#!/usr/bin/env bash
set -euo pipefail

main() {
    if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
        usage
        return
    fi
    if (( $# < 2 || $# > 3 )); then
        usage >&2
        return 2
    fi
    local version="${1#ramlab-}" base_image="$2" jobs="${3:-4}"
    version="${version#v}"
    local component='(0|[1-9][0-9]*)'
    if [[ ! "$version" =~ ^${component}\.${component}\.${component}(\.${component})?$ ]]; then
        printf 'Version must have three or four numeric components.\n' >&2
        return 2
    fi
    if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then
        printf 'Jobs must be a positive integer.\n' >&2
        return 2
    fi
    local source_dir output_dir log_file
    source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
    output_dir="${source_dir}/dist/local/${version}"
    mkdir -p "${source_dir}/build-local/logs"
    log_file="${source_dir}/build-local/logs/$(date -u +%Y%m%dT%H%M%SZ)-$$.log"
    printf 'Building local source: %s\nBuild log: %s\n' "$source_dir" "$log_file"
    docker build --pull --progress=plain --target artifacts \
        --file "${source_dir}/Dockerfile" \
        --build-arg "BASE_IMAGE=${base_image}" \
        --build-arg "OPEN3D_PACKAGE_VERSION=${version}" \
        --build-arg "NPROC=${jobs}" \
        --output "type=local,dest=${output_dir}" \
        "$source_dir" 2>&1 | tee "$log_file"
    printf 'Verified packages: %s\n' "$output_dir"
}

usage() {
    cat <<'HELP'
Usage: packaging/build-local.sh VERSION MAXQ_BASE_IMAGE [JOBS]

Build the current checkout, including uncommitted edits, using the workflow's
Dockerfile. VERSION may also be a tag name prefixed with v or ramlab-v;
it labels the packages and does not change the checkout.

MAXQ_BASE_IMAGE must explicitly select the published base image. JOBS defaults to 4.
Example: packaging/build-local.sh 4.0.0 "$MAXQ_BASE_IMAGE" 4

The build pulls the published base image, reuses Docker's compilation cache,
and checks APT and wheel installations in separate containers. It never publishes.
Use your existing Docker login for access to ghcr.io.

Packages: dist/local/VERSION/
Logs:     build-local/logs/
After fixing a compile error, rerun the same command to resume compilation.
HELP
}

main "$@"
