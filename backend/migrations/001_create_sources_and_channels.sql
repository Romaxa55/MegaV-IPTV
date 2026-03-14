-- IPTV Sources
CREATE TABLE IF NOT EXISTS iptv_sources (
    id SERIAL PRIMARY KEY,
    url TEXT UNIQUE NOT NULL,
    name TEXT,
    source_type TEXT NOT NULL DEFAULT 'github',
    last_parsed_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'active',
    channel_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- IPTV Channel Groups
CREATE TABLE IF NOT EXISTS iptv_groups (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    channel_count INT NOT NULL DEFAULT 0,
    icon TEXT
);

-- IPTV Channels
CREATE TABLE IF NOT EXISTS iptv_channels (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    logo_url TEXT,
    group_title TEXT,
    country TEXT,
    language TEXT,
    tvg_id TEXT,
    source_id INT REFERENCES iptv_sources(id) ON DELETE SET NULL,
    is_working BOOLEAN,
    last_checked_at TIMESTAMPTZ,
    video_codec TEXT,
    audio_codec TEXT,
    resolution TEXT,
    thumbnail_url TEXT,
    thumbnail_updated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_iptv_channels_group ON iptv_channels(group_title);
CREATE INDEX IF NOT EXISTS idx_iptv_channels_country ON iptv_channels(country);
CREATE INDEX IF NOT EXISTS idx_iptv_channels_working ON iptv_channels(is_working);
CREATE INDEX IF NOT EXISTS idx_iptv_channels_tvg_id ON iptv_channels(tvg_id);
CREATE INDEX IF NOT EXISTS idx_iptv_channels_source ON iptv_channels(source_id);
CREATE INDEX IF NOT EXISTS idx_iptv_channels_url ON iptv_channels(url);
