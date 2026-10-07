"""Idempotent seeder: runs seed_from_page.sql, then gives every seed user a real
bcrypt hash of the demo password 'demo1234' (only if their hash doesn't already match).

    DATABASE_URL=postgresql://... python3 seed.py
"""
import os
import pathlib

import bcrypt
import psycopg

DEMO_PASSWORD = b"demo1234"
SEED_EMAILS = ["alex.green@example.com", "maya.recycle@example.com", "jordan.nyc@example.com"]


def main():
    sql = (pathlib.Path(__file__).parent / "seed_from_page.sql").read_text()
    with psycopg.connect(os.environ["DATABASE_URL"], autocommit=True) as conn:
        conn.execute(sql)
        for email in SEED_EMAILS:
            row = conn.execute("SELECT id, password_hash FROM users WHERE email = %s", (email,)).fetchone()
            if not row:
                continue
            try:
                ok = bcrypt.checkpw(DEMO_PASSWORD, row[1].encode())
            except ValueError:  # placeholder hashes in the original seed are not valid bcrypt
                ok = False
            if not ok:
                new_hash = bcrypt.hashpw(DEMO_PASSWORD, bcrypt.gensalt(12)).decode()
                conn.execute("UPDATE users SET password_hash = %s WHERE id = %s", (new_hash, row[0]))
                print(f"set demo password for {email}")
        for t in ["users", "map_markers", "map_locations", "crowded_alerts", "public_311_reports",
                  "nyc_311_cache", "rewards", "user_claimed_rewards", "scan_logs",
                  "volunteer_signups", "chat_messages"]:
            print(f"{t}: {conn.execute(f'SELECT count(*) FROM {t}').fetchone()[0]}")


if __name__ == "__main__":
    main()
