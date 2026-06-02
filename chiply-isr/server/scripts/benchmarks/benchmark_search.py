#!/usr/bin/env python3
"""Benchmark semantic search performance."""

import time
import requests
import json
import sys
from statistics import mean, median, stdev

def benchmark_search(query: str, limit: int = 10, iterations: int = 5):
    """Benchmark a semantic search query."""
    url = "http://127.0.0.1:8765/api/search/semantic"
    headers = {"Content-Type": "application/json"}
    data = {
        "query": query,
        "limit": limit,
        "rerank": False
    }

    times = []
    print(f"\nBenchmarking query: '{query}' (limit={limit}, iterations={iterations})")
    print("-" * 70)

    for i in range(iterations):
        start = time.perf_counter()
        try:
            response = requests.post(url, headers=headers, json=data, timeout=30)
            elapsed = time.perf_counter() - start

            if response.status_code == 200:
                result = response.json()
                num_results = len(result.get('results', []))
                times.append(elapsed)
                print(f"  Iteration {i+1}: {elapsed*1000:.1f}ms ({num_results} results)")
            else:
                print(f"  Iteration {i+1}: ERROR - Status {response.status_code}")
        except Exception as e:
            elapsed = time.perf_counter() - start
            print(f"  Iteration {i+1}: ERROR - {e} (after {elapsed*1000:.1f}ms)")

    if times:
        print("-" * 70)
        print(f"  Mean:   {mean(times)*1000:.1f}ms")
        print(f"  Median: {median(times)*1000:.1f}ms")
        if len(times) > 1:
            print(f"  StdDev: {stdev(times)*1000:.1f}ms")
        print(f"  Min:    {min(times)*1000:.1f}ms")
        print(f"  Max:    {max(times)*1000:.1f}ms")

    return times

def main():
    # Check server is running
    try:
        response = requests.get("http://127.0.0.1:8765/health", timeout=5)
        if response.status_code != 200:
            print("ERROR: Server is not responding correctly")
            sys.exit(1)
    except Exception as e:
        print(f"ERROR: Cannot connect to server: {e}")
        sys.exit(1)

    # Get database stats
    try:
        stats = requests.get("http://127.0.0.1:8765/api/stats/", timeout=5).json()
        print("\nDatabase Statistics:")
        print(f"  Files: {stats['files_count']}")
        print(f"  Chunks: {stats['chunks_count']}")
        print(f"  Embeddings: {stats['embeddings_count']}")
        print(f"  Database size: {stats['db_size_mb']:.1f} MB")
    except Exception as e:
        print(f"Warning: Could not get stats: {e}")

    # Benchmark different query types
    print("\n" + "=" * 70)
    print("SEMANTIC SEARCH BENCHMARKS")
    print("=" * 70)

    # Short simple query
    benchmark_search("cat", limit=10, iterations=5)

    # Medium query
    benchmark_search("machine learning", limit=10, iterations=5)

    # Longer query
    benchmark_search("What are the best practices for writing Python code", limit=10, iterations=5)

    # Different limits
    print("\n" + "=" * 70)
    print("TESTING DIFFERENT RESULT LIMITS")
    print("=" * 70)

    for limit in [5, 10, 20, 50]:
        benchmark_search("test", limit=limit, iterations=3)

    print("\n" + "=" * 70)
    print("BENCHMARK COMPLETE")
    print("=" * 70)

if __name__ == "__main__":
    main()
