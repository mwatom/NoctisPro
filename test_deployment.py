#!/usr/bin/env python3
import requests
import sys

def test_local_server():
    try:
        response = requests.get('http://localhost:8000', timeout=5)
        print(f"Local server status: {response.status_code}")
        print(f"Response headers: {dict(response.headers)}")
        print(f"Content length: {len(response.text)}")
        if response.status_code == 200:
            print("✅ Django server is working locally!")
            return True
        else:
            print("❌ Django server returned error")
            return False
    except Exception as e:
        print(f"❌ Error connecting to local server: {e}")
        return False

if __name__ == "__main__":
    test_local_server()