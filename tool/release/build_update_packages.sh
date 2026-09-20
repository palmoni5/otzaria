#!/usr/bin/env bash
# בונה חבילות עדכון דיפרנציאליות לארכיטקטורה אחת: מול עד N השחרורים
# הקודמים שיש להם מניפסט קובצי אפליקציה לאותה ארכיטקטורה.
#
# כל מעבר מפיק **שתי** חבילות: ה-patch, שהלקוח מנסה קודם, ו-`-files` —
# אותם קבצים דחוסים במלואם, שממנה מושלם כל ערך שה-patch שלו אינו ישים.
#
# usage: build_update_packages.sh <arch> <new-tag> <new-manifest> <new-zip> <out-dir> [base-count]
#
# הכלי הוא אופטימיזציה: כישלון כאן משאיר את המשתמשים על המתקין המלא.
set -euo pipefail

arch=${1:?usage: build_update_packages.sh <arch> <new-tag> <new-manifest> <new-zip> <out-dir> [base-count]}
new_tag=${2:?missing new release tag}
new_manifest=${3:?missing new app file manifest}
new_zip=${4:?missing new portable zip}
out_dir=${5:?missing output directory}
base_count=${6:-2}

source_repo=${UPDATE_PACKAGES_SOURCE_REPO:-Otzaria/otzaria}
manifest_asset="otzaria-app-files-windows-${arch}.json"

[ -f "$new_manifest" ] || { echo "::warning::$new_manifest is missing - no update packages for $arch"; exit 0; }
[ -f "$new_zip" ] || { echo "::warning::$new_zip is missing - no update packages for $arch"; exit 0; }

mkdir -p "$out_dir"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

new_root="$work/new"
mkdir -p "$new_root"
unzip -q -o "$new_zip" -d "$new_root"

# השחרורים הקודמים, החדש ביותר תחילה, בלי טיוטות ובלי השחרור הנוכחי.
mapfile -t candidates < <(
  gh release list --repo "$source_repo" --limit 40 \
    --json tagName,isDraft,createdAt \
    --jq 'map(select(.isDraft | not)) | sort_by(.createdAt) | reverse | .[].tagName' |
    grep -v -x -- "$new_tag" || true
)

built=0
for tag in "${candidates[@]}"; do
  [ "$built" -lt "$base_count" ] || break
  base="$work/base"
  rm -rf "$base"
  mkdir -p "$base"

  if ! gh release download "$tag" --repo "$source_repo" \
    --pattern "$manifest_asset" --dir "$base" >/dev/null 2>&1; then
    echo "$tag has no $manifest_asset - skipping"
    continue
  fi
  zip_pattern="otzaria-windows.zip"
  [ "$arch" = "x64" ] || zip_pattern="otzaria-windows_${arch}.zip"
  if ! gh release download "$tag" --repo "$source_repo" \
    --pattern "$zip_pattern" --dir "$base" >/dev/null 2>&1; then
    echo "::warning::$tag has $manifest_asset but no $zip_pattern - skipping"
    continue
  fi

  old_root="$base/root"
  mkdir -p "$old_root"
  unzip -q -o "$base/$zip_pattern" -d "$old_root"

  if ! dart run tool/release/generate_update_package.dart \
    --old-manifest "$base/$manifest_asset" --old-dir "$old_root" \
    --new-manifest "$new_manifest" --new-dir "$new_root" \
    --out-dir "$out_dir" --verify; then
    echo "::warning::could not build an update package from $tag - skipping"
    continue
  fi
  built=$((built + 1))
done

if [ "$built" -eq 0 ]; then
  echo "::warning::no update packages were built for $arch"
fi
echo "built $built update package(s) for $arch"
