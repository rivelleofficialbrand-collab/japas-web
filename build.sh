#!/bin/bash
# build.sh - Untuk Netlify auto-deploy

echo "📦 Installing Flutter SDK..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

echo "📱 Enabling web..."
flutter config --enable-web

echo "🔨 Building web release..."
flutter build web --release

echo "✅ Build selesai."