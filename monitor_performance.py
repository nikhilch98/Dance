#!/usr/bin/env python3
"""
Performance monitoring script for Nachna API
Tracks response times and identifies bottlenecks
"""

import time
import requests
import statistics
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
import json

# Configuration
BASE_URL = "https://nachna.com"  # Change to https after SSL setup
ENDPOINTS = [
    "/api/workshops?version=v2",
    "/api/artists?version=v2",
    "/api/studios?version=v2",
]

def measure_request(url, session=None):
    """Measure detailed timing for a single request"""
    if session is None:
        session = requests.Session()
    
    start_time = time.time()
    
    try:
        response = session.get(url, timeout=30)
        end_time = time.time()
        
        return {
            "url": url,
            "status_code": response.status_code,
            "total_time": end_time - start_time,
            "response_size": len(response.content),
            "headers": dict(response.headers),
            "success": response.status_code == 200
        }
    except Exception as e:
        end_time = time.time()
        return {
            "url": url,
            "error": str(e),
            "total_time": end_time - start_time,
            "success": False
        }

def run_performance_test():
    """Run comprehensive performance tests"""
    print(f"=== Nachna API Performance Test ===")
    print(f"Time: {datetime.now()}")
    print(f"Base URL: {BASE_URL}\n")
    
    # Test 1: Individual endpoint response times
    print("1. Individual Endpoint Tests:")
    print("-" * 50)
    
    with requests.Session() as session:
        for endpoint in ENDPOINTS:
            url = BASE_URL + endpoint
            results = []
            
            # Make 5 requests to get average
            for i in range(5):
                result = measure_request(url, session)
                results.append(result["total_time"])
                time.sleep(0.1)  # Small delay between requests
            
            avg_time = statistics.mean(results)
            min_time = min(results)
            max_time = max(results)
            
            print(f"{endpoint}")
            print(f"  Average: {avg_time*1000:.1f}ms")
            print(f"  Min: {min_time*1000:.1f}ms, Max: {max_time*1000:.1f}ms")
            print()
    
    # Test 2: Concurrent requests
    print("\n2. Concurrent Request Test (10 simultaneous):")
    print("-" * 50)
    
    with ThreadPoolExecutor(max_workers=10) as executor:
        url = BASE_URL + ENDPOINTS[0]
        futures = [executor.submit(measure_request, url) for _ in range(10)]
        
        times = []
        for future in as_completed(futures):
            result = future.result()
            if result["success"]:
                times.append(result["total_time"])
        
        if times:
            print(f"Average response time under load: {statistics.mean(times)*1000:.1f}ms")
            print(f"Max response time under load: {max(times)*1000:.1f}ms")
    
    # Test 3: Keep-alive connection test
    print("\n3. Keep-Alive Connection Test:")
    print("-" * 50)
    
    # Without keep-alive
    no_keepalive_times = []
    for _ in range(5):
        result = measure_request(BASE_URL + ENDPOINTS[0])
        if result["success"]:
            no_keepalive_times.append(result["total_time"])
        time.sleep(0.1)
    
    # With keep-alive
    keepalive_times = []
    with requests.Session() as session:
        for _ in range(5):
            result = measure_request(BASE_URL + ENDPOINTS[0], session)
            if result["success"]:
                keepalive_times.append(result["total_time"])
            time.sleep(0.1)
    
    if no_keepalive_times and keepalive_times:
        print(f"Without keep-alive: {statistics.mean(no_keepalive_times)*1000:.1f}ms avg")
        print(f"With keep-alive: {statistics.mean(keepalive_times)*1000:.1f}ms avg")
        improvement = (1 - statistics.mean(keepalive_times)/statistics.mean(no_keepalive_times)) * 100
        print(f"Improvement: {improvement:.1f}%")
    
    # Test 4: Response size and compression
    print("\n4. Response Size Analysis:")
    print("-" * 50)
    
    with requests.Session() as session:
        for endpoint in ENDPOINTS:
            url = BASE_URL + endpoint
            result = measure_request(url, session)
            
            if result["success"]:
                size_kb = result["response_size"] / 1024
                encoding = result["headers"].get("content-encoding", "none")
                print(f"{endpoint}")
                print(f"  Size: {size_kb:.1f} KB")
                print(f"  Encoding: {encoding}")
                print()

if __name__ == "__main__":
    run_performance_test() 