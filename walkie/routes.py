import os
import sys
import uuid
import secrets
import string
import logging
from typing import List, Optional
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, HTTPException, status, Query, Response
import aiosqlite

try:
    from app.walkie.database import init_db as init_walkie_db, get_db, DB_PATH
    from app.walkie.audio_history import audio_history
    from app.walkie.models import (
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
    from app.walkie.connection_manager import manager
except ImportError:
    try:
        from walkie.database import init_db as init_walkie_db, get_db, DB_PATH
        from walkie.audio_history import audio_history
        from walkie.models import (
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
        from walkie.connection_manager import manager
    except ImportError:
        from database import init_db as init_walkie_db, get_db, DB_PATH
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

logger = logging.getLogger("kalortech.walkie")

router = APIRouter(tags=["WalkieTalkie"])

def generate_join_token(length: int = 6) -> str:
    """Generate human-friendly uppercase alphanumeric join token (e.g., 'WALK92')"""
    chars = string.ascii_uppercase + string.digits
    return "".join(secrets.choice(chars) for _ in range(length))

@router.get("/walkie/health")
@router.get("/health/walkie")
async def walkie_health():
    return {"status": "healthy", "service": "KalorTech WalkieTalkie", "db": "connected"}

# --------------------------------------------------------------------------
# Channels / Groups Management
# --------------------------------------------------------------------------

@router.post("/walkie/groups", response_model=GroupResponse, status_code=status.HTTP_201_CREATED)
@router.post("/groups", response_model=GroupResponse, status_code=status.HTTP_201_CREATED)
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

@router.get("/walkie/groups", response_model=List[GroupResponse])
@router.get("/groups", response_model=List[GroupResponse])
async def list_groups(
    user_id: Optional[str] = Query(None),
    db: aiosqlite.Connection = Depends(get_db)
):
    """
    Returns channels that the specified user is a member of.
    If no user_id is provided or the user has not joined any channels, returns empty list.
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

@router.get("/walkie/groups/{group_id}", response_model=GroupResponse)
@router.get("/groups/{group_id}", response_model=GroupResponse)
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
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Group not found")
    return GroupResponse(
        id=row["id"],
        name=row["name"],
        join_token=row["join_token"],
        member_count=row["member_count"],
        created_at=str(row["created_at"])
    )

@router.post("/walkie/groups/join", response_model=GroupResponse)
@router.post("/groups/join", response_model=GroupResponse)
async def join_group(
    req: JoinGroupRequest,
    db: aiosqlite.Connection = Depends(get_db)
):
    token = req.join_token.strip().upper()
    cursor = await db.execute("SELECT id, name, join_token, created_at FROM groups WHERE UPPER(join_token) = ?", (token,))
    row = await cursor.fetchone()
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invalid join token or channel not found")

    group_id = row["id"]

    await db.execute("""
        INSERT INTO members (group_id, user_id, display_name)
        VALUES (?, ?, ?)
        ON CONFLICT(group_id, user_id) DO UPDATE SET display_name = excluded.display_name
    """, (group_id, req.user_id, req.display_name.strip()))
    await db.commit()

    count_cursor = await db.execute("SELECT COUNT(*) as cnt FROM members WHERE group_id = ?", (group_id,))
    count_row = await count_cursor.fetchone()
    member_count = count_row["cnt"] if count_row else 1

    return GroupResponse(
        id=group_id,
        name=row["name"],
        join_token=row["join_token"],
        member_count=member_count,
        created_at=str(row["created_at"])
    )

@router.get("/walkie/groups/{group_id}/members", response_model=List[MemberResponse])
@router.get("/groups/{group_id}/members", response_model=List[MemberResponse])
async def list_members(group_id: str, db: aiosqlite.Connection = Depends(get_db)):
    cursor = await db.execute("""
        SELECT user_id, display_name, joined_at
        FROM members
        WHERE group_id = ?
        ORDER BY joined_at ASC
    """, (group_id,))
    rows = await cursor.fetchall()
    online_users = manager.get_online_users(group_id)
    return [
        MemberResponse(
            user_id=row["user_id"],
            display_name=row["display_name"],
            is_online=(row["user_id"] in online_users),
            joined_at=str(row["joined_at"])
        )
        for row in rows
    ]

@router.post("/walkie/groups/{group_id}/leave", response_model=LeaveGroupResponse)
@router.post("/groups/{group_id}/leave", response_model=LeaveGroupResponse)
async def leave_group(
    group_id: str,
    user_id: str = Query(...),
    db: aiosqlite.Connection = Depends(get_db)
):
    await db.execute("DELETE FROM members WHERE group_id = ? AND user_id = ?", (group_id, user_id))
    await db.commit()
    await manager.disconnect(group_id, user_id)
    return LeaveGroupResponse(
        status="success",
        group_id=group_id,
        user_id=user_id
    )

@router.delete("/walkie/groups/{group_id}", response_model=DeleteGroupResponse)
@router.delete("/groups/{group_id}", response_model=DeleteGroupResponse)
async def delete_group(group_id: str, db: aiosqlite.Connection = Depends(get_db)):
    cursor = await db.execute("SELECT id FROM groups WHERE id = ?", (group_id,))
    if not await cursor.fetchone():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Group not found")

    await manager.broadcast_json(group_id, {
        "type": "group_deleted",
        "group_id": group_id
    })
    audio_history.clear_group(group_id)

    await db.execute("DELETE FROM members WHERE group_id = ?", (group_id,))
    await db.execute("DELETE FROM groups WHERE id = ?", (group_id,))
    await db.commit()

    return DeleteGroupResponse(
        status="success",
        group_id=group_id,
        message="Group and all member records deleted successfully"
    )

@router.patch("/walkie/groups/{group_id}", response_model=GroupResponse)
@router.patch("/groups/{group_id}", response_model=GroupResponse)
async def rename_group(
    group_id: str,
    req: RenameGroupRequest,
    db: aiosqlite.Connection = Depends(get_db)
):
    new_name = req.name.strip()
    cursor = await db.execute("SELECT id, name, join_token, created_at FROM groups WHERE id = ?", (group_id,))
    row = await cursor.fetchone()
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Group not found")

    await db.execute("UPDATE groups SET name = ? WHERE id = ?", (new_name, group_id))
    await db.commit()

    await manager.broadcast_group_renamed(group_id, new_name)

    count_cursor = await db.execute("SELECT COUNT(*) as cnt FROM members WHERE group_id = ?", (group_id,))
    count_row = await count_cursor.fetchone()
    member_count = count_row["cnt"] if count_row else 0

    return GroupResponse(
        id=group_id,
        name=new_name,
        join_token=row["join_token"],
        member_count=member_count,
        created_at=str(row["created_at"])
    )

@router.put("/walkie/users/{user_id}", response_model=UpdateUserResponse)
async def update_user_display_name(
    user_id: str,
    req: UpdateUserRequest,
    db: aiosqlite.Connection = Depends(get_db)
):
    new_name = req.display_name.strip()
    await db.execute("UPDATE members SET display_name = ? WHERE user_id = ?", (new_name, user_id))
    await db.commit()
    await manager.update_user_name(user_id, new_name)
    return UpdateUserResponse(user_id=user_id, display_name=new_name)

# --------------------------------------------------------------------------
# Audio Transmission History & Replay Endpoints
# --------------------------------------------------------------------------

@router.get("/walkie/groups/{group_id}/transmissions")
@router.get("/groups/{group_id}/transmissions")
async def get_group_transmissions(group_id: str):
    return {"transmissions": audio_history.get_group_messages(group_id)}

@router.get("/walkie/transmissions/{tx_id}/audio")
@router.get("/transmissions/{tx_id}/audio")
async def get_transmission_raw_audio(tx_id: str):
    msg = audio_history.get_message(tx_id)
    if not msg:
        raise HTTPException(status_code=404, detail="Audio transmission not found or expired")
    return Response(content=msg.audio_bytes, media_type="application/octet-stream")

# --------------------------------------------------------------------------
# WebSocket Endpoint for Live Multi-Speaker PTT Audio Streaming
# --------------------------------------------------------------------------

async def _handle_walkie_websocket(
    websocket: WebSocket,
    group_id: str,
    user_id: str,
    display_name: str,
    db: aiosqlite.Connection
):
    # Verify membership
    cursor = await db.execute("SELECT 1 FROM members WHERE group_id = ? AND user_id = ?", (group_id, user_id))
    if not await cursor.fetchone():
        await websocket.close(code=4003, reason="Forbidden: Not a member of this channel")
        return

    await manager.connect(group_id, user_id, display_name, websocket)

    current_audio_chunks = []
    ptt_start_time: Optional[float] = None
    echo_mode = False

    try:
        while True:
            msg = await websocket.receive()

            if "bytes" in msg and msg["bytes"]:
                data = msg["bytes"]
                if manager.is_speaking(group_id, user_id):
                    current_audio_chunks.append(data)
                    exclude_id = None if echo_mode else user_id
                    await manager.broadcast_bytes(group_id, data, exclude_user_id=exclude_id)

            elif "text" in msg and msg["text"]:
                try:
                    import json
                    event = json.loads(msg["text"])
                    event_type = event.get("type")

                    if event_type == "ptt_start":
                        echo_mode = bool(event.get("echo", False))
                        current_audio_chunks.clear()
                        import time
                        ptt_start_time = time.time()
                        await manager.try_acquire_ptt(group_id, user_id)
                        await manager.broadcast_json(group_id, {
                            "type": "ptt_started",
                            "user_id": user_id,
                            "display_name": manager.user_names.get(user_id, display_name)
                        })

                    elif event_type == "ptt_stop":
                        was_speaking = manager.is_speaking(group_id, user_id)
                        await manager.release_ptt(group_id, user_id)
                        tx_dict = None
                        if was_speaking and current_audio_chunks:
                            import time
                            duration = (time.time() - ptt_start_time) if ptt_start_time else 0.0
                            combined_pcm = b"".join(current_audio_chunks)
                            saved_msg = audio_history.add_message(
                                group_id=group_id,
                                user_id=user_id,
                                display_name=manager.user_names.get(user_id, display_name),
                                raw_pcm=combined_pcm,
                                duration_seconds=duration,
                            )
                            tx_dict = saved_msg.to_dict()
                            current_audio_chunks.clear()

                        await manager.broadcast_json(group_id, {
                            "type": "ptt_stopped",
                            "user_id": user_id,
                            "transmission": tx_dict
                        })

                    elif event_type == "update_display_name":
                        new_name = event.get("display_name", "").strip()
                        if new_name:
                            await db.execute("UPDATE members SET display_name = ? WHERE user_id = ?", (new_name, user_id))
                            await db.commit()
                            await manager.update_user_name(user_id, new_name)

                except Exception as e:
                    logger.error(f"Error handling text frame: {e}")

    except WebSocketDisconnect:
        await manager.disconnect(group_id, user_id)
    except Exception as e:
        logger.error(f"Unexpected WebSocket error: {e}")
        await manager.disconnect(group_id, user_id)

@router.websocket("/walkie/ws/group/{group_id}")
async def walkie_ws_endpoint_prefixed(
    websocket: WebSocket,
    group_id: str,
    user_id: str = Query(...),
    display_name: str = Query("Operator"),
    db: aiosqlite.Connection = Depends(get_db)
):
    await _handle_walkie_websocket(websocket, group_id, user_id, display_name, db)

@router.websocket("/ws/group/{group_id}")
async def walkie_ws_endpoint_direct(
    websocket: WebSocket,
    group_id: str,
    user_id: str = Query(...),
    display_name: str = Query("Operator"),
    db: aiosqlite.Connection = Depends(get_db)
):
    await _handle_walkie_websocket(websocket, group_id, user_id, display_name, db)
