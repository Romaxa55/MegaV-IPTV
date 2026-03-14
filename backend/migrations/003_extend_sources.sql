-- Extend iptv_sources with GitHub crawler metadata
ALTER TABLE iptv_sources ADD COLUMN IF NOT EXISTS github_repo TEXT;
ALTER TABLE iptv_sources ADD COLUMN IF NOT EXISTS github_stars INT NOT NULL DEFAULT 0;
ALTER TABLE iptv_sources ADD COLUMN IF NOT EXISTS last_commit_at TIMESTAMPTZ;
ALTER TABLE iptv_sources ADD COLUMN IF NOT EXISTS discovered_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE iptv_sources ADD COLUMN IF NOT EXISTS file_path TEXT;
ALTER TABLE iptv_sources ADD COLUMN IF NOT EXISTS raw_url TEXT;

CREATE INDEX IF NOT EXISTS idx_iptv_sources_github_repo ON iptv_sources(github_repo);
CREATE INDEX IF NOT EXISTS idx_iptv_sources_source_type ON iptv_sources(source_type);
