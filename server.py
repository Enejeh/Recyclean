"""Recyclean backend: serves index.html and a small JSON API backed by Postgres.

Env:
  DATABASE_URL  Postgres connection string (required)
  SECRET_KEY    Flask session key (falls back to a random key -> sessions reset on restart)

Run locally:  DATABASE_URL=... python3 -m flask --app server run
On Render:    gunicorn server:app
"""
import os
import secrets
from datetime import date, datetime, timezone
from functools import wraps
from pathlib import Path

import bcrypt
import psycopg
from flask import Flask, jsonify, request, send_from_directory, session
from psycopg.rows import dict_row

BASE_DIR = Path(__file__).resolve().parent

app = Flask(__name__, static_folder=None)
app.secret_key = os.environ.get("SECRET_KEY") or secrets.token_hex(32)
app.config.update(SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE="Lax")

# Points awarded per action (same amounts the page used before).
POINTS = {"report": 15, "311": 15, "volunteer": 25, "scan": 20}


# ---------------------------------------------------------------- helpers
def db():
    """Open a short-lived connection (use as a context manager; commits on success)."""
    return psycopg.connect(os.environ["DATABASE_URL"], row_factory=dict_row)


def time_ago(ts):
    if ts is None:
        return ""
    secs = (datetime.now(timezone.utc) - ts).total_seconds()
    if secs < 60:
        return "Just now"
    if secs < 3600:
        return f"{int(secs // 60)}m ago"
    if secs < 86400:
        return f"{int(secs // 3600)}h ago"
    return f"{int(secs // 86400)}d ago"


def age_from(dob):
    today = date.today()
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


def parse_date(value):
    try:
        return date.fromisoformat(str(value))
    except (TypeError, ValueError):
        return None


def body():
    return request.get_json(silent=True) or {}


def err(msg, code=400):
    return jsonify({"error": msg}), code


def login_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if not session.get("user_id"):
            return err("Please log in first.", 401)
        return fn(*args, **kwargs)
    return wrapper


def user_payload(conn, user_id):
    u = conn.execute(
        """SELECT id, email, display_name, points_balance, COALESCE(is_over_18, true) AS is_over_18
           FROM users WHERE id = %s""",
        (user_id,),
    ).fetchone()
    if not u:
        return None
    claimed = conn.execute(
        "SELECT reward_id FROM user_claimed_rewards WHERE user_id = %s", (user_id,)
    ).fetchall()
    return {
        "email": u["email"],
        "display_name": u["display_name"],
        "points_balance": u["points_balance"] or 0,
        "is_over_18": u["is_over_18"],
        "claimed_reward_ids": [c["reward_id"] for c in claimed],
    }


def award(conn, points):
    row = conn.execute(
        "UPDATE users SET points_balance = COALESCE(points_balance, 0) + %s WHERE id = %s RETURNING points_balance",
        (points, session["user_id"]),
    ).fetchone()
    return row["points_balance"]


# ---------------------------------------------------------------- page
@app.get("/")
def index():
    return send_from_directory(BASE_DIR, "index.html")


@app.get("/healthz")
def healthz():
    return jsonify({"ok": True})


# ---------------------------------------------------------------- auth
@app.post("/api/signup")
def signup():
    d = body()
    email = (d.get("email") or "").strip().lower()
    password = d.get("password") or ""
    username = (d.get("username") or "").strip()
    dob = parse_date(d.get("date_of_birth"))
    if not email or not username or not dob:
        return err("Username, email and date of birth are required.")
    if len(password) < 6:
        return err("Password must be at least 6 characters.")
    over18 = age_from(dob) >= 18
    parent_name = (d.get("parent_name") or "").strip() or None
    parent_email = (d.get("parent_email") or "").strip() or None
    parent_consent = bool(d.get("parent_consent"))
    if not over18 and not (parent_name and parent_email and parent_consent):
        return err("Parental consent is required for users under 18.")
    pw_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt(12)).decode()
    with db() as conn:
        if conn.execute("SELECT 1 FROM users WHERE lower(email) = %s", (email,)).fetchone():
            return err("An account with that email already exists.", 409)
        row = conn.execute(
            """INSERT INTO users (email, password_hash, display_name, points_balance,
                                  date_of_birth, is_over_18, parent_name, parent_email, parent_consent)
               VALUES (%s, %s, %s, 0, %s, %s, %s, %s, %s) RETURNING id""",
            (email[:255], pw_hash, username[:100], dob, over18, parent_name, parent_email, parent_consent),
        ).fetchone()
        session.clear()
        session["user_id"] = str(row["id"])
        return jsonify({"user": user_payload(conn, row["id"])}), 201


@app.post("/api/login")
def login():
    d = body()
    email = (d.get("email") or "").strip().lower()
    password = (d.get("password") or "").encode()
    with db() as conn:
        u = conn.execute(
            "SELECT id, password_hash FROM users WHERE lower(email) = %s", (email,)
        ).fetchone()
        ok = False
        if u:
            try:
                ok = bcrypt.checkpw(password, u["password_hash"].encode())
            except ValueError:
                ok = False
        if not ok:
            return err("Incorrect email or password.", 401)
        session.clear()
        session["user_id"] = str(u["id"])
        return jsonify({"user": user_payload(conn, u["id"])})


@app.post("/api/logout")
def logout():
    session.clear()
    return jsonify({"ok": True})


@app.get("/api/me")
def me():
    uid = session.get("user_id")
    if not uid:
        return jsonify({"user": None})
    with db() as conn:
        user = user_payload(conn, uid)
    if not user:
        session.clear()
    return jsonify({"user": user})


# ---------------------------------------------------------------- public reads
@app.get("/api/locations")
def locations():
    with db() as conn:
        rows = conn.execute(
            """SELECT id, latitude::float8 AS lat, longitude::float8 AS lng, status, type, urgency
               FROM map_locations ORDER BY id"""
        ).fetchall()
    return jsonify(rows)


@app.get("/api/alerts")
def alerts():
    with db() as conn:
        rows = conn.execute(
            """SELECT id, name, latitude::float8 AS lat, longitude::float8 AS lng, status, type,
                      description AS "desc"
               FROM crowded_alerts ORDER BY id"""
        ).fetchall()
    return jsonify(rows)


@app.get("/api/markers")
def markers():
    with db() as conn:
        rows = conn.execute(
            """SELECT m.id, m.latitude::float8 AS lat, m.longitude::float8 AS lng, m.category,
                      m.title, m.description, u.display_name AS author, m.created_at
               FROM map_markers m LEFT JOIN users u ON u.id = m.user_id
               ORDER BY m.created_at, m.id"""
        ).fetchall()
    for r in rows:
        r["created_at"] = r["created_at"].isoformat() if r["created_at"] else None
    return jsonify(rows)


def _cache_type(status):
    s = (status or "").lower()
    return "positive" if s == "closed" else ("pending" if s == "in progress" else "negative")


@app.get("/api/311")
def reports_311():
    """Community reports (newest first) followed by cached NYC Open Data 311 rows."""
    with db() as conn:
        community = conn.execute(
            """SELECT id, title, category, location, description, reporter, is_anonymous,
                      status, type, created_at
               FROM public_311_reports ORDER BY created_at DESC, id DESC"""
        ).fetchall()
        cache = conn.execute(
            """SELECT unique_key, complaint_type, descriptor, latitude::float8 AS lat,
                      longitude::float8 AS lng, status, last_synced
               FROM nyc_311_cache ORDER BY last_synced DESC NULLS LAST, unique_key"""
        ).fetchall()
    out = []
    for r in community:
        out.append({
            "id": r["id"],
            "title": r["title"],
            "category": r["category"],
            "location": r["location"],
            "description": r["description"],
            "reporter": "Anonymous Citizen" if r["is_anonymous"] else r["reporter"],
            "isAnonymous": r["is_anonymous"],
            "timeAgo": time_ago(r["created_at"]),
            "status": r["status"],
            "type": r["type"],
            "source": "community",
        })
    for r in cache:
        loc = f"{r['lat']:.4f}, {r['lng']:.4f}" if r["lat"] is not None else "NYC"
        out.append({
            "id": r["unique_key"],
            "title": r["complaint_type"],
            "category": r["descriptor"] or r["complaint_type"],
            "location": loc,
            "description": None,
            "reporter": "NYC 311 Open Data",
            "isAnonymous": False,
            "timeAgo": time_ago(r["last_synced"]),
            "status": (r["status"] or "").upper(),
            "type": _cache_type(r["status"]),
            "source": "nyc311",
        })
    return jsonify(out)


@app.get("/api/rewards")
def rewards():
    with db() as conn:
        rows = conn.execute(
            "SELECT id, title, description, points_required, icon FROM rewards ORDER BY points_required, id"
        ).fetchall()
    return jsonify(rows)


@app.get("/api/chat")
def chat_list():
    with db() as conn:
        rows = conn.execute(
            """SELECT id, author, body FROM
                 (SELECT id, author, body, created_at FROM chat_messages
                  ORDER BY created_at DESC, id DESC LIMIT 100) t
               ORDER BY created_at, id"""
        ).fetchall()
    return jsonify(rows)


# ---------------------------------------------------------------- writes (logged-in)
@app.post("/api/311")
@login_required
def create_311():
    d = body()
    location = (d.get("location") or "").strip()
    category = (d.get("category") or "").strip()
    if not location or not category:
        return err("Location and category are required.")
    title = (d.get("title") or "").strip() or "Sanitation Violation"
    anon = bool(d.get("anonymous"))
    with db() as conn:
        name = conn.execute("SELECT display_name FROM users WHERE id = %s", (session["user_id"],)).fetchone()
        row = conn.execute(
            """INSERT INTO public_311_reports
                 (user_id, title, category, location, description, reporter, is_anonymous, status, type)
               VALUES (%s, %s, %s, %s, %s, %s, %s, 'PENDING', 'negative') RETURNING id""",
            (session["user_id"], title[:255], category[:255], location[:255],
             (d.get("description") or "").strip() or None,
             "Anonymous Citizen" if anon else name["display_name"], anon),
        ).fetchone()
        pts = award(conn, POINTS["311"])
    return jsonify({"id": row["id"], "points_balance": pts}), 201


@app.post("/api/markers")
@login_required
def create_marker():
    d = body()
    try:
        lat, lng = float(d["lat"]), float(d["lng"])
    except (KeyError, TypeError, ValueError):
        return err("lat and lng are required.")
    title = (d.get("title") or "").strip()
    category = (d.get("category") or "Needs Attention").strip()
    if not title:
        return err("A location / title is required.")
    with db() as conn:
        row = conn.execute(
            """INSERT INTO map_markers (user_id, latitude, longitude, category, title, description)
               VALUES (%s, %s, %s, %s, %s, %s) RETURNING id""",
            (session["user_id"], lat, lng, category[:50], title[:150],
             (d.get("description") or "").strip() or None),
        ).fetchone()
        pts = award(conn, POINTS["report"])
    return jsonify({"id": row["id"], "points_balance": pts}), 201


@app.post("/api/volunteer")
@login_required
def volunteer():
    d = body()
    name = (d.get("full_name") or "").strip()
    dob = parse_date(d.get("date_of_birth"))
    event = (d.get("event_name") or "").strip()
    if not name or not dob or not event:
        return err("Name, date of birth and event are required.")
    if age_from(dob) < 18:
        return err("You must be at least 18 years old to register as a field cleanup volunteer.", 403)
    with db() as conn:
        row = conn.execute(
            """INSERT INTO volunteer_signups (user_id, full_name, date_of_birth, event_name)
               VALUES (%s, %s, %s, %s) RETURNING id""",
            (session["user_id"], name[:255], dob, event[:255]),
        ).fetchone()
        pts = award(conn, POINTS["volunteer"])
    return jsonify({"id": row["id"], "points_balance": pts}), 201


@app.post("/api/scans")
@login_required
def scans():
    d = body()
    category = (d.get("detected_category") or "").strip()
    if not category:
        return err("detected_category is required.")
    try:
        confidence = float(d.get("confidence_score", 0))
    except (TypeError, ValueError):
        confidence = 0.0
    with db() as conn:
        row = conn.execute(
            """INSERT INTO scan_logs (user_id, detected_category, confidence_score, points_awarded)
               VALUES (%s, %s, %s, %s) RETURNING id""",
            (session["user_id"], category[:100], confidence, POINTS["scan"]),
        ).fetchone()
        pts = award(conn, POINTS["scan"])
    return jsonify({"id": row["id"], "points_balance": pts}), 201


@app.post("/api/chat")
@login_required
def chat_post():
    text = (body().get("body") or "").strip()
    if not text:
        return err("Message is empty.")
    with db() as conn:
        name = conn.execute("SELECT display_name FROM users WHERE id = %s", (session["user_id"],)).fetchone()
        row = conn.execute(
            "INSERT INTO chat_messages (user_id, author, body) VALUES (%s, %s, %s) RETURNING id, author, body",
            (session["user_id"], name["display_name"], text[:1000]),
        ).fetchone()
    return jsonify(row), 201


@app.post("/api/rewards/<int:reward_id>/claim")
@login_required
def claim_reward(reward_id):
    """Rewards are milestone checkpoints: claiming checks the balance but does not spend points."""
    with db() as conn:
        reward = conn.execute("SELECT id, title, points_required FROM rewards WHERE id = %s", (reward_id,)).fetchone()
        if not reward:
            return err("Reward not found.", 404)
        u = conn.execute("SELECT points_balance FROM users WHERE id = %s", (session["user_id"],)).fetchone()
        balance = u["points_balance"] or 0
        if balance < reward["points_required"]:
            return err(f"You need {reward['points_required'] - balance} more points.", 403)
        existing = conn.execute(
            "SELECT redemption_code FROM user_claimed_rewards WHERE user_id = %s AND reward_id = %s",
            (session["user_id"], reward_id),
        ).fetchone()
        if existing:
            return jsonify({"already_claimed": True, "redemption_code": existing["redemption_code"]})
        code = f"RECYCLE-{reward['points_required']}-{secrets.token_hex(3).upper()}"
        row = conn.execute(
            """INSERT INTO user_claimed_rewards (user_id, reward_id, redemption_code)
               VALUES (%s, %s, %s) RETURNING id, redemption_code""",
            (session["user_id"], reward_id, code),
        ).fetchone()
    return jsonify({"id": row["id"], "redemption_code": row["redemption_code"]}), 201


if __name__ == "__main__":
    app.run(debug=True)
