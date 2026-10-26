# KWin NO-TILES for CachyOS

KWin NO-TILES adds a setting to disable KWin's built-in native tiling while leaving the rest of KWin intact. It is intended for people who use an external tiling manager such as [PlasmaZones](https://github.com/fuddlesworth/PlasmaZones).
THIS PACKAGE IS A REPLACEMENT FOR NATIVE KWIN AND WILL UNINSTALL IT WHEN YOU INSTALL VIA PACMAN! THIS IS EXPECTED BEHAVIOR!

Install instructions can be found [Here](https://bossman22-dxf.github.io/KWin-No-Tiles-cachyOS/)

## Current scope

- KWin source: KDE's stable KWin tarball, authenticated by its detached release signature.
- Package source: the live CachyOS `cachyos-extra-v3` repository.
- CPU target: x86-64-v3, tuned for Zen 2 (`-march=x86-64-v3 -mtune=znver2`).
- Package name: `kwin-no-tiles`.
- KWin config key: `[Windows] NativeTilingEnabled=false`.
- Patch: `disable-native-tiling-6.8.patch`.

The baseline target is KWin `6.8.1-2.1`. An earlier manual CI workflow successfully compiled this baseline and verified package metadata. This clean-import pipeline adds upstream detached-signature verification, dynamic repository-version detection, package-content checks and gated release automation. **The new clean-import pipeline itself has not yet completed its first end-to-end run.** A release must not be treated as validated until that pipeline reports success.

## What the patch changes

The patch adds a KWin config option and a checkbox for enabling or disabling built-in window tiling. When disabled, it blocks KWin's native tiling entry points and releases existing native tile assignments, so an external tiler can manage window placement.

The setting is intended to leave ordinary window snapping separate. It does not force-change KDE's unrelated snapping settings.

## Automated build and release policy

`.github/workflows/auto-release-cachyos-v3.yml` runs every six hours or by manual dispatch. It deliberately has **no push trigger**, so editing or importing repository files cannot accidentally start a long package build.

For each run it:

1. Queries the live KWin package version in CachyOS's v3 repository.
2. Skips versions that already have a complete successful release, and skips if the configured mirror reports a version older than the newest successful v3 release.
3. Authenticates the official KDE source tarball with its detached signature and the allowed KDE signing-key fingerprints.
4. Requires the patch to apply with zero fuzz.
5. Builds inside a CachyOS container, targeting x86-64-v3/Zen 2 rather than the GitHub runner CPU.
6. Checks the built package name, version, `provides`/`conflicts` metadata, `kwin_wayland` binary, and the `NativeTilingEnabled` schema entry.
7. Creates a versioned GitHub Release only after every previous check succeeds.

The workflow never reuses a complete successful release tag. If source authentication, patch application, dependency resolution, compilation, or package-content checks fail, it publishes no package. Once a new release is successfully published, the workflow attempts to retain only the two most recent successful releases.

The separate `.github/workflows/build-cachyos-kwin-6.8.1.yml` workflow is a manual-only baseline build that uploads a test artifact but does not publish a Release. The manual preflight workflow is also opt-in. None of these workflows is configured to run on `push`.

## Package and repository signing

Every successful automated GitHub Release now includes:

- The verified package and its detached GPG signature (`.pkg.tar.zst.sig`).
- The signing public key (`kwin-no-tiles-signing-key.asc`) and full fingerprint (`GPG_FINGERPRINT.txt`).
- `SHA256SUMS`, covering both the package and its signature with relative filenames so it can be checked after downloading.
- The build report, updated to record the signature verification result.

The private signing key and passphrase remain in GitHub Actions secrets. The existing build checks still run first; signing is a required step before a release can be created. A release is considered complete only when its package signature and public-key information are present.

The separate `.github/workflows/publishing.yml` workflow runs after a successful release workflow (or by manual dispatch). It downloads the newest one or two release packages, verifies their detached signatures with the project key, builds a pacman database with `repo-add`, signs the database, verifies that signature, and deploys the repository to GitHub Pages. It does not re-sign release packages. The Pages repository keeps its own copy of the last two package versions.

### Configure the pacman repository

After the first successful release and Pages deployment, the repository will be available at:

`https://bossman22-dxf.github.io/KWin-No-Tiles-cachyOS/x86_64`

Before trusting the key, verify its **full fingerprint through a maintainer-published source you already trust**. Do not rely solely on a fingerprint downloaded beside the key from the same website.

Download and inspect the public key:

```bash
curl -fsSLo /tmp/kwin-no-tiles-signing-key.asc \
  https://bossman22-dxf.github.io/KWin-No-Tiles-cachyOS/keys/kwin-no-tiles-signing-key.asc
gpg --show-keys --with-fingerprint /tmp/kwin-no-tiles-signing-key.asc
```

After verifying the full fingerprint, add and locally trust the key:

```bash
sudo pacman-key --add /tmp/kwin-no-tiles-signing-key.asc
sudo pacman-key --lsign-key YOUR_FULL_GPG_FINGERPRINT
```

Replace `YOUR_FULL_GPG_FINGERPRINT` with the verified fingerprint, without angle brackets. Then add this repository section to `/etc/pacman.conf`:

```ini
[kwin-no-tiles]
SigLevel = Required
Server = https://bossman22-dxf.github.io/KWin-No-Tiles-cachyOS/$arch
```

Synchronise and install:

```bash
sudo pacman -Syu
sudo pacman -S kwin-no-tiles
```

**Important:** this package intentionally conflicts with and replaces the stock `kwin` package. Keep a rollback copy of the previous working package. The automated build checks do not replace live runtime testing on a CachyOS Plasma session.

## Safe maintenance rules

- Do not install a package only because compilation succeeded. Runtime testing on a live CachyOS Plasma session remains a separate step.
- If the patch no longer applies cleanly to a newer KWin version, stop and update/review the patch rather than allowing fuzz.
- If KDE changes its release-signing keys, review the official key fingerprints before updating `validpgpkeys` in `PKGBUILD`.
- If build dependencies or runtime dependencies change, update the recipe and `.SRCINFO` after review. A successful source build is not permission to ignore package metadata changes.
- Keep the stock KWin package cache available until the patched package has been runtime-tested and a recovery route has been confirmed.

## Files

- `PKGBUILD`: CachyOS-compatible package recipe.
- `.SRCINFO`: package metadata generated from the recipe.
- `disable-native-tiling-6.8.patch`: patch for KWin 6.8.x source, reviewed against 6.8.1.
- `.github/scripts/query-cachyos-v3.sh`: live v3 repository query.
- `.github/scripts/build-cachyos-v3.sh`: version-parameterized build and package-content verification.
- `.github/workflows/auto-release-cachyos-v3.yml`: scheduled new-version check/build/release workflow.
- `.github/workflows/build-cachyos-kwin-6.8.1.yml`: manual baseline build, no release.
- `.github/workflows/preflight-kwin-6.8.1.yml`: manual source/patch/repository preflight.

## License

The package recipe derives from the Arch KWin packaging recipe, so the included packaging license/attribution file is retained. The patch and automation should be reviewed independently when distributing the package.
