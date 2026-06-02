"""Schema for image search database (images + CLIP embeddings)."""

# Image search database schema - only images and CLIP embeddings with vector search
IMAGE_SCHEMA = """
-- Images table
CREATE TABLE IF NOT EXISTS images (
    rowid INTEGER PRIMARY KEY,
    filename TEXT NOT NULL,
    image_path TEXT NOT NULL,
    image_type TEXT,
    width INTEGER,
    height INTEGER,
    file_size INTEGER,
    begin INTEGER,
    ocr_text TEXT
);

CREATE INDEX IF NOT EXISTS idx_images_filename ON images(filename);
CREATE INDEX IF NOT EXISTS idx_images_path ON images(image_path);

-- Image embeddings table (CLIP) with libsql vector search
-- Note: F32_BLOB(512) is required for libsql vector search (clip-ViT-B-32 model)
CREATE TABLE IF NOT EXISTS image_embeddings (
    rowid INTEGER PRIMARY KEY,
    image_id INTEGER NOT NULL,
    clip_model TEXT NOT NULL,
    embedding_vector F32_BLOB(512) NOT NULL,
    embedding_dim INTEGER NOT NULL,
    created_at TEXT,
    FOREIGN KEY(image_id) REFERENCES images(rowid) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_image_embeddings_image ON image_embeddings(image_id);
CREATE INDEX IF NOT EXISTS idx_image_embeddings_model ON image_embeddings(clip_model);

-- Vector index for fast image search using libsql_vector_idx
CREATE INDEX IF NOT EXISTS idx_image_embeddings_vector ON image_embeddings(libsql_vector_idx(embedding_vector));
"""
