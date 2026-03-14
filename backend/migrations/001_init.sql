-- Channels parsed directly from the M3U playlist
CREATE TABLE IF NOT EXISTS channels (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    group_title TEXT NOT NULL DEFAULT '',
    stream_url TEXT NOT NULL UNIQUE,
    tvg_rec INT NOT NULL DEFAULT 0,
    logo_url TEXT,
    thumbnail_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_channels_group ON channels(group_title);
CREATE INDEX IF NOT EXISTS idx_channels_name ON channels USING gin (to_tsvector('simple', name));

-- EPG programs linked to channels by name matching
CREATE TABLE IF NOT EXISTS epg_programs (
    id SERIAL PRIMARY KEY,
    channel_id INT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT,
    icon TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    lang TEXT
);

CREATE INDEX IF NOT EXISTS idx_epg_channel_time ON epg_programs(channel_id, start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_epg_start ON epg_programs(start_time);
CREATE INDEX IF NOT EXISTS idx_epg_end ON epg_programs(end_time);

-- Playlist/EPG source config (single row, populated from env vars at startup)
CREATE TABLE IF NOT EXISTS config (
    id INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    playlist_url TEXT NOT NULL DEFAULT '',
    epg_url TEXT NOT NULL DEFAULT '',
    last_playlist_sync TIMESTAMPTZ,
    last_epg_sync TIMESTAMPTZ
);
