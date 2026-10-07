-- seed_from_page.sql
-- Idempotent: creates the tables/columns the page needs (if missing) and seeds them
-- with the data that used to be hard-coded in index.html. Safe to run repeatedly.
-- Run with:  DATABASE_URL=... python3 seed.py   (seed.py also sets demo passwords)

BEGIN;

-- ---------- new columns on users (signup form fields) ----------
ALTER TABLE users ADD COLUMN IF NOT EXISTS date_of_birth  date;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_over_18     boolean DEFAULT true;
ALTER TABLE users ADD COLUMN IF NOT EXISTS parent_name    varchar(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS parent_email   varchar(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS parent_consent boolean DEFAULT false;

-- ---------- rewards: optional emoji icon for the Perks timeline ----------
ALTER TABLE rewards ADD COLUMN IF NOT EXISTS icon varchar(16);

-- ---------- 50 interactive map locations (was `const locations` in index.html) ----------
CREATE TABLE IF NOT EXISTS map_locations (
    id        integer PRIMARY KEY,
    latitude  numeric(10,6) NOT NULL,
    longitude numeric(10,6) NOT NULL,
    status    varchar(50)  NOT NULL,
    type      varchar(100) NOT NULL,
    urgency   varchar(20)  NOT NULL
);

-- ---------- hub / dumping alerts (was `const crowdedAlerts`) ----------
CREATE TABLE IF NOT EXISTS crowded_alerts (
    id          integer PRIMARY KEY,
    name        varchar(255) NOT NULL,
    latitude    numeric(10,6) NOT NULL,
    longitude   numeric(10,6) NOT NULL,
    status      varchar(20)  NOT NULL,   -- marker color class: blue / red
    type        varchar(20)  NOT NULL,   -- positive / negative
    description text
);

-- ---------- community 311 feed (was `let public311Reports`) ----------
CREATE TABLE IF NOT EXISTS public_311_reports (
    id           serial PRIMARY KEY,
    user_id      uuid REFERENCES users(id) ON DELETE SET NULL,
    title        varchar(255) NOT NULL,
    category     varchar(255) NOT NULL,
    location     varchar(255) NOT NULL,
    description  text,
    reporter     varchar(255) NOT NULL,  -- display name at time of report, or 'Anonymous Citizen'
    is_anonymous boolean NOT NULL DEFAULT false,
    status       varchar(30) NOT NULL DEFAULT 'PENDING',
    type         varchar(20) NOT NULL DEFAULT 'negative',  -- positive / pending / negative
    created_at   timestamptz DEFAULT CURRENT_TIMESTAMP
);

-- ---------- volunteer cleanup registrations (volunteer modal) ----------
-- NOTE: the government ID number typed in the form is intentionally NOT stored.
CREATE TABLE IF NOT EXISTS volunteer_signups (
    id            serial PRIMARY KEY,
    user_id       uuid REFERENCES users(id) ON DELETE CASCADE,
    full_name     varchar(255) NOT NULL,
    date_of_birth date NOT NULL,
    event_name    varchar(255) NOT NULL,
    created_at    timestamptz DEFAULT CURRENT_TIMESTAMP
);

-- ---------- community eco chat ----------
CREATE TABLE IF NOT EXISTS chat_messages (
    id         serial PRIMARY KEY,
    user_id    uuid REFERENCES users(id) ON DELETE SET NULL,
    author     varchar(255) NOT NULL,
    body       text NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP
);

-- ================= DATA =================

INSERT INTO map_locations (id, latitude, longitude, status, type, urgency) VALUES
  (1, 40.7128, -74.006, 'Overly Trashed', 'Park Bench', 'High'),
  (2, 40.7135, -74.0048, 'Cleaned', 'Bus Stop', 'Low'),
  (3, 40.7142, -74.0075, 'Needs Attention', 'Sidewalk', 'Medium'),
  (4, 40.711, -74.0012, 'Overflowing Bin', 'Waste Can', 'High'),
  (5, 40.715, -74.009, 'Cleaned', 'Plaza', 'Low'),
  (6, 40.7161, -74.0031, 'Overly Trashed', 'Alleyway', 'High'),
  (7, 40.7121, -74.0088, 'Hazmat Reported', 'Dumping Site', 'Critical'),
  (8, 40.7175, -74.0055, 'Cleaned', 'Subway Entrance', 'Low'),
  (9, 40.718, -74.002, 'Needs Attention', 'Park Lawn', 'Medium'),
  (10, 40.7105, -74.0099, 'Overly Trashed', 'Street Corner', 'High'),
  (11, 40.7131, -74.0019, 'Cleaned', 'Crosswalk', 'Low'),
  (12, 40.7148, -74.0042, 'Overflowing Bin', 'Recycling Hub', 'High'),
  (13, 40.7192, -74.0068, 'Needs Attention', 'Bike Lane', 'Medium'),
  (14, 40.7118, -74.0035, 'Cleaned', 'Park Trail', 'Low'),
  (15, 40.7165, -74.0081, 'Overly Trashed', 'Parking Lot', 'High'),
  (16, 40.7139, -74.0095, 'Cleaned', 'Fountain Area', 'Low'),
  (17, 40.7101, -74.004, 'Needs Attention', 'Commercial Strip', 'Medium'),
  (18, 40.7155, -74.0015, 'Overly Trashed', 'Underpass', 'High'),
  (19, 40.7171, -74.0092, 'Cleaned', 'Playground', 'Low'),
  (20, 40.7125, -74.0051, 'Overflowing Bin', 'Food Court Exit', 'High'),
  (21, 40.7188, -74.0039, 'Cleaned', 'Dog Park', 'Low'),
  (22, 40.714, -74.001, 'Needs Attention', 'Train Platform', 'Medium'),
  (23, 40.7112, -74.0078, 'Overly Trashed', 'Vacant Lot', 'High'),
  (24, 40.7168, -74.0049, 'Cleaned', 'Waterfront Walk', 'Low'),
  (25, 40.7133, -74.0083, 'Hazmat Reported', 'Industrial Edge', 'Critical'),
  (26, 40.7198, -74.0011, 'Needs Attention', 'Bus Terminal', 'Medium'),
  (27, 40.7108, -74.0059, 'Cleaned', 'School Zone', 'Low'),
  (28, 40.7152, -74.0033, 'Overly Trashed', 'Construction Perimeter', 'High'),
  (29, 40.7177, -74.0071, 'Cleaned', 'Community Garden', 'Low'),
  (30, 40.7123, -74.0025, 'Overflowing Bin', 'Main Street', 'High'),
  (31, 40.7145, -74.0063, 'Needs Attention', 'Taxi Stand', 'Medium'),
  (32, 40.7183, -74.0044, 'Cleaned', 'Library Plaza', 'Low'),
  (33, 40.7104, -74.0085, 'Overly Trashed', 'Drainage Ditch', 'High'),
  (34, 40.716, -74.0018, 'Cleaned', 'Skatepark', 'Low'),
  (35, 40.7137, -74.007, 'Needs Attention', 'Outdoor Seating', 'Medium'),
  (36, 40.719, -74.008, 'Overflowing Bin', 'Stadium Entrance', 'High'),
  (37, 40.7116, -74.0022, 'Cleaned', 'Pedestrian Bridge', 'Low'),
  (38, 40.7158, -74.0097, 'Overly Trashed', 'Behind Shopping Center', 'High'),
  (39, 40.7129, -74.0038, 'Cleaned', 'City Hall Steps', 'Low'),
  (40, 40.7173, -74.0028, 'Needs Attention', 'Market Alley', 'Medium'),
  (41, 40.7109, -74.0066, 'Overly Trashed', 'Highway Ramp', 'High'),
  (42, 40.7143, -74.0014, 'Cleaned', 'Post Office Lawn', 'Low'),
  (43, 40.7185, -74.0059, 'Needs Attention', 'Residential Corner', 'Medium'),
  (44, 40.7119, -74.0091, 'Overflowing Bin', 'Ferry Terminal', 'High'),
  (45, 40.7163, -74.0037, 'Cleaned', 'Theater District Walkway', 'Low'),
  (46, 40.713, -74.0079, 'Overly Trashed', 'Storm Drain Area', 'High'),
  (47, 40.7195, -74.0026, 'Cleaned', 'Visitor Center', 'Low'),
  (48, 40.7102, -74.0017, 'Needs Attention', 'Loading Dock', 'Medium'),
  (49, 40.7149, -74.0086, 'Overly Trashed', 'Bridge Footing', 'High'),
  (50, 40.7169, -74.0062, 'Cleaned', 'Recreation Center', 'Low')
ON CONFLICT (id) DO NOTHING;

INSERT INTO crowded_alerts (id, name, latitude, longitude, status, type, description) VALUES
  (1, 'CSH Drop Bin',             40.8208, -73.8860, 'blue', 'positive', 'Official recycling drop-off hub.'),
  (2, 'Yankee Stadium Smart Bin', 40.8296, -73.9262, 'blue', 'positive', 'Solar-powered recycling compactor.'),
  (3, 'Mott Haven Heap 311',      40.8110, -73.9260, 'red',  'negative', 'Severe illegal dumping.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public_311_reports (id, title, category, location, reporter, is_anonymous, status, type, created_at) VALUES
  (101, 'Illegal Dumping',               'Furniture & Drywall Dumped', 'E 149th St & 3rd Ave',        'Anonymous Citizen',  true,  'ACTIVE',     'negative', now() - interval '12 minutes'),
  (102, 'Overfilled Bin Clearance',      'Recycling Overflow',         'CSH Drop Bin - E 161st St',   'Maria (CSH Staff)',  false, 'RESOLVED',   'positive', now() - interval '45 minutes'),
  (103, 'Abandoned Construction Debris', 'Hazardous Chemical/Debris',  'Jerome Ave & 170th St',       'Anonymous Citizen',  true,  'DISPATCHED', 'pending',  now() - interval '2 hours')
ON CONFLICT (id) DO NOTHING;
SELECT setval(pg_get_serial_sequence('public_311_reports', 'id'),
              GREATEST((SELECT max(id) FROM public_311_reports), 103));

-- The two starter chat messages from the page's HTML
INSERT INTO chat_messages (id, author, body, created_at) VALUES
  (1, 'Alex (Mott Haven)',  'Heavy dumping spotted near E 149th St! 🚨',          now() - interval '20 minutes'),
  (2, 'Maria (CSH Center)', 'Cleaned up 4 bags of plastic near the CSH Hub! ♻️', now() - interval '10 minutes')
ON CONFLICT (id) DO NOTHING;
SELECT setval(pg_get_serial_sequence('chat_messages', 'id'),
              GREATEST((SELECT max(id) FROM chat_messages), 2));

-- Reward checkpoints from the Perks timeline (merged into the existing rewards table)
INSERT INTO rewards (title, description, points_required, icon)
SELECT v.title, v.description, v.points_required, v.icon
FROM (VALUES
  ('$5 Amazon Gift Card',      'Digital gift code delivered straight to your verified account inbox upon reach.', 1250, '🎁'),
  ('RECYCLEAN Baseball Cap',   'Official limited edition embroidered eco-friendly RECYCLEAN cap.',                2000, '🧢'),
  ('RECYCLEAN T-Shirt',        '100% organic recycled cotton community volunteer merch T-Shirt.',                 3500, '👕')
) AS v(title, description, points_required, icon)
WHERE NOT EXISTS (SELECT 1 FROM rewards r WHERE r.title = v.title);

-- Icons for the three rewards that were already in the DB (only if not set)
UPDATE rewards SET icon = '🚇' WHERE title = 'Eco Transit Pass $5'       AND icon IS NULL;
UPDATE rewards SET icon = '🍶' WHERE title = 'Reusable Bottle Voucher'   AND icon IS NULL;
UPDATE rewards SET icon = '🌱' WHERE title = 'Community Garden Pass'     AND icon IS NULL;

COMMIT;
