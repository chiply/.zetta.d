#!/usr/bin/env python3
"""Profile semantic search to find bottlenecks."""

import time
import sys
import numpy as np
from org_db_server.services.embeddings import get_embedding_service
from org_db_server.services.database import Database
from org_db_server.config import settings

def profile_search(query: str = "test", limit: int = 10):
    """Profile each step of semantic search."""
    print(f"\nProfiling semantic search for query: '{query}' (limit={limit})")
    print("=" * 70)

    total_start = time.perf_counter()

    # Step 1: Get embedding service
    step_start = time.perf_counter()
    embedding_service = get_embedding_service("all-MiniLM-L6-v2")
    step_time = time.perf_counter() - step_start
    print(f"1. Get embedding service: {step_time*1000:.1f}ms")

    # Step 2: Generate query embedding
    step_start = time.perf_counter()
    query_embedding = embedding_service.generate_embedding(query)
    step_time = time.perf_counter() - step_start
    print(f"2. Generate query embedding: {step_time*1000:.1f}ms")

    # Step 3: Convert to bytes
    step_start = time.perf_counter()
    query_bytes = query_embedding.astype(np.float32).tobytes()
    step_time = time.perf_counter() - step_start
    print(f"3. Convert to bytes: {step_time*1000:.1f}ms")

    # Step 4: Database connection
    step_start = time.perf_counter()
    db = Database(settings.db_path)
    cursor = db.conn.cursor()
    step_time = time.perf_counter() - step_start
    print(f"4. Get database cursor: {step_time*1000:.1f}ms")

    # Step 5: Execute vector search query
    step_start = time.perf_counter()
    cursor.execute("""
        SELECT
            vt.id as chunk_id,
            c.chunk_text,
            c.chunk_type,
            c.begin_line,
            c.end_line,
            f.filename,
            lf.file_path as linked_file_path,
            lf.file_type as linked_file_type,
            e.embedding_vector
        FROM vector_top_k('idx_embeddings_vector', ?, ?) vt
        JOIN embeddings e ON e.rowid = vt.id
        JOIN chunks c ON c.rowid = e.chunk_id
        JOIN files f ON c.filename_id = f.rowid
        LEFT JOIN linked_files lf ON c.linked_file_id = lf.rowid
        WHERE e.embedding_model = ?
    """, [query_bytes, limit, "all-MiniLM-L6-v2"])
    step_time = time.perf_counter() - step_start
    print(f"5. Execute vector search query: {step_time*1000:.1f}ms")

    # Step 6: Fetch results
    step_start = time.perf_counter()
    rows = cursor.fetchall()
    step_time = time.perf_counter() - step_start
    print(f"6. Fetch results ({len(rows)} rows): {step_time*1000:.1f}ms")

    # Step 7: Calculate similarities
    step_start = time.perf_counter()
    for row in rows:
        embedding_bytes = row[8]
        stored_embedding = np.frombuffer(embedding_bytes, dtype=np.float32)
        similarity = float(embedding_service.similarity(query_embedding, stored_embedding))
    step_time = time.perf_counter() - step_start
    print(f"7. Calculate similarities: {step_time*1000:.1f}ms")

    total_time = time.perf_counter() - total_start
    print("=" * 70)
    print(f"TOTAL TIME: {total_time*1000:.1f}ms")
    print()

    return total_time

def main():
    print("\nSEMANTIC SEARCH PROFILING")
    print("=" * 70)

    # Run profile multiple times
    times = []
    for i in range(3):
        print(f"\n--- Run {i+1} ---")
        t = profile_search("test", limit=10)
        times.append(t)

    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"Average: {np.mean(times)*1000:.1f}ms")
    print(f"Min: {np.min(times)*1000:.1f}ms")
    print(f"Max: {np.max(times)*1000:.1f}ms")

if __name__ == "__main__":
    main()
