#!/bin/bash
# Full check mode - release build for accurate UI preview
# Cleans build cache after running
# Usage: ./full_check.sh
echo "🎨 Starting full check mode (release build)..."
flutter run -d edge --release --web-port 3003
EXIT_CODE=$?
echo "🧹 Cleaning build cache..."
rm -rf build/web
echo "✅ Done."
exit $EXIT_CODE
