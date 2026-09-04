import os
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
import aiosqlite

# Set in-memory or test database
TEST_DB_PATH = "test_walkie.db"
os.environ["WALKIE_DB_PATH"] = TEST_DB_PATH

from main import app
from database import init_db
from connection_manager import ConnectionManager

@pytest_asyncio.fixture(autouse=True)
async def setup_test_db():
    await init_db()
    yield
    if os.path.exists(TEST_DB_PATH):
        try:
            os.remove(TEST_DB_PATH)
        except Exception:
            pass

@pytest.mark.asyncio
async def test_create_and_list_groups():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Create group with creator
        resp = await client.post("/groups", json={
            "name": "Alpha Squad",
            "creator_id": "creator_1",
            "creator_display_name": "Commander"
        })
        assert resp.status_code == 201
        data = resp.json()
        assert data["name"] == "Alpha Squad"
        assert len(data["join_token"]) == 6
        group_id = data["id"]
        join_token = data["join_token"]

        # List groups without user_id -> MUST return empty (privacy)
        resp_anon = await client.get("/groups")
        assert resp_anon.status_code == 200
        assert resp_anon.json() == []

        # List groups with non-member user_id -> MUST return empty
        resp_stranger = await client.get("/groups?user_id=stranger_user")
        assert resp_stranger.status_code == 200
        assert resp_stranger.json() == []

        # List groups with creator_id -> MUST return the group
        resp_creator = await client.get("/groups?user_id=creator_1")
        assert resp_creator.status_code == 200
        creator_groups = resp_creator.json()
        assert len(creator_groups) == 1
        assert creator_groups[0]["id"] == group_id

        # Join group with new user
        join_resp = await client.post("/groups/join", json={
            "join_token": join_token,
            "user_id": "user_123",
            "display_name": "Ghost"
        })
        assert join_resp.status_code == 200
        assert join_resp.json()["member_count"] == 2

        # Now user_123 can see the group
        resp_user123 = await client.get("/groups?user_id=user_123")
        assert len(resp_user123.json()) == 1

        # Check members
        members_resp = await client.get(f"/groups/{group_id}/members")
        assert members_resp.status_code == 200
        members = members_resp.json()
        assert len(members) == 2

        # Leave group
        leave_resp = await client.delete(f"/groups/{group_id}/members/user_123")
        assert leave_resp.status_code == 200
        assert leave_resp.json()["status"] == "left"

        # After leave, user_123 cannot see the group
        resp_after_leave = await client.get("/groups?user_id=user_123")
        assert resp_after_leave.json() == []

@pytest.mark.asyncio
async def test_ptt_lock_logic():
    cm = ConnectionManager()
    group_id = "grp_test_ptt"
    user_a = "user_a"
    user_b = "user_b"

    # User A acquires PTT
    acquired_a = await cm.try_acquire_ptt(group_id, user_a)
    assert acquired_a is True
    assert user_a in cm.get_active_speakers(group_id)
    assert cm.is_speaking(group_id, user_a) is True

    # User B can also acquire PTT simultaneously (multi-speaker full duplex)
    acquired_b = await cm.try_acquire_ptt(group_id, user_b)
    assert acquired_b is True
    assert user_b in cm.get_active_speakers(group_id)
    assert cm.is_speaking(group_id, user_b) is True

    # User A releases PTT
    released_a = await cm.release_ptt(group_id, user_a)
    assert released_a is True
    assert user_a not in cm.get_active_speakers(group_id)
    # User B is still speaking
    assert user_b in cm.get_active_speakers(group_id)

@pytest.mark.asyncio
async def test_delete_group():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Create group
        resp = await client.post("/groups", json={"name": "Bravo Squad"})
        assert resp.status_code == 201
        group_id = resp.json()["id"]

        # Delete group
        del_resp = await client.delete(f"/groups/{group_id}")
        assert del_resp.status_code == 200
        assert del_resp.json()["status"] == "deleted"

        # Verify group no longer exists
        get_resp = await client.get(f"/groups/{group_id}")
        assert get_resp.status_code == 404
