#!/usr/bin/env bash
set -euo pipefail

readonly repository_group="com.github.wxuanwx.ar-sdk"
readonly github_repository="wxuanwx/ar-sdk"
readonly artifact_config="artifacts.conf"
readonly checksum_file="artifacts.sha256"
readonly tag_history_file="jitpack-tag-history.txt"
readonly split_size="45M"
readonly jitpack_base="https://jitpack.io/com/github/wxuanwx/ar-sdk"

usage() {
  cat <<'EOF'
Usage: ./release-jitpack.sh <version> [--prepare-only]

Examples:
  ./release-jitpack.sh 1.0.1
  ./release-jitpack.sh 1.0.1 --prepare-only

The script automatically creates the first unused tag in this form:
  <version>-jitpack.1, <version>-jitpack.2, ...
EOF
}

[[ $# -ge 1 && $# -le 2 ]] || { usage >&2; exit 1; }
base_version="$1"
prepare_only=false
if [[ "${2:-}" == "--prepare-only" ]]; then
  prepare_only=true
elif [[ $# -eq 2 ]]; then
  usage >&2
  exit 1
fi

[[ "$base_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z]+)*$ ]] || {
  printf 'Invalid version: %s\n' "$base_version" >&2
  exit 1
}

for command_name in git curl sha256sum split awk sed cmp python3; do
  command -v "$command_name" >/dev/null || { printf 'Missing command: %s\n' "$command_name" >&2; exit 1; }
done

[[ -f "$artifact_config" ]] || { printf 'Missing %s\n' "$artifact_config" >&2; exit 1; }
[[ -f jitpack-install.sh ]] || { printf 'Missing jitpack-install.sh\n' >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null

temp_dir="$(mktemp -d /tmp/ar-sdk-release.XXXXXX)"
cleanup() {
  rm -rf "$temp_dir"
}
trap cleanup EXIT INT TERM

resolve_artifact() {
  local source_file="$1"
  local storage="$2"
  local resolved_source="$source_file"
  if [[ ! -f "$resolved_source" && "$storage" == "split" ]]; then
    resolved_source="${temp_dir}/${source_file}"
    compgen -G "${source_file}.part-*" >/dev/null || {
      printf 'Missing %s and its split parts.\n' "$source_file" >&2
      exit 1
    }
    cat "${source_file}.part-"* > "$resolved_source"
  fi
  [[ -f "$resolved_source" ]] || { printf 'Missing artifact: %s\n' "$source_file" >&2; exit 1; }
  printf '%s' "$resolved_source"
}

printf 'Validating artifacts ...\n'
: > "${temp_dir}/${checksum_file}"
while IFS='|' read -r source_file artifact_id storage; do
  [[ -n "$source_file" && "${source_file:0:1}" != "#" ]] || continue
  resolved_source="$(resolve_artifact "$source_file" "$storage")"
  sha256sum "$resolved_source" | awk -v file="$source_file" '{ print $1 "  " file }' >> "${temp_dir}/${checksum_file}"

  if [[ "$storage" == "split" && -f "$source_file" ]]; then
    rm -f "${source_file}.part-"*
    split -b "$split_size" -d -a 2 "$source_file" "${source_file}.part-"
    reconstructed_file="${temp_dir}/reconstructed-${source_file}"
    cat "${source_file}.part-"* > "$reconstructed_file"
    cmp "$source_file" "$reconstructed_file"
    printf 'Split and verified %s\n' "$source_file"
  fi
done < "$artifact_config"
mv "${temp_dir}/${checksum_file}" "$checksum_file"

remote_tags="$(git ls-remote --tags origin 2>/dev/null | sed 's#.*refs/tags/##' || true)"
local_tags="$(git tag --list || true)"
tag_index=0
while IFS= read -r existing_tag; do
  if [[ "$existing_tag" =~ ^${base_version//./\.}-jitpack\.([0-9]+)$ ]]; then
    existing_index="${BASH_REMATCH[1]}"
    (( existing_index > tag_index )) && tag_index="$existing_index"
  fi
done < <(cat "$tag_history_file" 2>/dev/null; printf '%s\n%s\n' "$remote_tags" "$local_tags")
((tag_index += 1))
release_tag="${base_version}-jitpack.${tag_index}"
printf 'Selected release tag: %s\n' "$release_tag"
printf '%s\n' "$release_tag" >> "$tag_history_file"

python3 - "$release_tag" <<'PY'
from pathlib import Path
import re
import sys

readme = Path("README.md")
text = readme.read_text(encoding="utf-8")
tag = sys.argv[1]
text = re.sub(
    r'(com\.github\.wxuanwx\.ar-sdk:[a-z0-9-]+:)[^"\s]+',
    rf'\g<1>{tag}',
    text,
)
text = re.sub(
    r'(?:All modules|These three modules) use the verified `[^`]+` release tag\.',
    f'These three modules use the verified `{tag}` release tag.',
    text,
)
readme.write_text(text, encoding="utf-8")
PY

printf 'Running local JitPack simulation ...\n'
work_dir="${temp_dir}/work"
mkdir -p "$work_dir"
cp artifacts.conf artifacts.sha256 jitpack-install.sh pom.xml "$work_dir/"
while IFS='|' read -r source_file artifact_id storage; do
  [[ -n "$source_file" && "${source_file:0:1}" != "#" ]] || continue
  mkdir -p "${work_dir}/${artifact_id}"
  cp "${artifact_id}/pom.xml" "${work_dir}/${artifact_id}/pom.xml"
  if [[ "$storage" == "split" ]]; then
    cp "${source_file}.part-"* "$work_dir/"
  else
    cp "$source_file" "$work_dir/"
  fi
done < "$artifact_config"
(
  cd "$work_dir"
  HOME="${temp_dir}/home" GROUP=com.github.wxuanwx ARTIFACT=ar-sdk VERSION="$release_tag" ./jitpack-install.sh
)

if "$prepare_only"; then
  printf 'Preparation passed. Files were updated, but no commit, tag, push, or JitPack request was made.\n'
  exit 0
fi

git add README.md artifacts.conf artifacts.sha256 jitpack-install.sh release-jitpack.sh RELEASING.md \
  jitpack-tag-history.txt pom.xml
while IFS='|' read -r source_file artifact_id storage; do
  [[ -n "$source_file" && "${source_file:0:1}" != "#" ]] || continue
  git add "${artifact_id}/pom.xml"
  if [[ "$storage" == "split" ]]; then
    git add -f "${source_file}.part-"*
    git add -u -- "$source_file" 2>/dev/null || true
  else
    git add -f "$source_file"
  fi
done < "$artifact_config"

if ! git diff --cached --quiet; then
  git commit -m "Release AAR bundle ${release_tag}"
fi
git tag "$release_tag"
git push origin HEAD:main "$release_tag"

printf 'Waiting for JitPack build ...\n'
first_module="$(awk -F'|' '$1 !~ /^#/ && NF >= 2 { print $2; exit }' "$artifact_config")"
pom_url="${jitpack_base}/${first_module}/${release_tag}/${first_module}-${release_tag}.pom"
build_log_url="${jitpack_base}/${release_tag}/build.log"
for attempt in $(seq 1 40); do
  http_status="$(curl -sS --output "${temp_dir}/jitpack-response" --write-out '%{http_code}' --connect-timeout 20 --max-time 600 "$pom_url" || true)"
  if [[ "$http_status" == "200" ]]; then
    break
  fi
  if grep -q 'Build failed' "${temp_dir}/jitpack-response"; then
    curl -sS "$build_log_url" >&2 || true
    printf 'JitPack build failed. Fix the issue and rerun; a new .N tag will be selected.\n' >&2
    exit 1
  fi
  if [[ "$attempt" == "40" ]]; then
    printf 'Timed out waiting for JitPack. Check: %s\n' "$build_log_url" >&2
    exit 1
  fi
  printf 'JitPack not ready (%s), retrying %s/40 ...\n' "$http_status" "$attempt"
  sleep 15
done

printf 'Downloading and verifying published AARs ...\n'
while IFS='|' read -r source_file artifact_id storage; do
  [[ -n "$source_file" && "${source_file:0:1}" != "#" ]] || continue
  remote_file="${temp_dir}/${artifact_id}-${release_tag}.aar"
  curl -fsS --retry 3 --retry-all-errors --connect-timeout 20 --max-time 900 \
    -o "$remote_file" \
    "${jitpack_base}/${artifact_id}/${release_tag}/${artifact_id}-${release_tag}.aar"
  expected_checksum="$(awk -v file="$source_file" '$2 == file { print $1 }' "$checksum_file")"
  actual_checksum="$(sha256sum "$remote_file" | cut -d' ' -f1)"
  [[ "$actual_checksum" == "$expected_checksum" ]] || {
    printf 'Published checksum mismatch: %s\n' "$artifact_id" >&2
    exit 1
  }
  printf 'Verified %s\n' "$artifact_id"
done < "$artifact_config"

printf 'Release completed: %s\n' "$release_tag"
