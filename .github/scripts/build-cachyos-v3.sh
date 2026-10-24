#!/usr/bin/env bash
set -euo pipefail

expected_version="${EXPECTED_PACKAGE_VERSION:?EXPECTED_PACKAGE_VERSION is required}"
[[ "$expected_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+([.][0-9]+)*$ ]] || {
  echo "::error::Invalid package version-release: $expected_version" >&2
  exit 1
}
pkgver="${expected_version%-*}"
pkgrel="${expected_version##*-}"
output=/output
mkdir -p "$output"

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
install -m 0644 "$config" /etc/pacman.conf

pacman_sync_succeeded=false
for attempt in 1 2 3; do
  if pacman -Syy --noconfirm; then
    pacman_sync_succeeded=true
    break
  fi
  if [[ "$attempt" -lt 3 ]]; then
    sleep "$((attempt * 3))"
  fi
done
if [[ "$pacman_sync_succeeded" != true ]]; then
  echo '::error::Unable to sync CachyOS v3 package databases.' >&2
  exit 1
fi

check_live_version() {
  local info actual
  info="$(pacman -Si kwin)"
  actual="$(printf '%s\n' "$info" | sed -n 's/^Version[[:space:]]*:[[:space:]]*//p' | head -n 1)"
  printf '%s\n' "$info" | grep -E '^(Repository|Name|Version)[[:space:]]*:'
  [[ "$actual" == "$expected_version" ]] || {
    echo "::error::CachyOS v3 now provides $actual, not expected $expected_version." >&2
    return 1
  }
}
check_live_version

install_succeeded=false
for attempt in 1 2 3; do
  if pacman -Syu --noconfirm --needed base-devel sudo git; then
    install_succeeded=true
    break
  fi
  if [[ "$attempt" -lt 3 ]]; then
    echo "Dependency transaction failed on attempt $attempt; refreshing package databases and retrying." >&2
    pacman -Syy --noconfirm || true
    sleep "$((attempt * 5))"
  fi
done
if [[ "$install_succeeded" != true ]]; then
  echo '::error::Could not install the build toolchain after three attempts.' >&2
  exit 1
fi

# Build for Ryzen 9 3950X (Zen 2) / x86-64-v3, not the CI runner CPU.
sed -i 's/-march=native/-march=x86-64-v3 -mtune=znver2/g' /etc/makepkg.conf
if grep -q -- '-march=native' /etc/makepkg.conf; then
  echo '::error::-march=native remains in /etc/makepkg.conf.' >&2
  exit 1
fi
grep -Fq -- '-march=x86-64-v3 -mtune=znver2' /etc/makepkg.conf || {
  echo '::error::Could not set the Zen 2 / x86-64-v3 compiler baseline.' >&2
  exit 1
}
echo '=== Verified compiler flags ==='
grep -E '^(CFLAGS|CXXFLAGS|LDFLAGS|MAKEFLAGS)=' /etc/makepkg.conf || true

# Repository versions can change while the builder updates. Confirm again
# immediately before calculating/building the package.
check_live_version

chmod 0777 "$output"
if ! id builder >/dev/null 2>&1; then
  useradd --create-home builder
fi
printf 'builder ALL=(root) NOPASSWD: /usr/bin/pacman\n' > /etc/sudoers.d/kwin-builder
chmod 0440 /etc/sudoers.d/kwin-builder
install -d -o builder -g builder /home/builder/build

# makepkg verifies signatures against the builder's own GPG keyring, not pacman's
# keyring. Set GNUPGHOME explicitly so root's keyring is never consulted.
install -d -m 0700 -o builder -g builder /home/builder/.gnupg
KDE_SIGNING_KEYS=(
  E0A3EB202F8E57528E13E72FD7574483BB57B18D
  0AAC775BB6437A8D9AF7A3ACFE0784117FBCE11D
  D07BD8662C56CB291B316EB2F5675605C74E02CF
  90A968ACA84537CC27B99EAF2C8DF587A6D4AAC1
  1FA881591C26B276D7A5518EEAAF29B42A678C20
)
for key in "${KDE_SIGNING_KEYS[@]}"; do
  if ! runuser -u builder -- env HOME=/home/builder GNUPGHOME=/home/builder/.gnupg gpg --batch --list-keys "$key" >/dev/null 2>&1; then
    runuser -u builder -- env HOME=/home/builder GNUPGHOME=/home/builder/.gnupg gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys "$key" \
      || echo "::warning::Could not retrieve KDE key $key; source verification must still succeed before publishing." >&2
  fi
done

cp -a /input/. /home/builder/build/
chown -R builder:builder /home/builder/build
cd /home/builder/build

sed -i \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e "s/^pkgrel=.*/pkgrel=${pkgrel}/" \
  PKGBUILD

runuser -u builder -- env HOME=/home/builder GNUPGHOME=/home/builder/.gnupg makepkg --verifysource
runuser -u builder -- env HOME=/home/builder GNUPGHOME=/home/builder/.gnupg makepkg --printsrcinfo > "$output/SRCINFO.generated"
runuser -u builder -- env HOME=/home/builder GNUPGHOME=/home/builder/.gnupg makepkg --syncdeps --noconfirm --cleanbuild

shopt -s nullglob
packages=(/home/builder/build/*.pkg.tar.zst)
[[ "${#packages[@]}" -eq 1 ]] || {
  echo "::error::Expected one output package; found ${#packages[@]}." >&2
  exit 1
}
package="${packages[0]}"
cp -v "$package" "$output/"

bsdtar -xOf "$output/$(basename "$package")" .PKGINFO | tee "$output/PKGINFO.txt"
grep -Fqx 'pkgname = kwin-no-tiles' "$output/PKGINFO.txt"
grep -Fqx "pkgver = ${expected_version}" "$output/PKGINFO.txt"
grep -Fqx 'conflict = kwin' "$output/PKGINFO.txt"
grep -Fqx "provides = kwin=${pkgver}" "$output/PKGINFO.txt"

bsdtar -tf "$output/$(basename "$package")" > "$output/package-files.txt"
grep -Fxq 'usr/bin/kwin_wayland' "$output/package-files.txt" || {
  echo '::error::The package does not contain usr/bin/kwin_wayland.' >&2
  exit 1
}
schema_path="$(grep -E '(^|/)kwin\.kcfg$' "$output/package-files.txt" | head -n 1 || true)"
[[ -n "$schema_path" ]] || {
  echo '::error::Could not find the installed KWin configuration schema.' >&2
  exit 1
}
bsdtar -xOf "$output/$(basename "$package")" "$schema_path" > "$output/kwin.kcfg"
grep -Fq 'NativeTilingEnabled' "$output/kwin.kcfg" || {
  echo '::error::NativeTilingEnabled was not found in the packaged KWin schema.' >&2
  exit 1
}

sha256sum "$output/$(basename "$package")" > "$output/SHA256SUMS"
{
  echo "Target package: kwin-no-tiles ${expected_version}"
  echo 'Repository: cachyos-extra-v3'
  echo 'Build environment: cachyos/cachyos:latest'
  echo 'CPU flags: -march=x86-64-v3 -mtune=znver2'
  echo 'Source authentication: makepkg detached-signature verification passed'
  echo 'Patch validation: zero-fuzz patch application required by PKGBUILD'
  echo 'Package name/version/conflict/provides checks: PASS'
  echo 'kwin_wayland executable and NativeTilingEnabled schema checks: PASS'
  echo 'Release published by this script: no'
} > "$output/build-report.txt"

echo 'CachyOS v3 KWin NO-TILES package build and package-content checks: PASS'
