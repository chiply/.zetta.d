# Utility Scripts

This directory contains utility scripts for development, benchmarking, profiling, and database migrations.

## Benchmarks

Scripts for measuring search performance:

- **`benchmarks/benchmark_search.py`** - Benchmark various search types (semantic, fulltext, image, headline)
- **`benchmarks/benchmark_semantic_search.py`** - Detailed semantic search benchmarking

Usage:
```bash
cd python
uv run python scripts/benchmarks/benchmark_search.py
```

## Profiling

Scripts for performance analysis and debugging:

- **`profiling/debug_search_performance.py`** - Debug search performance issues
- **`profiling/profile_search.py`** - Profile search operations

Usage:
```bash
cd python
uv run python scripts/profiling/debug_search_performance.py
```

## Migrations

One-time migration scripts for database schema changes:

- **`migrations/migrate_to_f32_blob.py`** - Migrate embeddings to F32_BLOB format for vector search
- **`migrations/optimize_database.py`** - Optimize database indexes and vacuum
- **`migrations/implement_file_level_embeddings.py`** - Implement file-level embedding aggregation

⚠️ **Note:** Migration scripts are designed to be run once. Review the script before running to understand what it does.

Usage:
```bash
cd python
uv run python scripts/migrations/migrate_to_f32_blob.py
```

## Development

These scripts are not part of the main package but are useful for:
- Performance testing
- Debugging issues
- Database maintenance
- Schema migrations
- Understanding system behavior
