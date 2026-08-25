#!/usr/bin/env bash
set -euo pipefail

readonly root_group="${GROUP:-com.github.wxuanwx}"
readonly repository_group="${root_group}.${ARTIFACT:-ar-sdk}"
readonly repository_artifact="${ARTIFACT:-ar-sdk}"
readonly release_version="${VERSION:-1.0.0}"
readonly local_repository="${HOME}/.m2/repository"
readonly artifact_config="artifacts.conf"
readonly checksum_file="artifacts.sha256"

[[ -f "$artifact_config" ]] || { printf 'Missing %s\n' "$artifact_config" >&2; exit 1; }
[[ -f "$checksum_file" ]] || { printf 'Missing %s\n' "$checksum_file" >&2; exit 1; }

temp_dir="$(mktemp -d /tmp/ar-sdk-jitpack.XXXXXX)"
cleanup() {
  rm -rf "$temp_dir"
}
trap cleanup EXIT INT TERM

artifacts=()
while IFS='|' read -r source_file artifact_id storage; do
  [[ -n "$source_file" && "${source_file:0:1}" != "#" ]] || continue
  resolved_source="$source_file"
  if [[ ! -f "$resolved_source" && "$storage" == "split" ]]; then
    resolved_source="${temp_dir}/${source_file}"
    compgen -G "${source_file}.part-*" >/dev/null || {
      printf 'Missing artifact and parts: %s\n' "$source_file" >&2
      exit 1
    }
    cat "${source_file}.part-"* > "$resolved_source"
  fi
  [[ -f "$resolved_source" ]] || { printf 'Missing artifact: %s\n' "$source_file" >&2; exit 1; }

  expected_checksum="$(awk -v file="$source_file" '$2 == file { print $1 }' "$checksum_file")"
  [[ -n "$expected_checksum" ]] || { printf 'Missing checksum: %s\n' "$source_file" >&2; exit 1; }
  actual_checksum="$(sha256sum "$resolved_source" | cut -d' ' -f1)"
  [[ "$actual_checksum" == "$expected_checksum" ]] || {
    printf 'Invalid checksum for %s\n' "$source_file" >&2
    exit 1
  }
  artifacts+=("${resolved_source}|${artifact_id}")
done < "$artifact_config"

group_path="${repository_group//./\/}"
root_group_path="${root_group//./\/}"

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
  mkdir -p "$artifact_id"
  cp "$source_file" "${target_dir}/${target_base}.aar"
  write_pom "${target_dir}/${target_base}.pom" "$artifact_id" "aar"
  write_pom "${artifact_id}/pom.xml" "$artifact_id" "aar"
  printf 'Installed %s:%s:%s\n' "$repository_group" "$artifact_id" "$release_version"
done

cat > pom.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>${root_group}</groupId>
  <artifactId>${repository_artifact}</artifactId>
  <version>${release_version}</version>
  <packaging>pom</packaging>
  <name>AR SDK binary artifacts</name>
  <modules>
EOF

for artifact in "${artifacts[@]}"; do
  IFS='|' read -r source_file artifact_id <<< "$artifact"
  printf '    <module>%s</module>\n' "$artifact_id" >> pom.xml
done

cat >> pom.xml <<'EOF'
  </modules>
</project>
EOF

aggregate_dir="${local_repository}/${root_group_path}/${repository_artifact}/${release_version}"
aggregate_pom="${aggregate_dir}/${repository_artifact}-${release_version}.pom"
mkdir -p "$aggregate_dir"
cat > "$aggregate_pom" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>${root_group}</groupId>
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

printf 'Installed aggregate %s:%s:%s\n' "$root_group" "$repository_artifact" "$release_version"
