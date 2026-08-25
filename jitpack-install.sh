#!/usr/bin/env bash
set -euo pipefail

readonly repository_group="${GROUP:-com.github.wxuanwx}.${ARTIFACT:-ar-sdk}"
readonly repository_artifact="${ARTIFACT:-ar-sdk}"
readonly release_version="${VERSION:-1.0.0}"
readonly local_repository="${HOME}/.m2/repository"
readonly ypjar_checksum="3b6232672368f76d1ebd7bc1d2af357c382c2c34fdb709c464a8719ea9e849a6"

ypjar_source="ypjar-lib-release.aar"
if [[ ! -f "$ypjar_source" ]]; then
  ypjar_source="$(mktemp /tmp/ypjar-lib-release.XXXXXX.aar)"
  cat ypjar-lib-release.aar.part-* > "$ypjar_source"
fi

[[ "$(sha256sum "$ypjar_source" | cut -d' ' -f1)" == "$ypjar_checksum" ]] || {
  printf 'Invalid ypjar-lib artifact checksum.\n' >&2
  exit 1
}

readonly artifacts=(
  "${ypjar_source}|ypjar-lib"
  "libyuv-debug.aar|libyuv"
  "bubbleseekbar-release.aar|bubbleseekbar"
  "breakpad-build-release.aar|breakpad-build"
  "android-gif-drawable-1.2.28.aar|android-gif-drawable"
  "oaid_sdk_1.0.25.aar|oaid-sdk"
)

group_path="${repository_group//./\/}"

write_pom() {
  local target="$1"
  local artifact_id="$2"
  local packaging="$3"
  cat > "$target" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>${repository_group}</groupId>
  <artifactId>${artifact_id}</artifactId>
  <version>${release_version}</version>
  <packaging>${packaging}</packaging>
</project>
EOF
}

for artifact in "${artifacts[@]}"; do
  IFS='|' read -r source_file artifact_id <<< "$artifact"
  [[ -f "$source_file" ]] || { printf 'Missing artifact: %s\n' "$source_file" >&2; exit 1; }

  target_dir="${local_repository}/${group_path}/${artifact_id}/${release_version}"
  target_base="${artifact_id}-${release_version}"
  mkdir -p "$target_dir"
  cp "$source_file" "${target_dir}/${target_base}.aar"
  write_pom "${target_dir}/${target_base}.pom" "$artifact_id" "aar"
  printf 'Installed %s:%s:%s\n' "$repository_group" "$artifact_id" "$release_version"
done

aggregate_dir="${local_repository}/${group_path}/${repository_artifact}/${release_version}"
aggregate_pom="${aggregate_dir}/${repository_artifact}-${release_version}.pom"
mkdir -p "$aggregate_dir"
cat > "$aggregate_pom" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>${repository_group}</groupId>
  <artifactId>${repository_artifact}</artifactId>
  <version>${release_version}</version>
  <packaging>pom</packaging>
  <dependencies>
EOF

for artifact in "${artifacts[@]}"; do
  IFS='|' read -r source_file artifact_id <<< "$artifact"
  cat >> "$aggregate_pom" <<EOF
    <dependency>
      <groupId>${repository_group}</groupId>
      <artifactId>${artifact_id}</artifactId>
      <version>${release_version}</version>
      <type>aar</type>
    </dependency>
EOF
done

cat >> "$aggregate_pom" <<'EOF'
  </dependencies>
</project>
EOF

printf 'Installed aggregate %s:%s:%s\n' "$repository_group" "$repository_artifact" "$release_version"
