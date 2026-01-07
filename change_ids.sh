#!/usr/bin/env bash
set -euo pipefail

NEW_ID="com.lamontenunn.aftpro"

# iOS: change from your current one
OLD_IOS_ID="com.lamontenunn.aftpro"

# Android: from what your output showed
OLD_ANDROID_ID="com.lamontenunn.aftpro"

echo "== Changing identifiers to: $NEW_ID =="

# ---------- iOS ----------
PBX="ios/Runner.xcodeproj/project.pbxproj"
if [[ -f "$PBX" ]]; then
  cp "$PBX" "$PBX.bak"
  perl -pi -e "s/\Q$OLD_IOS_ID\E/$NEW_ID/g" "$PBX"
  echo "✅ iOS pbxproj updated (backup: $PBX.bak)"
else
  echo "ℹ️ iOS pbxproj not found: $PBX"
fi

# ---------- Android (Gradle) ----------
GRADLE="android/app/build.gradle"
if [[ -f "$GRADLE" ]]; then
  cp "$GRADLE" "$GRADLE.bak"

  perl -pi -e "s/applicationId\\s+\"[^\"]+\"/applicationId \"$NEW_ID\"/g" "$GRADLE"
  perl -pi -e "s/applicationId\\s*=\\s*\"[^\"]+\"/applicationId = \"$NEW_ID\"/g" "$GRADLE"
  perl -pi -e "s/namespace\\s+\"[^\"]+\"/namespace \"$NEW_ID\"/g" "$GRADLE"

  perl -pi -e "s/\Q$OLD_ANDROID_ID\E/$NEW_ID/g" "$GRADLE"

  echo "✅ Android build.gradle updated (backup: $GRADLE.bak)"
else
  echo "ℹ️ Android build.gradle not found: $GRADLE"
fi

# ---------- Android (MainActivity) ----------
MAIN_ACTIVITY="$(find android/app/src/main -name MainActivity.kt -o -name MainActivity.java 2>/dev/null | head -n 1 || true)"
if [[ -n "$MAIN_ACTIVITY" ]]; then
  cp "$MAIN_ACTIVITY" "$MAIN_ACTIVITY.bak"

  # Update package line
  perl -pi -e "s/^package\\s+[a-zA-Z0-9_\\.]+;/package $NEW_ID;/m" "$MAIN_ACTIVITY"
  perl -pi -e "s/^package\\s+[a-zA-Z0-9_\\.]+\\s*\$/package $NEW_ID/m" "$MAIN_ACTIVITY"

  EXT="${MAIN_ACTIVITY##*.}"
  if [[ "$EXT" == "java" ]]; then
    SRC_LANG_DIR="java"
  else
    SRC_LANG_DIR="kotlin"
  fi

  DEST_DIR="android/app/src/main/$SRC_LANG_DIR/$(echo "$NEW_ID" | tr '.' '/')"
  mkdir -p "$DEST_DIR"
  mv "$MAIN_ACTIVITY" "$DEST_DIR/$(basename "$MAIN_ACTIVITY")"

  echo "✅ MainActivity updated + moved to: $DEST_DIR"
  echo "   (backup: $MAIN_ACTIVITY.bak)"
else
  echo "ℹ️ MainActivity not found under android/app/src/main"
fi

echo "== Done =="
echo "Next steps:"
echo "  flutter clean"
echo "  (If using Firebase) download new GoogleService-Info.plist + google-services.json"
