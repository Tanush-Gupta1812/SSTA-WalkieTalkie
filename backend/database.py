import aiosqlite
import os

DB_PATH = os.environ.get("WALKIE_DB_PATH", os.path.join(os.path.dirname(__file__), "walkie.db"))

async def get_db():
    db = await aiosqlite.connect(DB_PATH)
    db.row_factory = aiosqlite.Row
    try:
        yield db
    finally:
        await db.close()

async def init_db():
    async with aiosqlite.connect(DB_PATH) as db:
        # High-performance concurrent settings: non-blocking WAL mode + lower disk sync overhead
        await db.execute("PRAGMA journal_mode=WAL;")
        await db.execute("PRAGMA synchronous=NORMAL;")
        await db.execute("PRAGMA busy_timeout=5000;")

        await db.execute("""
            CREATE TABLE IF NOT EXISTS groups (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                join_token TEXT UNIQUE NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        await db.execute("""
            CREATE TABLE IF NOT EXISTS members (
                group_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                display_name TEXT NOT NULL,
                joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (group_id, user_id),
                FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
            )
        """)
        # Indexes for O(1) channel queries and member listings
        await db.execute("CREATE INDEX IF NOT EXISTS idx_members_user_id ON members(user_id);")
        await db.execute("CREATE INDEX IF NOT EXISTS idx_groups_join_token ON groups(join_token);")
        await db.commit()

