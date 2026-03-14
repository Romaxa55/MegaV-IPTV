-- Reference channels from iptv-org/database (~39K known channels worldwide)
CREATE TABLE IF NOT EXISTS iptv_reference_channels (
    id TEXT PRIMARY KEY,                  -- e.g. "PerviyKanal.ru"
    name TEXT NOT NULL,                   -- canonical name "Первый канал"
    alt_names TEXT[],                     -- alternative names array
    network TEXT,
    owners TEXT,
    country TEXT NOT NULL,                -- ISO 3166-1 alpha-2
    categories TEXT[],                    -- e.g. {"general","news"}
    is_nsfw BOOLEAN NOT NULL DEFAULT FALSE,
    launched TEXT,
    closed TEXT,
    replaced_by TEXT,
    website TEXT,
    logo_url TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ref_channels_country ON iptv_reference_channels(country);
CREATE INDEX IF NOT EXISTS idx_ref_channels_name ON iptv_reference_channels USING gin (to_tsvector('simple', name));
CREATE INDEX IF NOT EXISTS idx_ref_channels_alt_names ON iptv_reference_channels USING gin (alt_names);

-- Streams: concrete playback URLs linked to a reference channel
CREATE TABLE IF NOT EXISTS iptv_streams (
    id SERIAL PRIMARY KEY,
    channel_id TEXT REFERENCES iptv_reference_channels(id) ON DELETE SET NULL,
    url TEXT NOT NULL,
    source_id INT REFERENCES iptv_sources(id) ON DELETE SET NULL,
    original_name TEXT,                   -- name as it appeared in M3U
    original_group TEXT,                  -- group-title as it appeared in M3U
    quality TEXT,                         -- "1080p", "720p", "SD", etc.
    is_working BOOLEAN,
    last_checked_at TIMESTAMPTZ,
    response_time_ms INT,
    video_codec TEXT,
    audio_codec TEXT,
    resolution TEXT,
    uptime_pct FLOAT DEFAULT 0,
    check_count INT DEFAULT 0,
    ok_count INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(url)
);

CREATE INDEX IF NOT EXISTS idx_streams_channel ON iptv_streams(channel_id);
CREATE INDEX IF NOT EXISTS idx_streams_working ON iptv_streams(is_working);
CREATE INDEX IF NOT EXISTS idx_streams_source ON iptv_streams(source_id);

-- Unmatched streams: couldn't match to any reference channel
CREATE TABLE IF NOT EXISTS iptv_unmatched_streams (
    id SERIAL PRIMARY KEY,
    url TEXT NOT NULL UNIQUE,
    original_name TEXT,
    original_group TEXT,
    tvg_id TEXT,
    logo_url TEXT,
    country_hint TEXT,                    -- guessed from name/group
    source_id INT REFERENCES iptv_sources(id) ON DELETE SET NULL,
    is_working BOOLEAN,
    last_checked_at TIMESTAMPTZ,
    match_attempted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_unmatched_name ON iptv_unmatched_streams USING gin (to_tsvector('simple', original_name));
