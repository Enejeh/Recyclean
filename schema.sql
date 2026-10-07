-- schema.sql — full current schema of the Recyclean database (Postgres).
-- Tables marked (original) existed before the backend was added; the rest were added
-- (by seed_from_page.sql) to hold data that used to be hard-coded in index.html.

-- (original) + signup columns date_of_birth .. parent_consent
CREATE TABLE users (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email          varchar(255) NOT NULL UNIQUE,
    password_hash  varchar(255) NOT NULL,          -- bcrypt
    display_name   varchar(100) NOT NULL,          -- "Username" on the signup form
    points_balance integer DEFAULT 0,
    created_at     timestamptz DEFAULT CURRENT_TIMESTAMP,
    date_of_birth  date,
    is_over_18     boolean DEFAULT true,
    parent_name    varchar(255),
    parent_email   varchar(255),
    parent_consent boolean DEFAULT false
);

-- (original) community pins; "Report Litter Site" submissions are saved here
CREATE TABLE map_markers (
    id          serial PRIMARY KEY,
    user_id     uuid REFERENCES users(id) ON DELETE CASCADE,
    latitude    numeric(10,8) NOT NULL,
    longitude   numeric(11,8) NOT NULL,
    category    varchar(50)  NOT NULL,   -- Cleaned / Needs Attention / Overly Trashed / Overflowing Bin / Public Bin ...
    title       varchar(150) NOT NULL,
    description text,
    created_at  timestamptz DEFAULT CURRENT_TIMESTAMP
);

-- (original) cached NYC Open Data 311 complaints (shown at the end of the 311 feed)
CREATE TABLE nyc_311_cache (
    unique_key     varchar(50) PRIMARY KEY,
    complaint_type varchar(100) NOT NULL,
    descriptor     text,
    latitude       numeric(10,8),
    longitude      numeric(11,8),
    status         varchar(50) NOT NULL,
    last_synced    timestamptz DEFAULT CURRENT_TIMESTAMP
);

-- (original) + icon; also holds the Perks timeline checkpoints
CREATE TABLE rewards (
    id              serial PRIMARY KEY,
    title           varchar(150) NOT NULL,
    description     text NOT NULL,
    points_required integer NOT NULL,
    icon            varchar(16)
);

-- (original)
CREATE TABLE user_claimed_rewards (
    id              serial PRIMARY KEY,
    user_id         uuid REFERENCES users(id) ON DELETE CASCADE,
    reward_id       integer REFERENCES rewards(id) ON DELETE CASCADE,
    redemption_code varchar(50) NOT NULL UNIQUE,
    claimed_at      timestamptz DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, reward_id)
);

-- (original) AI scanner log
CREATE TABLE scan_logs (
    id                serial PRIMARY KEY,
    user_id           uuid REFERENCES users(id) ON DELETE CASCADE,
    detected_category varchar(100) NOT NULL,
    confidence_score  numeric(5,2) NOT NULL,
    points_awarded    integer NOT NULL,
    created_at        timestamptz DEFAULT CURRENT_TIMESTAMP
);

-- (added) the 50 map locations (was `const locations` in index.html)
CREATE TABLE map_locations (
    id        integer PRIMARY KEY,
    latitude  numeric(10,6) NOT NULL,
    longitude numeric(10,6) NOT NULL,
    status    varchar(50)  NOT NULL,
    type      varchar(100) NOT NULL,
    urgency   varchar(20)  NOT NULL
);

-- (added) hub / dumping alerts (was `const crowdedAlerts`)
CREATE TABLE crowded_alerts (
    id          integer PRIMARY KEY,
    name        varchar(255) NOT NULL,
    latitude    numeric(10,6) NOT NULL,
    longitude   numeric(10,6) NOT NULL,
    status      varchar(20)  NOT NULL,   -- marker color: blue / red
    type        varchar(20)  NOT NULL,   -- positive / negative
    description text
);

-- (added) community 311 feed (was `let public311Reports`)
CREATE TABLE public_311_reports (
    id           serial PRIMARY KEY,
    user_id      uuid REFERENCES users(id) ON DELETE SET NULL,
    title        varchar(255) NOT NULL,
    category     varchar(255) NOT NULL,
    location     varchar(255) NOT NULL,
    description  text,
    reporter     varchar(255) NOT NULL,
    is_anonymous boolean NOT NULL DEFAULT false,
    status       varchar(30) NOT NULL DEFAULT 'PENDING',
    type         varchar(20) NOT NULL DEFAULT 'negative',
    created_at   timestamptz DEFAULT CURRENT_TIMESTAMP
);

-- (added) volunteer cleanup registrations (government ID number is NOT stored)
CREATE TABLE volunteer_signups (
    id            serial PRIMARY KEY,
    user_id       uuid REFERENCES users(id) ON DELETE CASCADE,
    full_name     varchar(255) NOT NULL,
    date_of_birth date NOT NULL,
    event_name    varchar(255) NOT NULL,
    created_at    timestamptz DEFAULT CURRENT_TIMESTAMP
);

-- (added) community eco chat
CREATE TABLE chat_messages (
    id         serial PRIMARY KEY,
    user_id    uuid REFERENCES users(id) ON DELETE SET NULL,
    author     varchar(255) NOT NULL,
    body       text NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP
);
