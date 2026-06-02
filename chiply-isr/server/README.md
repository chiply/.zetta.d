# org-db v3 - Python Server

FastAPI-based server for org-db v3 with semantic search, image search, and full-text search capabilities.

## Features

- **Multi-Database Architecture**: Separate databases for metadata, semantic embeddings, and image embeddings
- **Vector Search**: Fast similarity search using libsql vector indexes
- **Full-Text Search**: FTS5-based keyword search
- **Image Search**: CLIP-based image similarity search
- **Property Search**: Search org-mode properties (CATEGORY, TODO, PRIORITY, etc.)
- **Linked Files**: Index and search external files (PDF, DOCX, PPTX, etc.)
- **Web Interface**: Homepage with database statistics and system info

## Quick Start

```bash
# Install dependencies
uv sync

# Run server
uv run uvicorn org_db_server.main:app --host 127.0.0.1 --port 8765

# Access web interface
open http://127.0.0.1:8765
```

## Documentation

See the [../docs/](../docs/) directory for detailed documentation:

- **[Documentation Index](../docs/README.md)** - Complete documentation index
- **[Multi-Database Architecture](../docs/architecture/multi-database.md)** - Architecture overview
- **[ANN Search Optimization](../docs/performance/ann-search-optimization.md)** - Vector search optimization
- **[Property Search](../docs/features/property-search.md)** - Property search feature
- **[Linked Files Optimization](../docs/performance/linked-files-optimization.md)** - External file indexing
- **[Supported Formats](../docs/architecture/supported-formats.md)** - List of supported file formats

## API Endpoints

- `GET /` - Web interface homepage
- `GET /health` - Health check
- `GET /api/stats/` - Database statistics
- `POST /api/search/semantic` - Semantic search (vector embeddings)
- `POST /api/search/images` - Image search (CLIP embeddings)
- `POST /api/search/fulltext` - Full-text search (FTS5)
- `POST /api/search/headlines` - Headline search
- `POST /api/search/properties` - Property search
- `POST /api/index/file` - Index a single file
- `POST /api/index/directory` - Index a directory
- `GET /api/files` - List all indexed files
- `GET /api/agenda` - Get agenda items

## Configuration

Environment variables (all optional):

```bash
# Database paths (default: ~/org-db/)
export ORG_DB_DB_PATH=~/org-db/org-db-v3.db
export ORG_DB_SEMANTIC_DB_PATH=~/org-db/org-db-v3-semantic.db
export ORG_DB_IMAGE_DB_PATH=~/org-db/org-db-v3-images.db

# Server settings
export ORG_DB_HOST=127.0.0.1
export ORG_DB_PORT=8765

# Model settings
export ORG_DB_EMBEDDING_MODEL=all-MiniLM-L6-v2
export ORG_DB_CLIP_MODEL=clip-ViT-B-32
```

## Performance

Current search performance (with optimizations):

- **Exact search** (< 5000 items): 0.02-0.35s
- **ANN search** (≥ 5000 items): 0.5-1.5s
- **Full-text search**: < 0.1s
- **Property search**: < 0.1s

## Architecture

org-db v3 uses a **three-database architecture** for optimal performance:

1. **Main DB** (~960 MB) - Files, headlines, links, properties, tags, FTS5 index
2. **Semantic DB** (~7 MB) - Text embeddings and chunks
3. **Image DB** (~1 MB) - Image embeddings and metadata

This separation:
- Reduces database bloat
- Improves query performance
- Enables independent optimization
- Simplifies backup and maintenance

## Testing

```bash
# Run all tests
uv run pytest

# Run specific test
uv run pytest tests/test_search.py -v

# Test ANN search fix
uv run python test_ann_fix.py
```

## Development

```bash
# Format code
uv run black org_db_server/

# Type checking
uv run mypy org_db_server/

# Lint
uv run ruff check org_db_server/
```

## License

MIT License - See [../LICENSE](../LICENSE) for details.
