-- EPG Programs
CREATE TABLE IF NOT EXISTS iptv_epg_programs (
    id SERIAL PRIMARY KEY,
    channel_id TEXT NOT NULL REFERENCES iptv_channels(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT,
    icon TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    lang TEXT
);

CREATE INDEX IF NOT EXISTS idx_iptv_epg_channel_time ON iptv_epg_programs(channel_id, start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_iptv_epg_start ON iptv_epg_programs(start_time);
CREATE INDEX IF NOT EXISTS idx_iptv_epg_end ON iptv_epg_programs(end_time);

-- EPG Channel Mapping (smart matching cache)
CREATE TABLE IF NOT EXISTS iptv_epg_channel_map (
    id SERIAL PRIMARY KEY,
    channel_id TEXT NOT NULL REFERENCES iptv_channels(id) ON DELETE CASCADE,
    epg_channel_id TEXT NOT NULL,
    confidence FLOAT NOT NULL DEFAULT 1.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(channel_id, epg_channel_id)
);

CREATE INDEX IF NOT EXISTS idx_iptv_epg_map_channel ON iptv_epg_channel_map(channel_id);
CREATE INDEX IF NOT EXISTS idx_iptv_epg_map_epg ON iptv_epg_channel_map(epg_channel_id);
