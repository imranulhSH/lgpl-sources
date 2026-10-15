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

# Patches that edit the same file in sequence. A later patch rewrites lines
# around an earlier one, so a per-patch "--dry-run" check is wrong once the
# stack is in: the first patch's insertion can apply a second time (patch
# finds its context elsewhere) and the second patch then fails. Decide for the
# whole stack instead, without fuzz: either every patch applies in order to the
# current file (pristine source), or every patch reverses in reverse order
# (already applied). Anything else is a partly patched or foreign source and
# fails closed.
apply_source_patch_stack() {
  local target_relative_path="$1"
  shift
  local target_file="$source_dir/$target_relative_path"
  local patch_files=()
  local labels=()
  while [[ $# -gt 0 ]]; do
    patch_files+=("$1")
    labels+=("$2")
    shift 2
  done

  if [[ ! -f "$target_file" ]]; then
    printf 'error: FFmpeg source is missing %s: %s\n' "$target_relative_path" "$source_dir" >&2
    exit 66
  fi
  local patch_file
  for patch_file in "${patch_files[@]}"; do
    if [[ ! -f "$patch_file" ]]; then
      printf 'error: required FFmpeg source patch is missing: %s\n' "$patch_file" >&2
      exit 66
    fi
  done

  local scratch
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/npc-ffmpeg-patch-stack.XXXXXX")"
  mkdir -p "$scratch/$(dirname "$target_relative_path")"
  local index
  local forward_applies=1
  cp "$target_file" "$scratch/$target_relative_path"
  for patch_file in "${patch_files[@]}"; do
    if ! patch -d "$scratch" -p1 -N -F 0 -s <"$patch_file" >/dev/null 2>&1; then
      forward_applies=0
      break
    fi
  done
  if [[ $forward_applies -eq 1 ]]; then
    rm -rf "$scratch"
    for index in "${!patch_files[@]}"; do
      patch -d "$source_dir" -p1 -N -F 0 <"${patch_files[$index]}"
      printf 'Applied %s: %s\n' "${labels[$index]}" "$source_dir"
    done
    return 0
  fi

  local reverse_applies=1
  cp "$target_file" "$scratch/$target_relative_path"
  for (( index = ${#patch_files[@]} - 1; index >= 0; index-- )); do
    if ! patch -d "$scratch" -p1 -R -F 0 -s <"${patch_files[$index]}" >/dev/null 2>&1; then
      reverse_applies=0
      break
    fi
  done
  rm -rf "$scratch"
  if [[ $reverse_applies -eq 1 ]]; then
    for index in "${!labels[@]}"; do
      printf '%s already applied: %s\n' "${labels[$index]}" "$source_dir"
    done
    return 0
  fi

  printf 'error: FFmpeg source is incompatible with the required %s: %s\n' \
    "${labels[0]}" "$source_dir" >&2
  exit 65
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
apply_source_patch_stack \
  "libavformat/hls.c" \
  "$script_dir/patches/ffmpeg-hls-presentation-origin-seek.patch" \
  "FFmpeg HLS presentation-origin seek patch" \
  "$script_dir/patches/ffmpeg-hls-timeline-epochs.patch" \
  "FFmpeg HLS timeline epochs and subtitle selection patch" \
  "$script_dir/patches/ffmpeg-hls-midplay-subtitle.patch" \
  "FFmpeg HLS playing subtitle selection patch"
apply_source_patch \
  "$script_dir/patches/ffmpeg-webvtt-hls-timestamp-map.patch" \
  "libavformat/webvttdec.c" \
  "FFmpeg HLS WebVTT timestamp-map patch"
apply_source_patch \
  "$script_dir/patches/ffmpeg-mov-channel-layout-status.patch" \
  "libavformat/mov.c" \
  "FFmpeg MOV channel-layout error propagation patch"
apply_source_patch \
  "$script_dir/patches/ffmpeg-vobsub-host-io-inheritance.patch" \
  "libavformat/mpeg.c" \
  "FFmpeg VobSub host-I/O inheritance patch"
