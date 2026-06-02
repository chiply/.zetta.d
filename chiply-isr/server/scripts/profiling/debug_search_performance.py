#!/usr/bin/env python3
"""
Comprehensive search performance debugging tool.

This tool helps diagnose why database searches are slow or failing.
Run this before and after optimizations to measure improvements.
"""

import time
import libsql
import requests
import sys
import psutil
import os
from pathlib import Path
from statistics import mean, median

# Database path
DB_PATH = Path.home() / "Dropbox/emacs/cache/org-db-v3/org-db-v3.db"
SERVER_URL = "http://127.0.0.1:8765"

def format_bytes(bytes):
    """Format bytes as human-readable string."""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes < 1024.0:
            return f"{bytes:.1f} {unit}"
        bytes /= 1024.0
    return f"{bytes:.1f} TB"

def print_section(title):
    """Print formatted section header."""
    print(f"\n{'='*70}")
    print(f"{title:^70}")
    print('='*70)

def check_database_health():
    """Check database file health and statistics."""
    print_section("DATABASE HEALTH CHECK")

    if not DB_PATH.exists():
        print(f"❌ ERROR: Database not found at {DB_PATH}")
        return False

    # File stats
    stat = os.stat(DB_PATH)
    print(f"Database path: {DB_PATH}")
    print(f"Database size: {format_bytes(stat.st_size)}")
    print(f"Last modified: {time.ctime(stat.st_mtime)}")

    # Connect and check integrity
    try:
        conn = libsql.connect(str(DB_PATH))
        cursor = conn.cursor()

        # Quick integrity check
        print("\nRunning integrity check...")
        start = time.time()
        cursor.execute("PRAGMA integrity_check")
        result = cursor.fetchone()[0]
        elapsed = time.time() - start

        if result == "ok":
            print(f"✅ Integrity check PASSED ({elapsed:.2f}s)")
        else:
            print(f"❌ Integrity check FAILED: {result}")
            return False

        # Check table sizes
        print("\nTable statistics:")
        tables = ['files', 'chunks', 'embeddings', 'images', 'image_embeddings',
                  'headlines', 'fts_content', 'linked_files']

        for table in tables:
            try:
                cursor.execute(f"SELECT COUNT(*) FROM {table}")
                count = cursor.fetchone()[0]
                print(f"  {table:20} {count:>10,} rows")
            except Exception as e:
                print(f"  {table:20} ERROR: {e}")

        # Check index health
        print("\nIndex statistics:")
        cursor.execute("""
            SELECT name, tbl_name
            FROM sqlite_master
            WHERE type='index' AND sql IS NOT NULL
            ORDER BY tbl_name, name
        """)

        index_count = 0
        current_table = None
        for row in cursor.fetchall():
            index_name, table_name = row
            if table_name != current_table:
                print(f"\n  {table_name}:")
                current_table = table_name
            print(f"    - {index_name}")
            index_count += 1

        print(f"\nTotal indexes: {index_count}")

        # Check if ANALYZE has been run
        print("\nQuery optimizer statistics:")
        cursor.execute("SELECT COUNT(*) FROM sqlite_stat1")
        stat_count = cursor.fetchone()
        if stat_count and stat_count[0] > 0:
            print(f"✅ sqlite_stat1 has {stat_count[0]} entries (ANALYZE has been run)")
        else:
            print("⚠️  WARNING: No optimizer statistics found!")
            print("   Run: curl -X POST http://127.0.0.1:8765/api/optimize")

        conn.close()
        return True

    except Exception as e:
        print(f"❌ ERROR checking database: {e}")
        return False

def check_server_status():
    """Check if server is running and responsive."""
    print_section("SERVER STATUS CHECK")

    try:
        response = requests.get(f"{SERVER_URL}/health", timeout=5)
        if response.status_code == 200:
            print("✅ Server is running and responding")
            data = response.json()
            print(f"   Version: {data.get('version', 'unknown')}")
            return True
        else:
            print(f"❌ Server returned status code: {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print("❌ Server is NOT running (connection refused)")
        print("   Start server from Emacs: M-x org-db-v3-start-server")
        return False
    except requests.exceptions.Timeout:
        print("⚠️  Server is not responding (timeout)")
        return False
    except Exception as e:
        print(f"❌ Error checking server: {e}")
        return False

def test_simple_query():
    """Test a simple semantic search query."""
    print_section("SIMPLE QUERY TEST")

    query = "test"
    print(f"Testing semantic search for: '{query}'")
    print("Request timeout: 10 seconds")

    try:
        start = time.time()
        response = requests.post(
            f"{SERVER_URL}/api/search/semantic",
            headers={"Content-Type": "application/json"},
            json={"query": query, "limit": 5, "rerank": False},
            timeout=10
        )
        elapsed = time.time() - start

        if response.status_code == 200:
            data = response.json()
            results = data.get('results', [])
            print(f"✅ Query completed in {elapsed*1000:.1f}ms")
            print(f"   Returned {len(results)} results")

            if elapsed > 2.0:
                print(f"⚠️  WARNING: Query took {elapsed:.1f}s (should be <1s)")
                return "SLOW"
            return "OK"
        else:
            print(f"❌ Query failed with status {response.status_code}")
            print(f"   Response: {response.text[:200]}")
            return "ERROR"

    except requests.exceptions.Timeout:
        print(f"❌ Query TIMED OUT after 10 seconds")
        print("   This is a CRITICAL performance issue!")
        return "TIMEOUT"
    except Exception as e:
        print(f"❌ Query error: {e}")
        return "ERROR"

def analyze_query_performance():
    """Analyze query performance with different parameters."""
    print_section("QUERY PERFORMANCE ANALYSIS")

    test_queries = [
        ("Short query", "cat", 5),
        ("Medium query", "machine learning", 10),
        ("Long query", "what are best practices", 10),
    ]

    results = []

    for label, query, limit in test_queries:
        print(f"\n{label}: '{query}' (limit={limit})")

        times = []
        for i in range(3):
            try:
                start = time.time()
                response = requests.post(
                    f"{SERVER_URL}/api/search/semantic",
                    headers={"Content-Type": "application/json"},
                    json={"query": query, "limit": limit, "rerank": False},
                    timeout=15
                )
                elapsed = time.time() - start

                if response.status_code == 200:
                    times.append(elapsed)
                    print(f"  Attempt {i+1}: {elapsed*1000:.1f}ms")
                else:
                    print(f"  Attempt {i+1}: ERROR (status {response.status_code})")

            except requests.exceptions.Timeout:
                print(f"  Attempt {i+1}: TIMEOUT (>15s)")
            except Exception as e:
                print(f"  Attempt {i+1}: ERROR ({e})")

        if times:
            avg = mean(times)
            results.append((label, avg))
            print(f"  Average: {avg*1000:.1f}ms")
            if avg > 1.0:
                print(f"  ⚠️  SLOW (should be <1000ms)")
        else:
            print(f"  ❌ All attempts failed!")

    return results

def check_system_resources():
    """Check system resource usage."""
    print_section("SYSTEM RESOURCE CHECK")

    # Overall system
    cpu_percent = psutil.cpu_percent(interval=1)
    mem = psutil.virtual_memory()
    disk = psutil.disk_usage('/')

    print("System resources:")
    print(f"  CPU usage: {cpu_percent:.1f}%")
    print(f"  Memory: {format_bytes(mem.used)}/{format_bytes(mem.total)} " +
          f"({mem.percent:.1f}% used)")
    print(f"  Disk: {format_bytes(disk.used)}/{format_bytes(disk.total)} " +
          f"({disk.percent:.1f}% used)")

    # Find server process
    print("\nSearching for org-db server process...")
    found = False
    for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
        try:
            cmdline = ' '.join(proc.info['cmdline'] or [])
            if 'uvicorn' in cmdline and 'org_db_server' in cmdline:
                found = True
                print(f"\n  Found server process (PID {proc.info['pid']}):")
                proc_info = proc.as_dict(attrs=['memory_info', 'cpu_percent', 'num_threads'])
                print(f"    Memory: {format_bytes(proc_info['memory_info'].rss)}")
                print(f"    CPU: {proc_info['cpu_percent']:.1f}%")
                print(f"    Threads: {proc_info['num_threads']}")
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass

    if not found:
        print("  ⚠️  Server process not found")

def main():
    """Run all diagnostic checks."""
    print("\n" + "="*70)
    print("ORG-DB V3 SEARCH PERFORMANCE DIAGNOSTIC TOOL".center(70))
    print("="*70)

    # Run checks
    db_ok = check_database_health()
    server_ok = check_server_status()
    check_system_resources()

    if not server_ok:
        print("\n" + "="*70)
        print("❌ Cannot run query tests - server is not running")
        print("="*70)
        sys.exit(1)

    if not db_ok:
        print("\n" + "="*70)
        print("⚠️  Database issues detected - queries may fail")
        print("="*70)

    # Run query tests
    query_status = test_simple_query()

    if query_status == "OK":
        analyze_query_performance()

    # Summary
    print_section("DIAGNOSTIC SUMMARY")

    print("\nStatus:")
    print(f"  Database health: {'✅ OK' if db_ok else '❌ ISSUES'}")
    print(f"  Server status: {'✅ RUNNING' if server_ok else '❌ DOWN'}")
    print(f"  Query performance: {query_status}")

    print("\nRecommendations:")

    if query_status == "TIMEOUT" or query_status == "SLOW":
        print("  🔴 CRITICAL: Queries are too slow!")
        print("     1. Run database optimization:")
        print("        curl -X POST http://127.0.0.1:8765/api/optimize")
        print("     2. Consider reducing database size")
        print("     3. Check disk I/O performance")
        print("     4. Review recent code changes that removed caching")

    if not db_ok:
        print("  🟡 Database issues detected")
        print("     1. Check database file integrity")
        print("     2. Consider rebuilding database")

    print("\n" + "="*70)

if __name__ == "__main__":
    main()
