-- Add feed/timeshift support to streams
ALTER TABLE iptv_streams ADD COLUMN IF NOT EXISTS feed TEXT;
ALTER TABLE iptv_streams ADD COLUMN IF NOT EXISTS timeshift_hours INT DEFAULT 0;

-- EPG programs now link to reference channels, not old iptv_channels
-- Add reference_channel_id to epg programs for direct lookup
ALTER TABLE iptv_epg_programs ADD COLUMN IF NOT EXISTS reference_channel_id TEXT;

CREATE INDEX IF NOT EXISTS idx_epg_ref_channel ON iptv_epg_programs(reference_channel_id);
CREATE INDEX IF NOT EXISTS idx_epg_ref_channel_time ON iptv_epg_programs(reference_channel_id, start_time, end_time);

-- EPG sources: track which EPG XML files we fetch per country/site
CREATE TABLE IF NOT EXISTS iptv_epg_sources (
    id SERIAL PRIMARY KEY,
    site TEXT NOT NULL,
    lang TEXT NOT NULL,
    url TEXT NOT NULL,
    channel_count INT DEFAULT 0,
    last_fetched_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(site, lang)
);
