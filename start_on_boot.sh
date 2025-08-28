#!/bin/bash
# Simple startup script for container environments
cd /workspace
sleep 10  # Wait for system to be ready
./manage_autostart.sh start
