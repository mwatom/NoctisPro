#!/bin/bash
echo "🛑 Stopping deployment..."
kill 6296 6334 2>/dev/null
echo "✅ Stopped"
