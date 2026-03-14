-- Drop old FK constraints that reference iptv_channels
ALTER TABLE iptv_epg_programs DROP CONSTRAINT IF EXISTS iptv_epg_programs_channel_id_fkey;
ALTER TABLE iptv_epg_channel_map DROP CONSTRAINT IF EXISTS iptv_epg_channel_map_channel_id_fkey;

-- Add new FK constraints referencing iptv_reference_channels
ALTER TABLE iptv_epg_programs
    ADD CONSTRAINT iptv_epg_programs_channel_id_fkey
    FOREIGN KEY (channel_id) REFERENCES iptv_reference_channels(id) ON DELETE CASCADE;

ALTER TABLE iptv_epg_channel_map
    ADD CONSTRAINT iptv_epg_channel_map_channel_id_fkey
    FOREIGN KEY (channel_id) REFERENCES iptv_reference_channels(id) ON DELETE CASCADE;
