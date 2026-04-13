#!/bin/bash
SRC="/home/cerelac/expenso"
DEST="/home/cerelac/expensoAI"

# SLEEP_SECONDS: 2 hours = 7200 seconds / 11 commits = ~654 seconds. We'll use 600 (10 mins) as it's slightly faster and guarantees finishing within 2h.
SLEEP_SECONDS=600

mkdir -p "$DEST"
cd "$DEST"

# Make sure git is initialized
if [ ! -d ".git" ]; then
  git init
  git remote add origin https://github.com/murugnn/expensoAI.git
  git branch -M main
fi

copy_and_commit() {
    local msg=$1
    local files=("${@:2}")
    
    echo "Starting commit: $msg"
    
    for f in "${files[@]}"; do
        if [ -d "$SRC/$f" ]; then
            mkdir -p $(dirname "$f")
            cp -r "$SRC/$f" "$f"
        elif [ -f "$SRC/$f" ]; then
            mkdir -p $(dirname "$f")
            cp "$SRC/$f" "$f"
        fi
    done
    
    git add .
    git commit -m "$msg"
    git push -u origin main
    
    echo "Pushed commit: $msg. Sleeping for $SLEEP_SECONDS seconds..."
    sleep $SLEEP_SECONDS
}

# 1
copy_and_commit "Initial project setup" README.md pubspec.yaml pubspec.lock .gitignore .env android ios linux macos web windows
# 2
copy_and_commit "Add core architecture and thematic styling" lib/core lib/theme.dart
# 3
copy_and_commit "Add data models and assets" lib/models assets
# 4
copy_and_commit "Implement authentication and onboarding flows" lib/features/auth lib/features/onboarding lib/features/tutorial
# 5
copy_and_commit "Add state management providers" lib/providers
# 6
copy_and_commit "Build dashboard and main screen" lib/features/dashboard lib/features/main_screen.dart
# 7
copy_and_commit "Add expense tracking and receipt scan logic" lib/features/add_expense lib/features/scan
# 8
copy_and_commit "Integrate AI Insights and ML text classifiers" lib/features/ai_insights lib/ml
# 9
copy_and_commit "Add gamification features, streak tracking and shop" lib/features/streak lib/features/demon_fight lib/features/shop
# 10
copy_and_commit "Create goals tracking and user profile" lib/features/goals lib/features/profile

# 11
echo "Starting final push..."
rsync -a --exclude='.git' "$SRC/" "$DEST/"
git add .
git commit -m "Add settings, updater and finalize application integration"
git push -u origin main

echo "All done! Successfully migrated and pushed!"
