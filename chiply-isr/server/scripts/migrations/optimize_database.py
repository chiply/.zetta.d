#!/usr/bin/env python3
"""
Database optimization script for org-db-v3.

This script runs ANALYZE to update query optimizer statistics,
which significantly improves vector search performance.

Usage:
    python3 optimize_database.py [--dry-run]
"""

import sys
import time
import libsql
import argparse
from pathlib import Path

DB_PATH = Path.home() / "Dropbox/emacs/cache/org-db-v3/org-db-v3.db"

def format_time(seconds):
    """Format seconds as human-readable time."""
    if seconds < 1:
        return f"{seconds*1000:.0f}ms"
    return f"{seconds:.2f}s"

def check_optimizer_stats(conn):
    """Check if ANALYZE has been run before."""
    cursor = conn.cursor()

    # Check sqlite_stat1 table
    cursor.execute("SELECT COUNT(*) FROM sqlite_stat1")
    count = cursor.fetchone()[0]

    print(f"\nCurrent optimizer statistics:")
    print(f"  Entries in sqlite_stat1: {count}")

    if count == 0:
        print("  ⚠️  WARNING: No optimizer statistics found!")
        print("     This is your first optimization run.")
        return False
    else:
        print("  ✅ Optimizer statistics exist")

        # Show last analyze time (approximate by checking stats)
        cursor.execute("SELECT tbl, idx, stat FROM sqlite_stat1 LIMIT 5")
        print("\n  Sample statistics:")
        for row in cursor.fetchall():
            tbl, idx, stat = row
            print(f"    {tbl}.{idx}: {stat}")

        return True

def get_database_stats(conn):
    """Get database statistics."""
    cursor = conn.cursor()

    stats = {}

    # Count major tables
    tables = ['files', 'chunks', 'embeddings', 'images', 'image_embeddings']
    for table in tables:
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        stats[table] = cursor.fetchone()[0]

    # Count indexes
    cursor.execute("""
        SELECT COUNT(*)
        FROM sqlite_master
        WHERE type='index' AND sql IS NOT NULL
    """)
    stats['indexes'] = cursor.fetchone()[0]

    return stats

def optimize_database(conn, dry_run=False):
    """Run ANALYZE to optimize database."""
    cursor = conn.cursor()

    print("\n" + "="*70)
    print("DATABASE OPTIMIZATION".center(70))
    print("="*70)

    if dry_run:
        print("\n🔍 DRY RUN MODE - No changes will be made")

    stats = get_database_stats(conn)

    print(f"\nDatabase statistics:")
    print(f"  Files: {stats['files']:,}")
    print(f"  Chunks: {stats['chunks']:,}")
    print(f"  Embeddings: {stats['embeddings']:,}")
    print(f"  Images: {stats['images']:,}")
    print(f"  Image embeddings: {stats['image_embeddings']:,}")
    print(f"  Total indexes: {stats['indexes']}")

    has_stats = check_optimizer_stats(conn)

    if dry_run:
        print("\n✓ Dry run complete - database not modified")
        return

    # Run ANALYZE
    print("\n" + "-"*70)
    print("Running ANALYZE to update query optimizer statistics...")
    print("This may take several minutes for large databases...")
    print("-"*70)

    start = time.time()
    try:
        cursor.execute("ANALYZE")
        conn.commit()
        elapsed = time.time() - start

        print(f"\n✅ ANALYZE completed successfully in {format_time(elapsed)}")

        # Verify it worked
        cursor.execute("SELECT COUNT(*) FROM sqlite_stat1")
        new_count = cursor.fetchone()[0]
        print(f"\n   sqlite_stat1 now has {new_count} entries")

        if not has_stats:
            print("   🎉 First-time optimization complete!")
        else:
            print("   ✓ Statistics updated")

        return True

    except Exception as e:
        print(f"\n❌ ERROR during ANALYZE: {e}")
        return False

def verify_indexes(conn):
    """Verify vector indexes exist."""
    cursor = conn.cursor()

    print("\n" + "-"*70)
    print("Verifying vector indexes...")
    print("-"*70)

    # Check embeddings vector index
    cursor.execute("""
        SELECT name FROM sqlite_master
        WHERE type='index' AND name='idx_embeddings_vector'
    """)
    if cursor.fetchone():
        print("  ✅ idx_embeddings_vector exists (for text search)")
    else:
        print("  ❌ idx_embeddings_vector MISSING (text search will be slow!)")

    # Check image embeddings vector index
    cursor.execute("""
        SELECT name FROM sqlite_master
        WHERE type='index' AND name='idx_image_embeddings_vector'
    """)
    if cursor.fetchone():
        print("  ✅ idx_image_embeddings_vector exists (for image search)")
    else:
        print("  ❌ idx_image_embeddings_vector MISSING (image search will be slow!)")

def main():
    parser = argparse.ArgumentParser(
        description="Optimize org-db-v3 database for better search performance"
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be done without making changes'
    )
    args = parser.parse_args()

    print("="*70)
    print("ORG-DB V3 DATABASE OPTIMIZER".center(70))
    print("="*70)

    # Check database exists
    if not DB_PATH.exists():
        print(f"\n❌ ERROR: Database not found at {DB_PATH}")
        sys.exit(1)

    print(f"\nDatabase: {DB_PATH}")
    print(f"Size: {DB_PATH.stat().st_size / (1024**3):.2f} GB")

    # Connect
    try:
        conn = libsql.connect(str(DB_PATH))
        print("✅ Connected to database")
    except Exception as e:
        print(f"❌ ERROR: Could not connect to database: {e}")
        sys.exit(1)

    try:
        # Verify indexes
        verify_indexes(conn)

        # Optimize
        success = optimize_database(conn, dry_run=args.dry_run)

        if success:
            print("\n" + "="*70)
            print("OPTIMIZATION COMPLETE".center(70))
            print("="*70)
            print("\nNext steps:")
            print("  1. Restart the org-db server")
            print("  2. Test search performance")
            print("  3. Run optimization weekly for large databases")
        else:
            print("\n" + "="*70)
            print("OPTIMIZATION FAILED".center(70))
            print("="*70)
            sys.exit(1)

    finally:
        conn.close()

if __name__ == "__main__":
    main()
