import time
import io
import wave
import uuid
from collections import deque
from typing import Dict, List, Optional

# Max messages retained in memory across all users combined per group
MAX_GROUP_HISTORY = 3

class AudioMessage:
    def __init__(
        self,
        message_id: str,
        group_id: str,
        user_id: str,
        display_name: str,
        audio_bytes: bytes,
        duration_seconds: float,
        timestamp: float,
    ):
        self.id = message_id
        self.group_id = group_id
        self.user_id = user_id
        self.display_name = display_name
        self.audio_bytes = audio_bytes
        self.duration_seconds = duration_seconds
        self.timestamp = timestamp

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "group_id": self.group_id,
            "user_id": self.user_id,
            "display_name": self.display_name,
            "duration_seconds": round(self.duration_seconds, 1),
            "timestamp": self.timestamp,
            "size_bytes": len(self.audio_bytes),
        }

    def to_wav(self) -> bytes:
        """Convert raw PCM16 mono 16kHz to WAV format in memory for easy playback."""
        wav_buf = io.BytesIO()
        with wave.open(wav_buf, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)  # 16-bit PCM
            wf.setframerate(16000)  # 16 kHz
            wf.writeframes(self.audio_bytes)
        return wav_buf.getvalue()

class MemoryAudioHistory:
    def __init__(self):
        # group_id -> deque of AudioMessage (maxlen=MAX_GROUP_HISTORY, last 3 all users combined)
        self._store: Dict[str, deque] = {}
        # Quick lookup for audio binary: message_id -> AudioMessage
        self._messages_by_id: Dict[str, AudioMessage] = {}

    def add_message(
        self,
        group_id: str,
        user_id: str,
        display_name: str,
        raw_pcm: bytes,
        duration_seconds: float,
    ) -> AudioMessage:
        if group_id not in self._store:
            self._store[group_id] = deque(maxlen=MAX_GROUP_HISTORY)

        group_deque = self._store[group_id]

        # If deque is at capacity, the oldest item will be dropped; remove from ID lookup
        if len(group_deque) == MAX_GROUP_HISTORY:
            oldest = group_deque[0]
            self._messages_by_id.pop(oldest.id, None)

        msg_id = str(uuid.uuid4())
        msg = AudioMessage(
            message_id=msg_id,
            group_id=group_id,
            user_id=user_id,
            display_name=display_name,
            audio_bytes=raw_pcm,
            duration_seconds=duration_seconds,
            timestamp=time.time(),
        )

        group_deque.append(msg)
        self._messages_by_id[msg_id] = msg
        return msg

    def get_group_messages(self, group_id: str) -> List[dict]:
        """Returns the last 3 messages across all users in the group, sorted newest first."""
        if group_id not in self._store:
            return []
        # Return newest first (reversed order of chronological deque)
        return [m.to_dict() for m in reversed(self._store[group_id])]

    def get_message(self, message_id: str) -> Optional[AudioMessage]:
        return self._messages_by_id.get(message_id)

    def clear_group(self, group_id: str):
        if group_id in self._store:
            for m in self._store[group_id]:
                self._messages_by_id.pop(m.id, None)
            del self._store[group_id]

# Singleton instance
audio_history = MemoryAudioHistory()
