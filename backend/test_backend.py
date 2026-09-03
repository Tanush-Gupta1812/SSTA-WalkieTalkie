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
        # Create group
        resp = await client.post("/groups", json={"name": "Alpha Squad"})
        assert resp.status_code == 201
        data = resp.json()
        assert data["name"] == "Alpha Squad"
        assert len(data["join_token"]) == 6
        group_id = data["id"]
        join_token = data["join_token"]

        # List groups
        resp2 = await client.get("/groups")
        assert resp2.status_code == 200
        groups = resp2.json()
        assert len(groups) >= 1
        assert groups[0]["id"] == group_id

        # Join group
        join_resp = await client.post("/groups/join", json={
            "join_token": join_token,
            "user_id": "user_123",
            "display_name": "Ghost"
        })
        assert join_resp.status_code == 200
        assert join_resp.json()["member_count"] == 1

        # Check members
        members_resp = await client.get(f"/groups/{group_id}/members")
        assert members_resp.status_code == 200
        members = members_resp.json()
        assert len(members) == 1
        assert members[0]["user_id"] == "user_123"
        assert members[0]["display_name"] == "Ghost"

        # Leave group
        leave_resp = await client.delete(f"/groups/{group_id}/members/user_123")
        assert leave_resp.status_code == 200
        assert leave_resp.json()["status"] == "left"

        # Check members after leave
        members_resp2 = await client.get(f"/groups/{group_id}/members")
        assert len(members_resp2.json()) == 0

@pytest.mark.asyncio
async def test_ptt_lock_logic():
    cm = ConnectionManager()
    group_id = "grp_test_ptt"
    user_a = "user_a"
    user_b = "user_b"

    # User A acquires PTT lock
    acquired_a = await cm.try_acquire_ptt(group_id, user_a)
    assert acquired_a is True
    assert cm.get_active_speaker(group_id) == user_a
    assert cm.is_speaking(group_id, user_a) is True

    # User B tries to acquire while A is talking -> MUST FAIL
    acquired_b = await cm.try_acquire_ptt(group_id, user_b)
    assert acquired_b is False
    assert cm.get_active_speaker(group_id) == user_a

    # User A releases PTT lock
    released_a = await cm.release_ptt(group_id, user_a)
    assert released_a is True
    assert cm.get_active_speaker(group_id) is None

    # Now User B can acquire PTT lock
    acquired_b_second = await cm.try_acquire_ptt(group_id, user_b)
    assert acquired_b_second is True
    assert cm.get_active_speaker(group_id) == user_b

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
