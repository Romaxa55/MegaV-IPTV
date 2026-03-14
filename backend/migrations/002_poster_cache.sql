-- Persistent poster cache: survives EPG truncate, avoids re-fetching from Kinopoisk
CREATE TABLE IF NOT EXISTS poster_cache (
    title_hash TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    poster_url TEXT NOT NULL DEFAULT '',
    file_path TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
