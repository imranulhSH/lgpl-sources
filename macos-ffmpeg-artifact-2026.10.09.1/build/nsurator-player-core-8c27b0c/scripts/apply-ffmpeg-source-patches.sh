#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/apply-ffmpeg-source-patches.sh <ffmpeg-source-directory>

Apply the repository-maintained FFmpeg source patches required by the Apple
artifact build. Patches are idempotent and fail closed for an incompatible
source checkout.
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi
if [[ $# -ne 1 || -z "$1" ]]; then
  usage >&2
  exit 64
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$1"

apply_source_patch() {
  local patch_file="$1"
  local target_relative_path="$2"
  local label="$3"
  local target_file="$source_dir/$target_relative_path"

  if [[ ! -f "$target_file" ]]; then
    printf 'error: FFmpeg source is missing %s: %s\n' "$target_relative_path" "$source_dir" >&2
    exit 66
  fi
  if [[ ! -f "$patch_file" ]]; then
    printf 'error: required FFmpeg source patch is missing: %s\n' "$patch_file" >&2
    exit 66
  fi

  if patch -d "$source_dir" -p1 -N --dry-run <"$patch_file" >/dev/null 2>&1; then
    patch -d "$source_dir" -p1 -N <"$patch_file"
    printf 'Applied %s: %s\n' "$label" "$source_dir"
  elif patch -d "$source_dir" -p1 -R --dry-run <"$patch_file" >/dev/null 2>&1; then
    printf '%s already applied: %s\n' "$label" "$source_dir"
  else
    printf 'error: FFmpeg source is incompatible with the required %s: %s\n' \
      "$label" "$source_dir" >&2
    exit 65
  fi
}

apply_source_patch \
  "$script_dir/patches/ffmpeg-hls-child-network-options.patch" \
  "libavformat/aviobuf.c" \
  "FFmpeg HLS child network-option patch"
apply_source_patch \
  "$script_dir/patches/ffmpeg-securetransport-trust-errors.patch" \
  "libavformat/tls_securetransport.c" \
  "FFmpeg Secure Transport trust-error patch"
apply_source_patch \
  "$script_dir/patches/ffmpeg-libssh-host-key-verification.patch" \
  "libavformat/libssh.c" \
  "FFmpeg libssh host-key verification patch"
apply_source_patch \
  "$script_dir/patches/ffmpeg-matroska-interrupt-exit.patch" \
  "libavformat/matroskadec.c" \
  "FFmpeg Matroska interrupt-exit patch"
apply_source_patch \
  "$script_dir/patches/ffmpeg-matroska-invalid-level.patch" \
  "libavformat/matroskadec.c" \
  "FFmpeg Matroska invalid-level patch"
apply_source_patch \
  "$script_dir/patches/ffmpeg-http-stale-auth-retry.patch" \
  "libavformat/http.c" \
  "FFmpeg HTTP stale-auth retry patch"
apply_source_patch \
  "$script_dir/patches/ffmpeg-network-dns-error.patch" \
  "libavformat/tcp.c" \
  "FFmpeg network DNS-error patch"
