#!/usr/bin/env python3
"""Migration script to convert BLOB columns to F32_BLOB for vector search.

This script handles the migration from the old BLOB-based embedding storage
to the new F32_BLOB format required by libsql native vector search.
"""

import libsql
import sys
from pathlib import Path

def migrate_database(db_path: str):
    """Migrate database from BLOB to F32_BLOB vectors."""
    print(f"Migrating database: {db_path}")

    # Backup database
    backup_path = f"{db_path}.backup"
    print(f"Creating backup at: {backup_path}")
    Path(backup_path).write_bytes(Path(db_path).read_bytes())

    conn = libsql.connect(db_path)
    cursor = conn.cursor()

    try:
        print("\nStep 1: Checking current schema...")
        cursor.execute("PRAGMA table_info(embeddings)")
        cols = cursor.fetchall()
        embedding_col = [c for c in cols if c[1] == 'embedding_vector']
        if embedding_col:
            print(f"  Current embedding_vector type: {embedding_col[0][2]}")

        # Check if we need to migrate
        if embedding_col and 'F32_BLOB' in embedding_col[0][2]:
            print("  ✓ Database already uses F32_BLOB format!")
            return

        print("\nStep 2: Dropping vector indexes...")
        cursor.execute("DROP INDEX IF EXISTS idx_embeddings_vector")
        cursor.execute("DROP INDEX IF EXISTS idx_image_embeddings_vector")

        print("\nStep 3: Recreating embeddings table with F32_BLOB...")
        # Rename old table
        cursor.execute("ALTER TABLE embeddings RENAME TO embeddings_old")

        # Create new table with F32_BLOB
        cursor.execute("""
            CREATE TABLE embeddings (
                rowid INTEGER PRIMARY KEY,
                chunk_id INTEGER NOT NULL,
                embedding_model TEXT NOT NULL,
                embedding_vector F32_BLOB(384) NOT NULL,
                embedding_dim INTEGER NOT NULL,
                created_at TEXT,
                FOREIGN KEY(chunk_id) REFERENCES chunks(rowid) ON DELETE CASCADE
            )
        """)

        # Copy data (BLOB data is binary compatible with F32_BLOB)
        print("  Copying embedding data...")
        cursor.execute("""
            INSERT INTO embeddings (rowid, chunk_id, embedding_model, embedding_vector, embedding_dim, created_at)
            SELECT rowid, chunk_id, embedding_model, embedding_vector, embedding_dim, created_at
            FROM embeddings_old
        """)

        row_count = cursor.execute("SELECT COUNT(*) FROM embeddings").fetchone()[0]
        print(f"  ✓ Copied {row_count} embeddings")

        # Drop old table
        cursor.execute("DROP TABLE embeddings_old")

        # Recreate indexes
        print("\nStep 4: Creating indexes...")
        cursor.execute("CREATE INDEX idx_embeddings_chunk ON embeddings(chunk_id)")
        cursor.execute("CREATE INDEX idx_embeddings_model ON embeddings(embedding_model)")
        cursor.execute("CREATE INDEX idx_embeddings_vector ON embeddings(libsql_vector_idx(embedding_vector))")

        print("\nStep 5: Recreating image_embeddings table...")
        cursor.execute("ALTER TABLE image_embeddings RENAME TO image_embeddings_old")

        cursor.execute("""
            CREATE TABLE image_embeddings (
                rowid INTEGER PRIMARY KEY,
                image_id INTEGER NOT NULL,
                clip_model TEXT NOT NULL,
                embedding_vector F32_BLOB(512) NOT NULL,
                embedding_dim INTEGER NOT NULL,
                created_at TEXT,
                FOREIGN KEY(image_id) REFERENCES images(rowid) ON DELETE CASCADE
            )
        """)

        print("  Copying image embedding data...")
        cursor.execute("""
            INSERT INTO image_embeddings (rowid, image_id, clip_model, embedding_vector, embedding_dim, created_at)
            SELECT rowid, image_id, clip_model, embedding_vector, embedding_dim, created_at
            FROM image_embeddings_old
        """)

        image_count = cursor.execute("SELECT COUNT(*) FROM image_embeddings").fetchone()[0]
        print(f"  ✓ Copied {image_count} image embeddings")

        cursor.execute("DROP TABLE image_embeddings_old")

        print("\nStep 6: Creating image embedding indexes...")
        cursor.execute("CREATE INDEX idx_image_embeddings_image ON image_embeddings(image_id)")
        cursor.execute("CREATE INDEX idx_image_embeddings_model ON image_embeddings(clip_model)")
        cursor.execute("CREATE INDEX idx_image_embeddings_vector ON image_embeddings(libsql_vector_idx(embedding_vector))")

        conn.commit()
        print("\n✓ Migration completed successfully!")
        print(f"\nBackup saved at: {backup_path}")
        print("You can delete the backup once you've verified everything works.")

    except Exception as e:
        print(f"\n✗ Migration failed: {e}", file=sys.stderr)
        print(f"Restoring from backup...", file=sys.stderr)
        conn.close()
        Path(db_path).write_bytes(Path(backup_path).read_bytes())
        print(f"Database restored from backup", file=sys.stderr)
        sys.exit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    if len(sys.argv) > 1:
        db_path = sys.argv[1]
    else:
        # Default path
        import os
        cache_dir = os.path.expanduser("~/Dropbox/emacs/cache/org-db-v3")
        db_path = os.path.join(cache_dir, "org-db-v3.db")

    if not Path(db_path).exists():
        print(f"Database not found: {db_path}", file=sys.stderr)
        sys.exit(1)

    migrate_database(db_path)
