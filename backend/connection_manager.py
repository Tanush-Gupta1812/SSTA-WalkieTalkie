import asyncio
import json
import logging
from typing import Dict, Optional, Set
from fastapi import WebSocket

logger = logging.getLogger("walkie.connection_manager")

class ConnectionManager:
    """
    Manages active WebSocket connections per group, tracks user presence,
    and enforces an atomic Push-To-Talk lock (only one speaker per group at a time).
    """

    def __init__(self):
        # group_id -> {user_id: WebSocket}
        self.active_connections: Dict[str, Dict[str, WebSocket]] = {}
        # user_id -> display_name
        self.user_names: Dict[str, str] = {}
        # group_id -> user_id currently speaking (or None)
        self.active_speaker: Dict[str, Optional[str]] = {}
        # Lock for atomic PTT state mutations
        self._lock = asyncio.Lock()

    async def connect(self, group_id: str, user_id: str, display_name: str, websocket: WebSocket):
        await websocket.accept()
        async with self._lock:
            if group_id not in self.active_connections:
                self.active_connections[group_id] = {}
                self.active_speaker[group_id] = None

            self.active_connections[group_id][user_id] = websocket
            self.user_names[user_id] = display_name

        logger.info(f"User '{display_name}' ({user_id}) joined group {group_id}")

        # Broadcast user_joined event to all members in group
        await self.broadcast_json(group_id, {
            "type": "user_joined",
            "user_id": user_id,
            "display_name": display_name
        })

        # Send initial state to the newly connected user
        await self.send_initial_state(group_id, user_id, websocket)

    async def disconnect(self, group_id: str, user_id: str):
        was_speaking = False
        async with self._lock:
            if group_id in self.active_connections:
                self.active_connections[group_id].pop(user_id, None)
                if not self.active_connections[group_id]:
                    del self.active_connections[group_id]
                    self.active_speaker.pop(group_id, None)

            if self.active_speaker.get(group_id) == user_id:
                self.active_speaker[group_id] = None
                was_speaking = True

        display_name = self.user_names.get(user_id, user_id)
        logger.info(f"User '{display_name}' ({user_id}) left group {group_id}")

        # If user was actively transmitting when they disconnected, release channel immediately
        if was_speaking:
            await self.broadcast_json(group_id, {
                "type": "ptt_stopped",
                "user_id": user_id
            })

        await self.broadcast_json(group_id, {
            "type": "user_left",
            "user_id": user_id
        })

    async def try_acquire_ptt(self, group_id: str, user_id: str) -> bool:
        """
        Attempts to acquire the Push-To-Talk lock for group_id.
        Returns True if acquired, False if another user is already transmitting.
        """
        async with self._lock:
            current = self.active_speaker.get(group_id)
            if current is not None and current != user_id:
                # Channel is currently occupied
                return False
            self.active_speaker[group_id] = user_id
            return True

    async def release_ptt(self, group_id: str, user_id: str) -> bool:
        """
        Releases the Push-To-Talk lock if held by user_id.
        """
        async with self._lock:
            if self.active_speaker.get(group_id) == user_id:
                self.active_speaker[group_id] = None
                return True
            return False

    def get_active_speaker(self, group_id: str) -> Optional[str]:
        return self.active_speaker.get(group_id)

    def is_speaking(self, group_id: str, user_id: str) -> bool:
        return self.active_speaker.get(group_id) == user_id

    def get_online_users(self, group_id: str) -> Set[str]:
        return set(self.active_connections.get(group_id, {}).keys())

    async def broadcast_bytes(self, group_id: str, data: bytes, exclude_user_id: Optional[str] = None) -> int:
        """
        Relays binary audio chunks to connected sockets in the group.
        Returns the number of recipients audio was delivered to.
        """
        sent_count = 0
        connections = list(self.active_connections.get(group_id, {}).items())
        for u_id, ws in connections:
            if u_id == exclude_user_id:
                continue
            try:
                await ws.send_bytes(data)
                sent_count += 1
            except Exception as e:
                logger.warning(f"Failed to send audio chunk to user {u_id}: {e}")
        return sent_count

    async def broadcast_json(self, group_id: str, payload: dict, exclude_user_id: Optional[str] = None):
        """
        Broadcasts a JSON control message to all sockets in the group.
        """
        connections = list(self.active_connections.get(group_id, {}).items())
        text_data = json.dumps(payload)
        for u_id, ws in connections:
            if u_id == exclude_user_id:
                continue
            try:
                await ws.send_text(text_data)
            except Exception as e:
                logger.warning(f"Failed to send JSON to user {u_id}: {e}")

    async def send_initial_state(self, group_id: str, user_id: str, websocket: WebSocket):
        """
        Sends the initial connection state to a newly connected client:
        - List of online members
        - Current active speaker (if any)
        """
        online_members = [
            {"user_id": uid, "display_name": self.user_names.get(uid, uid)}
            for uid in self.active_connections.get(group_id, {}).keys()
        ]
        active_speaker_id = self.active_speaker.get(group_id)
        speaker_name = self.user_names.get(active_speaker_id) if active_speaker_id else None

        initial_payload = {
            "type": "initial_state",
            "online_members": online_members,
            "active_speaker_id": active_speaker_id,
            "active_speaker_name": speaker_name
        }
        try:
            await websocket.send_text(json.dumps(initial_payload))
        except Exception as e:
            logger.warning(f"Failed to send initial state to {user_id}: {e}")

# Global instance
manager = ConnectionManager()
