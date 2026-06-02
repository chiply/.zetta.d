"""Schema for semantic search database (chunks + embeddings)."""

# Semantic search database schema - only chunks and embeddings with vector search
SEMANTIC_SCHEMA = """
-- Chunks table for semantic search
CREATE TABLE IF NOT EXISTS chunks (
    rowid INTEGER PRIMARY KEY,
    filename TEXT NOT NULL,
    headline_id INTEGER,
    chunk_text TEXT NOT NULL,
    chunk_type TEXT,
    begin_line INTEGER NOT NULL,
    end_line INTEGER NOT NULL,
    char_offset INTEGER,
    linked_file_id INTEGER,
    linked_file_path TEXT
);

CREATE INDEX IF NOT EXISTS idx_chunks_filename ON chunks(filename);
CREATE INDEX IF NOT EXISTS idx_chunks_linked_file ON chunks(linked_file_path);

-- Embeddings table with libsql vector search
-- Note: F32_BLOB(384) is required for libsql vector search (all-MiniLM-L6-v2 model)
CREATE TABLE IF NOT EXISTS embeddings (
    rowid INTEGER PRIMARY KEY,
    chunk_id INTEGER NOT NULL,
    embedding_model TEXT NOT NULL,
    embedding_vector F32_BLOB(384) NOT NULL,
    embedding_dim INTEGER NOT NULL,
    created_at TEXT,
    FOREIGN KEY(chunk_id) REFERENCES chunks(rowid) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_embeddings_chunk ON embeddings(chunk_id);
CREATE INDEX IF NOT EXISTS idx_embeddings_model ON embeddings(embedding_model);

-- Vector index for fast semantic search using libsql_vector_idx
CREATE INDEX IF NOT EXISTS idx_embeddings_vector ON embeddings(libsql_vector_idx(embedding_vector));
"""
