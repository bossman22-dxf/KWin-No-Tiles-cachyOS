#!/usr/bin/env bash
set -euo pipefail

config=/tmp/pacman-kwin-no-tiles-v3.conf
{
  printf '%s\n' \
    '[options]' \
    'Architecture = auto' \
    'CheckSpace' \
    'SigLevel = Required DatabaseOptional' \
    'LocalFileSigLevel = Optional' \
    '' \
    '[cachyos-v3]' \
    'Include = /etc/pacman.d/cachyos-v3-mirrorlist' \
    '' \
    '[cachyos-core-v3]' \
    'Include = /etc/pacman.d/cachyos-v3-mirrorlist' \
    '' \
    '[cachyos-extra-v3]' \
    'Include = /etc/pacman.d/cachyos-v3-mirrorlist' \
    '' \
    '[cachyos]' \
    'Include = /etc/pacman.d/cachyos-mirrorlist' \
    '' \
    '[core]' \
    'Include = /etc/pacman.d/mirrorlist' \
    '' \
    '[extra]' \
    'Include = /etc/pacman.d/mirrorlist'
} > "$config"

synced=false
for attempt in 1 2 3; do
  if pacman --config "$config" -Syy --noconfirm; then
    synced=true
    break
  fi
  if [[ "$attempt" -lt 3 ]]; then
    sleep "$((attempt * 3))"
  fi
done
if [[ "$synced" != true ]]; then
  echo '::error::Unable to sync CachyOS v3 repository databases after three attempts.' >&2
  exit 1
fi

info="$(pacman --config "$config" -Si kwin)"
repository="$(printf '%s\n' "$info" | sed -n 's/^Repository[[:space:]]*:[[:space:]]*//p' | head -n 1)"
version="$(printf '%s\n' "$info" | sed -n 's/^Version[[:space:]]*:[[:space:]]*//p' | head -n 1)"

[[ -n "$repository" && -n "$version" ]] || {
  echo '::error::Could not read KWin version/repository from CachyOS metadata.' >&2
  exit 1
}
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+([.][0-9]+)*$ ]] || {
  echo "::error::Unexpected CachyOS KWin version format: $version" >&2
  exit 1
}

printf 'Repository: %s\nVersion: %s\n' "$repository" "$version"
