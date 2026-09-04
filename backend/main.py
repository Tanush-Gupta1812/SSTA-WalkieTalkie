import os
import sys
import logging
import uuid
import secrets
import string
from contextlib import asynccontextmanager
from typing import List, Optional

# Ensure backend directory is in sys.path regardless of execution working directory
_backend_dir = os.path.dirname(os.path.abspath(__file__))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends, HTTPException, status, Query, Response
from fastapi.middleware.cors import CORSMiddleware
import aiosqlite

from database import init_db, get_db, DB_PATH
from audio_history import audio_history
from models import (
    CreateGroupRequest,
    GroupResponse,
    JoinGroupRequest,
    MemberResponse,
    LeaveGroupResponse,
    DeleteGroupResponse,
    RenameGroupRequest,
    UpdateUserRequest,
    UpdateUserResponse,
)
from connection_manager import manager

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("walkie.api")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Setup SQLite tables on startup
    await init_db()
    logger.info("Database initialized successfully.")
    yield

app = FastAPI(
    title="SSTA-WalkieTalkie Backend",
    description="Real-time internet-based push-to-talk audio relay with group management and QR joining.",
    version="1.0.0",
    lifespan=lifespan
)

# Enable CORS for local cross-platform development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def generate_join_token(length: int = 6) -> str:
    """Generate human-friendly uppercase alphanumeric join token (e.g., 'WALK92')"""
    chars = string.ascii_uppercase + string.digits
    return "".join(secrets.choice(chars) for _ in range(length))

# --------------------------------------------------------------------------
# REST API Endpoints
# --------------------------------------------------------------------------

@app.get("/")
async def root():
    return {
        "status": "online",
        "service": "SSTA-WalkieTalkie Backend",
        "version": "1.0.0"
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "db": "connected"
    }

@app.post("/groups", response_model=GroupResponse, status_code=status.HTTP_201_CREATED)
async def create_group(
    req: CreateGroupRequest,
    db: aiosqlite.Connection = Depends(get_db)
):
    group_id = str(uuid.uuid4())
    join_token = generate_join_token()

    # Ensure token is unique
    for _ in range(5):
        cursor = await db.execute("SELECT id FROM groups WHERE join_token = ?", (join_token,))
        if not await cursor.fetchone():
            break
        join_token = generate_join_token()

    await db.execute(
        "INSERT INTO groups (id, name, join_token) VALUES (?, ?, ?)",
        (group_id, req.name.strip(), join_token)
    )

    member_count = 0
    if req.creator_id and req.creator_display_name:
        await db.execute(
            """
            INSERT INTO members (group_id, user_id, display_name)
            VALUES (?, ?, ?)
            ON CONFLICT(group_id, user_id) DO UPDATE SET display_name = excluded.display_name
            """,
            (group_id, req.creator_id, req.creator_display_name.strip())
        )
        member_count = 1

    await db.commit()

    return GroupResponse(
        id=group_id,
        name=req.name.strip(),
        join_token=join_token,
        member_count=member_count
    )

@app.get("/groups", response_model=List[GroupResponse])
async def list_groups(
    user_id: Optional[str] = Query(None),
    db: aiosqlite.Connection = Depends(get_db)
):
    """
    Returns channels that the specified user is a member of.
    If no user_id is provided or the user has not joined any channels, returns empty list.
    Channels are private and require a QR code or Join Token to join.
    """
    if not user_id:
        return []

    cursor = await db.execute("""
        SELECT g.id, g.name, g.join_token, g.created_at,
               (SELECT COUNT(*) FROM members WHERE group_id = g.id) as member_count
        FROM groups g
        INNER JOIN members m ON g.id = m.group_id AND m.user_id = ?
        ORDER BY g.created_at DESC
    """, (user_id,))
    rows = await cursor.fetchall()
    return [
        GroupResponse(
            id=row["id"],
            name=row["name"],
            join_token=row["join_token"],
            member_count=row["member_count"],
            created_at=str(row["created_at"])
        )
        for row in rows
    ]

@app.get("/groups/{group_id}", response_model=GroupResponse)
async def get_group(group_id: str, db: aiosqlite.Connection = Depends(get_db)):
    cursor = await db.execute("""
        SELECT g.id, g.name, g.join_token, g.created_at,
               COUNT(m.user_id) as member_count
        FROM groups g
        LEFT JOIN members m ON g.id = m.group_id
        WHERE g.id = ?
        GROUP BY g.id
    """, (group_id,))
    row = await cursor.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Group not found")

    return GroupResponse(
        id=row["id"],
        name=row["name"],
        join_token=row["join_token"],
        member_count=row["member_count"],
        created_at=str(row["created_at"])
    )

@app.post("/groups/join", response_model=GroupResponse)
async def join_group(
    req: JoinGroupRequest,
    db: aiosqlite.Connection = Depends(get_db)
):
    token = req.join_token.strip().upper()
    cursor = await db.execute("SELECT id, name, join_token, created_at FROM groups WHERE UPPER(join_token) = ?", (token,))
    row = await cursor.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Invalid join token or group does not exist")

    group_id = row["id"]

    # Insert or update member record
    await db.execute("""
        INSERT INTO members (group_id, user_id, display_name)
        VALUES (?, ?, ?)
        ON CONFLICT(group_id, user_id) DO UPDATE SET display_name=excluded.display_name
    """, (group_id, req.user_id, req.display_name.strip()))
    await db.commit()

    # Get updated member count
    count_cur = await db.execute("SELECT COUNT(*) as count FROM members WHERE group_id = ?", (group_id,))
    count_row = await count_cur.fetchone()
    member_count = count_row["count"] if count_row else 1

    return GroupResponse(
        id=group_id,
        name=row["name"],
        join_token=row["join_token"],
        member_count=member_count,
        created_at=str(row["created_at"])
    )

@app.get("/groups/{group_id}/members", response_model=List[MemberResponse])
async def list_members(group_id: str, db: aiosqlite.Connection = Depends(get_db)):
    # Check group exists
    check = await db.execute("SELECT id FROM groups WHERE id = ?", (group_id,))
    if not await check.fetchone():
        raise HTTPException(status_code=404, detail="Group not found")

    cursor = await db.execute("""
        SELECT user_id, display_name, joined_at
        FROM members
        WHERE group_id = ?
        ORDER BY joined_at ASC
    """, (group_id,))
    rows = await cursor.fetchall()

    online_user_ids = manager.get_online_users(group_id)

    return [
        MemberResponse(
            user_id=row["user_id"],
            display_name=row["display_name"],
            is_online=row["user_id"] in online_user_ids,
            joined_at=str(row["joined_at"])
        )
        for row in rows
    ]

@app.delete("/groups/{group_id}/members/{user_id}", response_model=LeaveGroupResponse)
async def leave_group(
    group_id: str,
    user_id: str,
    db: aiosqlite.Connection = Depends(get_db)
):
    # Remove member from SQLite
    res = await db.execute("DELETE FROM members WHERE group_id = ? AND user_id = ?", (group_id, user_id))
    await db.commit()

    # If the user has an active WebSocket in this group, disconnect them gracefully
    user_ws = manager.active_connections.get(group_id, {}).get(user_id)
    if user_ws:
        await manager.disconnect(group_id, user_id)
        try:
            await user_ws.close()
        except Exception:
            pass

    return LeaveGroupResponse(
        status="left",
        group_id=group_id,
        user_id=user_id
    )

@app.delete("/groups/{group_id}", response_model=DeleteGroupResponse)
async def delete_group(
    group_id: str,
    db: aiosqlite.Connection = Depends(get_db)
):
    # Check if group exists
    cursor = await db.execute("SELECT id, name FROM groups WHERE id = ?", (group_id,))
    row = await cursor.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Group not found")

    group_name = row["name"]

    # Notify connected sockets that group was deleted
    await manager.broadcast_json(group_id, {
        "type": "group_deleted",
        "group_id": group_id,
        "name": group_name
    })

    # Close and disconnect all active WebSockets
    conns = list(manager.active_connections.get(group_id, {}).items())
    for u_id, ws in conns:
        try:
            await ws.close(code=1000, reason="Group deleted")
        except Exception:
            pass
        await manager.disconnect(group_id, u_id)

    # Delete members and group from SQLite
    await db.execute("DELETE FROM members WHERE group_id = ?", (group_id,))
    await db.execute("DELETE FROM groups WHERE id = ?", (group_id,))
    await db.commit()

    logger.info(f"Group '{group_name}' ({group_id}) permanently deleted.")
    return DeleteGroupResponse(
        status="deleted",
        group_id=group_id,
        message=f"Group '{group_name}' deleted successfully"
    )

@app.patch("/groups/{group_id}", response_model=GroupResponse)
async def rename_group(
    group_id: str,
    payload: RenameGroupRequest,
    db: aiosqlite.Connection = Depends(get_db)
):
    # Verify group exists
    cursor = await db.execute("SELECT id, name, join_token, created_at FROM groups WHERE id = ?", (group_id,))
    row = await cursor.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Group not found")

    new_name = payload.name.strip()
    if not new_name:
        raise HTTPException(status_code=400, detail="Channel name cannot be empty")

    await db.execute("UPDATE groups SET name = ? WHERE id = ?", (new_name, group_id))
    await db.commit()

    # Broadcast rename event to all connected sockets in this channel
    await manager.broadcast_group_renamed(group_id, new_name)

    # Get updated member count
    cnt_cursor = await db.execute("SELECT COUNT(*) FROM members WHERE group_id = ?", (group_id,))
    cnt_row = await cnt_cursor.fetchone()
    member_count = cnt_row[0] if cnt_row else 0

    logger.info(f"Group '{group_id}' renamed to '{new_name}'")
    return GroupResponse(
        id=group_id,
        name=new_name,
        join_token=row["join_token"],
        member_count=member_count,
        created_at=str(row["created_at"])
    )

@app.put("/walkie/users/{user_id}", response_model=UpdateUserResponse)
@app.patch("/walkie/users/{user_id}", response_model=UpdateUserResponse)
@app.put("/walkie/users/{user_id}/display_name", response_model=UpdateUserResponse)
@app.patch("/walkie/users/{user_id}/display_name", response_model=UpdateUserResponse)
@app.put("/users/{user_id}", response_model=UpdateUserResponse)
@app.patch("/users/{user_id}", response_model=UpdateUserResponse)
async def update_user(
    user_id: str,
    payload: UpdateUserRequest,
    db: aiosqlite.Connection = Depends(get_db)
):
    new_name = payload.display_name.strip()
    if not new_name:
        raise HTTPException(status_code=400, detail="Display name cannot be empty")

    # Update in all group memberships
    await db.execute("UPDATE members SET display_name = ? WHERE user_id = ?", (new_name, user_id))
    await db.commit()

    # Update in connection manager & broadcast live to all active channels
    await manager.update_user_name(user_id, new_name)

    logger.info(f"User '{user_id}' updated display name to '{new_name}'")
    return UpdateUserResponse(
        status="success",
        user_id=user_id,
        display_name=new_name
    )

# --------------------------------------------------------------------------
# WebSocket Endpoint: Real-time Audio Streaming & PTT Signaling
# --------------------------------------------------------------------------

@app.websocket("/ws/group/{group_id}")
async def websocket_group_endpoint(
    websocket: WebSocket,
    group_id: str,
    user_id: str = Query(...),
    display_name: str = Query("User"),
    echo: bool = Query(False)
):
    # Verify that user is a member of this channel (joined via QR code / Join Token)
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        # 1. Verify channel exists on this server
        cur = await db.execute("SELECT name FROM groups WHERE id = ?", (group_id,))
        group_row = await cur.fetchone()
        if not group_row:
            await websocket.accept()
            import json
            await websocket.send_text(json.dumps({
                "type": "group_deleted",
                "message": "This channel does not exist on this server."
            }))
            await websocket.close(code=4004, reason="Group not found")
            return

        # 2. Ensure member is registered in channel
        cur = await db.execute(
            "SELECT 1 FROM members WHERE group_id = ? AND user_id = ?",
            (group_id, user_id)
        )
        if not await cur.fetchone():
            await db.execute(
                """
                INSERT INTO members (group_id, user_id, display_name)
                VALUES (?, ?, ?)
                ON CONFLICT(group_id, user_id) DO UPDATE SET display_name = excluded.display_name
                """,
                (group_id, user_id, display_name)
            )
            await db.commit()

    await manager.connect(group_id, user_id, display_name, websocket)
    is_echo_enabled = echo
    audio_frame_count = 0
    total_audio_bytes = 0
    transmission_buffer = bytearray()
    ptt_start_time = 0.0
    import time
    last_log_time = 0.0

    try:
        while True:
            # Receive either text (control message) or bytes (audio chunk)
            message = await websocket.receive()

            if "text" in message:
                import json
                try:
                    data = json.loads(message["text"])
                    msg_type = data.get("type")

                    if msg_type == "ptt_start":
                        if "echo" in data:
                            is_echo_enabled = bool(data["echo"])
                        acquired = await manager.try_acquire_ptt(group_id, user_id)
                        if acquired:
                            audio_frame_count = 0
                            total_audio_bytes = 0
                            transmission_buffer.clear()
                            ptt_start_time = time.time()
                            logger.info(f"🎙️ [PTT ON] '{display_name}' started transmitting (group: {group_id}, echo={is_echo_enabled})")
                            # Notify everyone that this user started speaking
                            await manager.broadcast_json(group_id, {
                                "type": "ptt_started",
                                "user_id": user_id,
                                "display_name": display_name
                            })
                        else:
                            # Channel is currently occupied by someone else!
                            active_spk = manager.get_active_speaker(group_id)
                            spk_name = manager.user_names.get(active_spk, "Someone")
                            await websocket.send_text(json.dumps({
                                "type": "ptt_rejected",
                                "reason": "channel_busy",
                                "active_speaker_name": spk_name
                            }))

                    elif msg_type == "ptt_stop":
                        released = await manager.release_ptt(group_id, user_id)
                        if released:
                            duration = max(0.2, time.time() - ptt_start_time)
                            logger.info(f"🛑 [PTT OFF] '{display_name}' stopped transmitting (sent {total_audio_bytes} bytes across {audio_frame_count} frames, {duration:.1f}s)")
                            
                            # Save to in-memory history (last 5 per user) if audio was actually transmitted
                            saved_msg = None
                            if len(transmission_buffer) > 0:
                                saved_msg = audio_history.add_message(
                                    group_id=group_id,
                                    user_id=user_id,
                                    display_name=display_name,
                                    raw_pcm=bytes(transmission_buffer),
                                    duration_seconds=duration,
                                )

                            await manager.broadcast_json(group_id, {
                                "type": "ptt_stopped",
                                "user_id": user_id,
                                "transmission": saved_msg.to_dict() if saved_msg else None
                            })
                            transmission_buffer.clear()

                    elif msg_type == "update_display_name":
                        new_name = str(data.get("display_name", "")).strip()
                        if new_name:
                            display_name = new_name
                            await manager.update_user_name(user_id, new_name)
                            async with aiosqlite.connect(DB_PATH) as db:
                                await db.execute("UPDATE members SET display_name = ? WHERE user_id = ?", (new_name, user_id))
                                await db.commit()

                except json.JSONDecodeError:
                    logger.warning(f"Invalid JSON received from user {user_id}: {message['text']}")

            elif "bytes" in message:
                audio_bytes = message["bytes"]
                # Only relay audio if this user holds the PTT lock!
                if manager.is_speaking(group_id, user_id):
                    audio_frame_count += 1
                    total_audio_bytes += len(audio_bytes)
                    transmission_buffer.extend(audio_bytes)
                    now = time.time()
                    exclude_id = None if is_echo_enabled else user_id
                    listeners = await manager.broadcast_bytes(group_id, audio_bytes, exclude_user_id=exclude_id)
                    if now - last_log_time >= 1.5:
                        last_log_time = now
                        logger.info(f"🔊 [AUDIO RELAY] '{display_name}' -> {listeners} listener(s) ({len(audio_bytes)}B/chunk, {total_audio_bytes}B total)")
                else:
                    logger.debug(f"Dropped audio bytes from user {user_id} (does not hold lock)")

    except WebSocketDisconnect:
        await manager.disconnect(group_id, user_id)
    except Exception as e:
        logger.error(f"WebSocket error for user {user_id} in {group_id}: {e}")
        await manager.disconnect(group_id, user_id)

# --------------------------------------------------------------------------
# Audio History & Replay Endpoints (RAM based)
# --------------------------------------------------------------------------

@app.get("/groups/{group_id}/history")
async def get_group_audio_history(group_id: str):
    """Retrieve last 5 audio messages per user in this group, sorted newest first."""
    messages = audio_history.get_group_messages(group_id)
    return {"group_id": group_id, "messages": messages}

@app.get("/history/{message_id}/wav")
async def get_message_wav(message_id: str):
    """Stream cached audio message as a standard WAV audio clip directly from RAM."""
    msg = audio_history.get_message(message_id)
    if not msg:
        raise HTTPException(status_code=404, detail="Audio message not found or expired from cache")
    
    wav_bytes = msg.to_wav()
    return Response(
        content=wav_bytes,
        media_type="audio/wav",
        headers={"Content-Disposition": f"inline; filename=msg_{message_id}.wav"}
    )

@app.get("/history/{message_id}/raw")
async def get_message_raw_pcm(message_id: str):
    """Stream raw PCM16 bytes directly from RAM for low-latency playback."""
    msg = audio_history.get_message(message_id)
    if not msg:
        raise HTTPException(status_code=404, detail="Audio message not found or expired from cache")
    return Response(content=msg.audio_bytes, media_type="application/octet-stream")

@app.get("/health")
async def health_check():
    return {"status": "ok", "app": "SSTA-WalkieTalkie"}
