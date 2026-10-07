# Recyclean database backend

`index.html` is served by a small Flask app (`server.py`) that reads/writes a Postgres database.
The page's look and text are unchanged; its hard-coded data now comes from the database.

## Run locally

```bash
pip install -r requirements.txt
DATABASE_URL=postgresql://... python3 -m flask --app server run
# open http://127.0.0.1:5000
```

Production (Render): start command `gunicorn server:app`, env vars `DATABASE_URL` and `SECRET_KEY`.
(`gunicorn.conf.py` preloads the app so all workers share one session key.)

To create/refresh the seed data (safe to run any number of times):

```bash
DATABASE_URL=postgresql://... python3 seed.py
```

## Demo login

Every seed user has the password **`demo1234`**:

| Email | Display name |
|---|---|
| alex.green@example.com | EcoAlex |
| maya.recycle@example.com | MayaSavesEarth |
| jordan.nyc@example.com | CleanNYC_Jordan |

New users can sign up on the page (a password field was added to the signup form).

## Tables

Full definitions are in `schema.sql`.

| Table | What it holds | Used by |
|---|---|---|
| `users` | accounts (bcrypt `password_hash`, `points_balance`, DOB / parental consent) | login, signup, points |
| `map_locations` | the 50 map locations (was `locations` in the page) | map circles |
| `crowded_alerts` | hub / dumping alerts (was `crowdedAlerts`) | map icons |
| `map_markers` | community pins + "Report Litter Site" submissions | map circles |
| `public_311_reports` | community 311 feed (was `public311Reports`) | 311 panel + modal |
| `nyc_311_cache` | cached NYC Open Data 311 complaints | end of the 311 feed |
| `rewards` | reward checkpoints (incl. the page's 3 Perks items) | Perks timeline |
| `user_claimed_rewards` | rewards each user has claimed (one per reward) | Perks timeline |
| `scan_logs` | AI-scanner results | AI Scanner |
| `volunteer_signups` | volunteer cleanup registrations (no ID numbers stored) | Volunteer modal |
| `chat_messages` | community eco chat | chat panel |

## API

All responses are JSON. Writes need a logged-in session (otherwise `401`).

| Method & path | Purpose |
|---|---|
| `GET /` | the page |
| `POST /api/login` `{email, password}` | log in |
| `POST /api/signup` `{username, email, password, date_of_birth, parent_name?, parent_email?, parent_consent?}` | create account + log in (under-18 needs parental consent) |
| `POST /api/logout` | log out |
| `GET /api/me` | current user (`null` if logged out), incl. points and claimed reward ids |
| `GET /api/locations` | 50 map locations |
| `GET /api/alerts` | hub / dumping alerts |
| `GET /api/markers` | map_markers |
| `POST /api/markers` `{lat, lng, title, category, description}` | report a litter site (+15 pts) |
| `GET /api/311` | community 311 reports + cached NYC 311 rows |
| `POST /api/311` `{title, category, location, description, anonymous}` | submit a 311 report (+15 pts) |
| `POST /api/volunteer` `{full_name, date_of_birth, event_name}` | register for a cleanup, 18+ only (+25 pts) |
| `POST /api/scans` `{detected_category, confidence_score}` | log an AI scan (+20 pts) |
| `GET /api/rewards` | reward checkpoints |
| `POST /api/rewards/<id>/claim` | claim a reward once you have enough points (points are not spent) |
| `GET /api/chat` / `POST /api/chat` `{body}` | read / post chat messages |

## Files

- `server.py`: Flask app + API
- `schema.sql`: full schema
- `seed_from_page.sql`: idempotent DDL + seed data taken from the page
- `seed.py`: runs `seed_from_page.sql` and sets the demo passwords
- `gunicorn.conf.py`, `requirements.txt`: deployment
