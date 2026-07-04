#!/usr/bin/env bash
# Version update script for macOS/Linux - mirrors update_version.ps1
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${1:-$SCRIPT_DIR/version.json}"

if [[ ! -f "$VERSION_FILE" ]]; then
    echo "Error: Version file '$VERSION_FILE' not found!" >&2
    exit 1
fi

# Read version from JSON (requires python3 or jq)
if command -v python3 &>/dev/null; then
    NEW_VERSION=$(python3 - "$VERSION_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding='utf-8') as fh:
    print(json.load(fh)['version'])
PY
)
elif command -v jq &>/dev/null; then
    NEW_VERSION=$(jq -r '.version' "$VERSION_FILE")
else
    echo "Error: python3 or jq is required to parse version.json" >&2
    exit 1
fi

# Calculate version code: (major * 1000000) + (minor * 10000) + (patch * 10)
IFS='.' read -r V_MAJOR V_MINOR V_PATCH <<< "$NEW_VERSION"
if [[ -z "${V_MAJOR:-}" || -z "${V_MINOR:-}" || -z "${V_PATCH:-}" ]]; then
    echo "Error: version '$NEW_VERSION' must have format major.minor.patch" >&2
    exit 1
fi
VERSION_CODE=$(( (V_MAJOR * 1000000) + (V_MINOR * 10000) + (V_PATCH * 10) ))

echo "Updating version to: $NEW_VERSION (code: $VERSION_CODE)"

# Support both GNU sed (Linux) and BSD sed (macOS)
sedi() {
    if sed --version >/dev/null 2>&1; then
        sed -i "$@"
    else
        sed -i '' "$@"
    fi
}

# ---- .gitignore ----
GITIGNORE_TMP=$(mktemp)
awk \
    -v start_marker="# Generated Windows installers" \
    -v end_marker="# End generated Windows installers" \
    -v new_version="$NEW_VERSION" '
BEGIN {
    managed_count = 2
    managed[1] = "installer/otzaria-" new_version "-windows.exe"
    managed[2] = "installer/otzaria-" new_version "-windows-full.exe"
    inside_block = 0
    inserted_block = 0
}
$0 == start_marker {
    inside_block = 1
    next
}
$0 == end_marker {
    inside_block = 0
    next
}
inside_block {
    next
}
$0 ~ /^installer\/otzaria-[0-9.]+-windows(-full)?(-silent)?\.exe$/ {
    next
}
{
    print
    if (!inserted_block && $0 == "external/") {
        print start_marker
        for (i = 1; i <= managed_count; i++) {
            print managed[i]
        }
        print end_marker
        inserted_block = 1
    }
}
END {
    if (!inserted_block) {
        if (NR > 0) {
            print ""
        }
        print start_marker
        for (i = 1; i <= managed_count; i++) {
            print managed[i]
        }
        print end_marker
    }
}
' .gitignore > "$GITIGNORE_TMP"
mv "$GITIGNORE_TMP" .gitignore
echo "Updated .gitignore"

# ---- pubspec.yaml ----
# Update msix_version (4-part format: major.minor.patch.build) BEFORE version,
# because the version: regex would otherwise also match msix_version: lines via greedy whitespace.
sedi -E "s/^([[:space:]]*)msix_version:[[:space:]]*.*/\1msix_version: $NEW_VERSION.0/" pubspec.yaml
sedi -E "s/^version: .*/version: $NEW_VERSION+$VERSION_CODE/" pubspec.yaml
echo "Updated pubspec.yaml (version: $NEW_VERSION+$VERSION_CODE, msix_version: $NEW_VERSION.0)"

# ---- installer/otzaria_full.iss ----
ISS_FULL="installer/otzaria_full.iss"
if [[ -f "$ISS_FULL" ]]; then
    sedi -E "s/^#define MyAppVersion .*/#define MyAppVersion \"$NEW_VERSION\"/" "$ISS_FULL"
    echo "Updated $ISS_FULL"
fi

# ---- installer/otzaria.iss ----
ISS="installer/otzaria.iss"
if [[ -f "$ISS" ]]; then
    sedi -E "s/^#define MyAppVersion .*/#define MyAppVersion \"$NEW_VERSION\"/" "$ISS"
    echo "Updated $ISS"
fi

# ---- android/local.properties ----
LOCAL_PROPS="android/local.properties"
if [[ -f "$LOCAL_PROPS" ]]; then
    if grep -q "flutter\.versionName=" "$LOCAL_PROPS"; then
        sedi "s/flutter\.versionName=.*/flutter.versionName=$NEW_VERSION/" "$LOCAL_PROPS"
    else
        echo "flutter.versionName=$NEW_VERSION" >> "$LOCAL_PROPS"
    fi
    if grep -q "flutter\.versionCode=" "$LOCAL_PROPS"; then
        sedi "s/flutter\.versionCode=.*/flutter.versionCode=$VERSION_CODE/" "$LOCAL_PROPS"
    else
        echo "flutter.versionCode=$VERSION_CODE" >> "$LOCAL_PROPS"
    fi
    echo "Updated $LOCAL_PROPS (versionName=$NEW_VERSION, versionCode=$VERSION_CODE)"
fi

# ---- lib/main.dart (_latestReleasedBuildNumber) ----
MAIN_DART="lib/main.dart"
if [[ -f "$MAIN_DART" ]]; then
    sedi -E "s/^const int _latestReleasedBuildNumber = [0-9]+;/const int _latestReleasedBuildNumber = $VERSION_CODE;/" "$MAIN_DART"
    echo "Updated $MAIN_DART (_latestReleasedBuildNumber = $VERSION_CODE)"
fi

# ---- macos/Runner.xcodeproj/project.pbxproj ----
PBXPROJ="macos/Runner.xcodeproj/project.pbxproj"
if [[ -f "$PBXPROJ" ]]; then
    sedi -E "s/MARKETING_VERSION = [0-9.]+;/MARKETING_VERSION = $NEW_VERSION;/g" "$PBXPROJ"
    sedi -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $VERSION_CODE;/g" "$PBXPROJ"
    echo "Updated $PBXPROJ (MARKETING_VERSION=$NEW_VERSION, CURRENT_PROJECT_VERSION=$VERSION_CODE)"
fi

# ---- assets/יומן שינויים.md ----
CHANGELOG="assets/יומן שינויים.md"
if [[ -f "$CHANGELOG" ]]; then
    EXISTING=$(cat "$CHANGELOG")
    printf "* **%s**\n%s" "$NEW_VERSION" "$EXISTING" > "$CHANGELOG"
    echo "Updated $CHANGELOG with new version: $NEW_VERSION"
fi

# ---- Git commit ----
git add ".gitignore" "pubspec.yaml" "$VERSION_FILE" "$MAIN_DART" "$CHANGELOG"
[[ -f "$ISS_FULL" ]]   && git add "$ISS_FULL"
[[ -f "$ISS" ]]        && git add "$ISS"
# project.pbxproj is tracked but lives under a path matched by .gitignore (macos/*),
# so plain `git add` prints a warning and exits 1 — killing the script under `set -e`.
# -f forces the add for this already-tracked file.
[[ -f "$PBXPROJ" ]]    && git add -f "$PBXPROJ"

git commit -m "$NEW_VERSION"

echo ""
echo "Version update completed successfully!"
echo "All files have been updated to version: $NEW_VERSION"
