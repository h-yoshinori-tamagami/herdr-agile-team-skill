#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s [--dry-run]\n' "${0##*/}" >&2
}

dry_run=false
case "${1:-}" in
  "") ;;
  --dry-run) dry_run=true ;;
  *) usage; exit 2 ;;
esac

if [[ "$#" -gt 1 ]]; then
  usage
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
source_config="$repo_root/config/herdr/config.toml"
config_home="${XDG_CONFIG_HOME:-${HOME:?HOME is not set}/.config}"
target_dir="$config_home/herdr"
target="$target_dir/config.toml"

if [[ ! -f "$source_config" ]]; then
  printf 'Source config not found: %s\n' "$source_config" >&2
  exit 1
fi

if [[ -L "$target" ]]; then
  printf 'Refusing to replace a symlink: %s\n' "$target" >&2
  exit 1
fi

if [[ -e "$target" && ! -f "$target" ]]; then
  printf 'Target exists and is not a regular file: %s\n' "$target" >&2
  exit 1
fi

if [[ -f "$target" ]] && cmp -s "$source_config" "$target"; then
  printf 'Herdr config is already up to date: %s\n' "$target"
  exit 0
fi

if [[ "$dry_run" == true ]]; then
  if [[ -f "$target" ]]; then
    printf 'Would back up %s and replace it with %s\n' "$target" "$source_config"
  else
    printf 'Would install %s to %s\n' "$source_config" "$target"
  fi
  exit 0
fi

mkdir -p "$target_dir"

if [[ -f "$target" ]]; then
  backup="$target.backup.$(date +%Y%m%d%H%M%S).$$"
  cp -p "$target" "$backup"
  printf 'Backed up existing config to %s\n' "$backup"
fi

tmp_file="$(mktemp "$target.tmp.XXXXXX")"
cleanup() {
  if [[ -n "${tmp_file:-}" ]]; then
    rm -f "$tmp_file"
  fi
}
trap cleanup EXIT

cp "$source_config" "$tmp_file"
chmod 0644 "$tmp_file"
mv -f "$tmp_file" "$target"
tmp_file=""
trap - EXIT

printf 'Applied Herdr config to %s\n' "$target"
