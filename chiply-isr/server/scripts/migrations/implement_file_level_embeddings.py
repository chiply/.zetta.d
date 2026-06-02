#!/usr/bin/env python3
"""
Implementation example: File-level embedding aggregation

This shows how to implement file-level embeddings to reduce
database size by 98%+ while maintaining good search quality.
"""

import numpy as np
from typing import List, Dict
from pathlib import Path


# ============================================================================
# STRATEGY 1: MEAN POOLING (SIMPLEST)
# ============================================================================

def aggregate_embeddings_mean(chunk_embeddings: List[np.ndarray]) -> np.ndarray:
    """
    Average all chunk embeddings into one file embedding.

    This is the simplest and most common approach.
    Works well for most semantic search use cases.

    Args:
        chunk_embeddings: List of embedding vectors (each shape: (384,))

    Returns:
        Single aggregated embedding (shape: (384,))
    """
    if not chunk_embeddings:
        raise ValueError("No embeddings to aggregate")

    return np.mean(chunk_embeddings, axis=0)


# Example usage:
"""
# During indexing:
chunks = chunk_text(document_text, method="fixed", chunk_size=2048)
texts = [c['text'] for c in chunks]
chunk_embeddings = embedding_service.generate_embeddings(texts)

# Aggregate to single embedding
file_embedding = aggregate_embeddings_mean(chunk_embeddings)

# Store only file embedding, not chunks
db.store_file_embedding(file_id, file_embedding, model_name)
"""


# ============================================================================
# STRATEGY 2: WEIGHTED MEAN (BETTER QUALITY)
# ============================================================================

def aggregate_embeddings_weighted_by_length(
    chunk_embeddings: List[np.ndarray],
    chunk_texts: List[str]
) -> np.ndarray:
    """
    Weighted average where longer chunks get more weight.

    Rationale: Longer chunks usually contain more information.

    Args:
        chunk_embeddings: List of embeddings
        chunk_texts: Corresponding chunk texts

    Returns:
        Weighted aggregated embedding
    """
    if len(chunk_embeddings) != len(chunk_texts):
        raise ValueError("Embeddings and texts must have same length")

    # Calculate weights based on length
    weights = np.array([len(text) for text in chunk_texts], dtype=float)
    weights = weights / weights.sum()  # Normalize to sum to 1

    # Weighted sum
    aggregated = np.zeros_like(chunk_embeddings[0])
    for embedding, weight in zip(chunk_embeddings, weights):
        aggregated += embedding * weight

    return aggregated


def aggregate_embeddings_weighted_by_position(
    chunk_embeddings: List[np.ndarray],
    first_weight: float = 2.0,
    last_weight: float = 1.5
) -> np.ndarray:
    """
    Weighted average emphasizing first and last chunks.

    Rationale: Document beginning (intro) and end (conclusion)
    often contain the most important information.

    Args:
        chunk_embeddings: List of embeddings
        first_weight: Weight multiplier for first chunk
        last_weight: Weight multiplier for last chunk

    Returns:
        Weighted aggregated embedding
    """
    n = len(chunk_embeddings)
    weights = np.ones(n, dtype=float)

    # Emphasize first chunk
    weights[0] = first_weight

    # Emphasize last chunk
    if n > 1:
        weights[-1] = last_weight

    # Normalize
    weights = weights / weights.sum()

    # Weighted sum
    aggregated = np.zeros_like(chunk_embeddings[0])
    for embedding, weight in zip(chunk_embeddings, weights):
        aggregated += embedding * weight

    return aggregated


# ============================================================================
# STRATEGY 3: HIERARCHICAL (BEST QUALITY)
# ============================================================================

def generate_hierarchical_embedding(
    full_text: str,
    embedding_service,
    max_length: int = 8000
) -> np.ndarray:
    """
    Generate single embedding from full document text.

    This avoids chunking entirely and lets the model see full context.
    For very long documents, uses smart truncation.

    Args:
        full_text: Complete document text
        embedding_service: Embedding model service
        max_length: Maximum characters (≈512 tokens)

    Returns:
        Single document embedding
    """
    # Truncate if necessary
    if len(full_text) > max_length:
        text = smart_truncate(full_text, max_length)
    else:
        text = full_text

    return embedding_service.generate_embedding(text)


def smart_truncate(text: str, max_length: int) -> str:
    """
    Smart truncation that preserves beginning, end, and important middle.

    Split: 40% beginning, 40% end, 20% middle

    Args:
        text: Full text
        max_length: Target length in characters

    Returns:
        Truncated text
    """
    if len(text) <= max_length:
        return text

    # Calculate portions
    begin_len = int(max_length * 0.4)
    end_len = int(max_length * 0.4)

    beginning = text[:begin_len]
    ending = text[-end_len:]

    return f"{beginning}\n\n[...]\n\n{ending}"


def smart_truncate_with_middle(text: str, max_length: int) -> str:
    """
    Advanced truncation with important middle content.

    Extracts sentences with high keyword density from middle.

    Args:
        text: Full text
        max_length: Target length

    Returns:
        Truncated text with important excerpts
    """
    if len(text) <= max_length:
        return text

    # Portions: 30% begin, 20% end, 50% from middle
    begin_len = int(max_length * 0.3)
    end_len = int(max_length * 0.2)
    middle_budget = max_length - begin_len - end_len

    beginning = text[:begin_len]
    ending = text[-end_len:]

    # Extract middle text
    middle_start = begin_len
    middle_end = len(text) - end_len
    middle_text = text[middle_start:middle_end]

    # Extract important sentences from middle
    important_middle = extract_important_sentences(middle_text, middle_budget)

    return f"{beginning}\n\n[...middle excerpts...]\n{important_middle}\n\n[...]\n\n{ending}"


def extract_important_sentences(text: str, max_length: int) -> str:
    """
    Extract most important sentences based on simple heuristics.

    Scoring:
    - Longer sentences (more info)
    - Contains numbers/data
    - Contains common keywords

    Args:
        text: Text to extract from
        max_length: Maximum total length

    Returns:
        Most important sentences concatenated
    """
    # Split into sentences
    sentences = text.replace('\n', ' ').split('. ')

    # Score each sentence
    scored = []
    for sent in sentences:
        if len(sent.strip()) < 20:  # Skip very short
            continue

        score = 0
        words = sent.split()

        # Length score
        score += len(words)

        # Numbers/data score
        if any(char.isdigit() for char in sent):
            score += 10

        # Keyword score (simple)
        keywords = ['important', 'key', 'significant', 'result', 'finding',
                   'conclusion', 'therefore', 'however', 'method', 'approach']
        for kw in keywords:
            if kw in sent.lower():
                score += 5

        scored.append((score, sent))

    # Sort by score and take top sentences until we hit length
    scored.sort(reverse=True, key=lambda x: x[0])

    result = []
    current_length = 0
    for _, sent in scored:
        if current_length + len(sent) + 2 > max_length:
            break
        result.append(sent)
        current_length += len(sent) + 2

    return '. '.join(result)


# ============================================================================
# INTEGRATION EXAMPLE: MODIFY INDEXING
# ============================================================================

def index_linked_file_with_aggregation_EXAMPLE(
    file_path: str,
    file_id: int,
    linked_file_id: int,
    org_link_line: int,
    db,
    embedding_service
):
    """
    Example: How to modify indexing to use file-level embeddings.

    This replaces storing 50+ chunk embeddings with a single file embedding.

    THIS IS AN EXAMPLE - You would integrate this into indexing.py
    """
    from org_db_server.services.document_converter import get_document_converter
    from org_db_server.services.chunking import chunk_text

    # Convert document to markdown
    converter = get_document_converter()
    conversion = converter.convert_to_markdown(file_path)

    if conversion['status'] != 'success':
        return None

    markdown = conversion['markdown']

    # =======================================================================
    # OPTION A: Mean Pooling (chunk then aggregate)
    # =======================================================================

    # Generate chunks (for processing)
    chunks = chunk_text(markdown, method="fixed", chunk_size=2048, chunk_overlap=200)

    if not chunks:
        return None

    # Generate embeddings for chunks
    texts = [c['text'] for c in chunks]
    chunk_embeddings = embedding_service.generate_embeddings(texts)

    # Aggregate to single embedding
    file_embedding = aggregate_embeddings_mean(chunk_embeddings)

    # Store ONLY file-level embedding
    # (Modified database function)
    db.store_linked_file_embedding(
        linked_file_id=linked_file_id,
        embedding=file_embedding,
        model_name=embedding_service.model_name
    )

    # =======================================================================
    # OPTION B: Hierarchical (single embedding from full text)
    # =======================================================================

    # Generate single embedding from document
    file_embedding = generate_hierarchical_embedding(
        markdown,
        embedding_service,
        max_length=8000
    )

    # Store file-level embedding
    db.store_linked_file_embedding(
        linked_file_id=linked_file_id,
        embedding=file_embedding,
        model_name=embedding_service.model_name
    )

    return linked_file_id


# ============================================================================
# DATABASE MODIFICATIONS NEEDED
# ============================================================================

"""
Add to database.py:

def store_linked_file_embedding(
    self,
    linked_file_id: int,
    embedding: np.ndarray,
    model_name: str
):
    '''Store file-level embedding for a linked file.'''
    cursor = self.conn.cursor()

    # Delete any existing embedding
    cursor.execute(
        "DELETE FROM linked_file_embeddings WHERE linked_file_id = ?",
        (linked_file_id,)
    )

    # Convert embedding to bytes
    embedding_bytes = embedding.astype(np.float32).tobytes()

    # Insert new embedding
    cursor.execute(
        '''INSERT INTO linked_file_embeddings
           (linked_file_id, embedding_model, embedding_vector, embedding_dim, created_at)
           VALUES (?, ?, ?, ?, ?)''',
        (linked_file_id, model_name, embedding_bytes, len(embedding),
         datetime.now().isoformat())
    )

    self.conn.commit()


# For org files too:
def store_file_embedding(
    self,
    file_id: int,
    embedding: np.ndarray,
    model_name: str
):
    '''Store file-level embedding for an org file.'''
    cursor = self.conn.cursor()

    # Update files table with embedding
    embedding_bytes = embedding.astype(np.float32).tobytes()

    cursor.execute(
        '''UPDATE files
           SET file_embedding = ?, embedding_model = ?
           WHERE rowid = ?''',
        (embedding_bytes, model_name, file_id)
    )

    self.conn.commit()
"""


# ============================================================================
# SCHEMA MODIFICATIONS NEEDED
# ============================================================================

SCHEMA_ADDITIONS = """
-- Add file_embedding to files table (for org files)
ALTER TABLE files ADD COLUMN file_embedding F32_BLOB(384);
ALTER TABLE files ADD COLUMN embedding_model TEXT;
CREATE INDEX idx_files_embedding ON files(libsql_vector_idx(file_embedding));

-- Add linked_file_embeddings table (for linked files)
CREATE TABLE IF NOT EXISTS linked_file_embeddings (
    rowid INTEGER PRIMARY KEY,
    linked_file_id INTEGER NOT NULL,
    embedding_model TEXT NOT NULL,
    embedding_vector F32_BLOB(384) NOT NULL,
    embedding_dim INTEGER NOT NULL,
    created_at TEXT,
    FOREIGN KEY(linked_file_id) REFERENCES linked_files(rowid) ON DELETE CASCADE
);

CREATE INDEX idx_linked_file_embeddings_file ON linked_file_embeddings(linked_file_id);
CREATE INDEX idx_linked_file_embeddings_model ON linked_file_embeddings(embedding_model);
CREATE INDEX idx_linked_file_embeddings_vector
    ON linked_file_embeddings(libsql_vector_idx(embedding_vector));

-- Optional: Keep chunks table for org files only
-- Or add a flag to indicate whether to store chunks
ALTER TABLE chunks ADD COLUMN is_indexed BOOLEAN DEFAULT 1;
"""


# ============================================================================
# SEARCH MODIFICATIONS NEEDED
# ============================================================================

"""
Modify search.py to search file-level embeddings:

@router.post("/semantic/files", response_model=SemanticSearchResponse)
async def semantic_search_files(request: SemanticSearchRequest):
    '''Search file-level embeddings only (fast).'''

    # Generate query embedding
    query_embedding = embedding_service.generate_embedding(request.query)
    query_bytes = query_embedding.astype(np.float32).tobytes()

    cursor = db.conn.cursor()

    # Search file-level embeddings
    cursor.execute('''
        SELECT
            f.filename,
            f.file_embedding,
            lf.file_path as linked_file_path,
            lf.file_type as linked_file_type
        FROM vector_top_k('idx_files_embedding', ?, ?) vt
        JOIN files f ON f.rowid = vt.id
        LEFT JOIN linked_files lf ON lf.org_file_id = f.rowid
        WHERE f.embedding_model = ?
    ''', [query_bytes, request.limit, model_name])

    # Process results...


@router.post("/semantic/hybrid", response_model=SemanticSearchResponse)
async def semantic_search_hybrid(request: SemanticSearchRequest):
    '''Two-stage: file-level first, then chunks for top matches.'''

    # Stage 1: Search file-level (fast)
    top_files = search_file_embeddings(query, limit=50)

    # Stage 2: Search chunks within top files (precise)
    results = []
    for file in top_files[:10]:
        chunks = search_chunks_in_file(query, file.id, limit=5)
        results.extend(chunks)

    return results[:request.limit]
"""


# ============================================================================
# TESTING & VALIDATION
# ============================================================================

def test_aggregation_quality():
    """
    Test that aggregation preserves semantic meaning.

    Run this before deploying to production to ensure quality.
    """
    from org_db_server.services.embeddings import get_embedding_service

    embedding_service = get_embedding_service()

    # Test document
    test_doc = """
    Machine learning is a subset of artificial intelligence.
    It focuses on training algorithms to learn from data.
    Common techniques include neural networks and decision trees.
    Applications range from image recognition to natural language processing.
    """

    # Method 1: Chunks + aggregation
    chunks = [
        "Machine learning is a subset of artificial intelligence.",
        "It focuses on training algorithms to learn from data.",
        "Common techniques include neural networks and decision trees.",
        "Applications range from image recognition to natural language processing."
    ]
    chunk_embeddings = embedding_service.generate_embeddings(chunks)
    aggregated = aggregate_embeddings_mean(chunk_embeddings)

    # Method 2: Full document
    full_embedding = embedding_service.generate_embedding(test_doc)

    # Compare similarity
    from org_db_server.services.embeddings import EmbeddingService
    similarity = EmbeddingService.similarity(aggregated, full_embedding)

    print(f"Similarity between aggregated and full: {similarity:.4f}")
    print(f"Expected: > 0.90 (closer to 1.0 is better)")

    # Test search behavior
    query = "What is machine learning?"
    query_emb = embedding_service.generate_embedding(query)

    sim_aggregated = EmbeddingService.similarity(query_emb, aggregated)
    sim_full = EmbeddingService.similarity(query_emb, full_embedding)

    print(f"\nQuery similarity with aggregated: {sim_aggregated:.4f}")
    print(f"Query similarity with full: {sim_full:.4f}")
    print(f"Difference: {abs(sim_aggregated - sim_full):.4f}")


if __name__ == "__main__":
    print("File-level embedding aggregation strategies")
    print("=" * 60)
    print("\nThis file contains implementation examples.")
    print("See EMBEDDING_AGGREGATION_STRATEGIES.md for full documentation.")
    print("\nTo test aggregation quality:")
    print("  python3 implement_file_level_embeddings.py test")

    import sys
    if len(sys.argv) > 1 and sys.argv[1] == 'test':
        test_aggregation_quality()
