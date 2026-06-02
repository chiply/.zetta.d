#!/usr/bin/env python3
"""Benchmark semantic search performance."""

import requests
import time
import json

BASE_URL = "http://127.0.0.1:8765"

def benchmark_query(query: str, limit: int = 20, runs: int = 5):
    """Run a query multiple times and report timing."""
    times = []

    print(f"\n{'='*60}")
    print(f"Query: '{query}' (limit={limit}, runs={runs})")
    print(f"{'='*60}")

    for i in range(runs):
        start = time.perf_counter()
        response = requests.post(
            f"{BASE_URL}/api/search/semantic",
            json={
                "query": query,
                "limit": limit,
                "rerank": False,
                "rerank_candidates": 50
            }
        )
        elapsed = (time.perf_counter() - start) * 1000
        times.append(elapsed)

        if response.status_code == 200:
            data = response.json()
            num_results = len(data.get("results", []))
            print(f"  Run {i+1}: {elapsed:6.1f}ms - {num_results} results")
        else:
            print(f"  Run {i+1}: ERROR - {response.status_code}")
            print(f"    {response.text}")
            return None

    # Calculate statistics
    avg = sum(times) / len(times)
    min_time = min(times)
    max_time = max(times)

    print(f"\n  Statistics:")
    print(f"    Average: {avg:6.1f}ms")
    print(f"    Min:     {min_time:6.1f}ms")
    print(f"    Max:     {max_time:6.1f}ms")

    return {
        "query": query,
        "times": times,
        "avg": avg,
        "min": min_time,
        "max": max_time
    }

def main():
    print("Semantic Search Performance Benchmarks")
    print("=" * 60)

    # Check server health
    try:
        response = requests.get(f"{BASE_URL}/health")
        if response.status_code != 200:
            print(f"ERROR: Server health check failed: {response.status_code}")
            return
        print(f"✓ Server is healthy")
    except Exception as e:
        print(f"ERROR: Cannot connect to server: {e}")
        return

    # Check database stats
    try:
        response = requests.get(f"{BASE_URL}/api/stats/")
        if response.status_code == 200:
            stats = response.json()
            print(f"✓ Database: {stats.get('total_embeddings', 'N/A')} embeddings")
        else:
            print(f"WARNING: Could not get stats: {response.status_code}")
    except Exception as e:
        print(f"WARNING: Stats check failed: {e}")

    # Run benchmarks
    queries = [
        "mushroom",
        "water splitting",
        "neural networks",
        "a",  # Very short query
        "What are the latest developments in machine learning for scientific computing?",  # Long query
    ]

    results = []
    for query in queries:
        result = benchmark_query(query, limit=20, runs=5)
        if result:
            results.append(result)
        time.sleep(0.1)  # Small delay between queries

    # Overall summary
    if results:
        print(f"\n{'='*60}")
        print("OVERALL SUMMARY")
        print(f"{'='*60}")
        all_times = [t for r in results for t in r["times"]]
        print(f"Total queries run: {len(all_times)}")
        print(f"Average time: {sum(all_times)/len(all_times):.1f}ms")
        print(f"Best time: {min(all_times):.1f}ms")
        print(f"Worst time: {max(all_times):.1f}ms")
        print(f"\nAll times are end-to-end (includes network + embedding + search)")

if __name__ == "__main__":
    main()
