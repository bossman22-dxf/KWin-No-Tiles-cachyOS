# Maintainer: bossman22-dxf

pkgname=kwin-no-tiles
pkgver=6.8.1
_dirver=$(echo "$pkgver" | cut -d. -f1-3)
pkgrel=2.1
pkgdesc='KWin with a setting to disable built-in window tiling'
arch=(x86_64)
url='https://kde.org/plasma-desktop/'
license=(LGPL-2.0-or-later)

provides=("kwin=$pkgver")
conflicts=('kwin')

depends=(aurorae
         breeze
         glibc
         iio-sensor-proxy
         plasma-activities
         kauth
         kcmutils
         kcolorscheme
         kconfig
         kcoreaddons
         kcrash
         kdbusaddons
         kdeclarative
         kdecoration
         kglobalaccel
         kglobalacceld
         kguiaddons
         ki18n
         kidletime
         kirigami
         kitemmodels
         knewstuff
         knighttime
         knotifications
         kpackage
         kquickcharts
         kscreenlocker
         kservice
         ksvg
         kwayland
         kwidgetsaddons
         kwindowsystem
         kxmlgui
         lcms2
         libcanberra
         libdisplay-info
         libdrm
         libei
         libepoxy
         libevdev
         libgcc
         libinput
         libpipewire
         libqaccessibilityclient-qt6
         libstdc++
         libxcb
         libxcvt
         libxkbcommon
         mesa
         milou
         pipewire-session-manager
         libplasma
         qt6-5compat
         qt6-base
         qt6-declarative
         qt6-svg
         qt6-tools
         systemd-libs
         vulkan-icd-loader
         wayland
         xcb-util-keysyms
         xcb-util-wm)
makedepends=(extra-cmake-modules
             kdoctools
             krunner
             plasma-wayland-protocols
             python
             vulkan-headers
             wayland-protocols
             xorg-xwayland)
optdepends=('plasma-keyboard: virtual keyboard')
groups=(plasma)

source=("https://download.kde.org/stable/plasma/${_dirver}/kwin-${pkgver}.tar.xz"
        "https://download.kde.org/stable/plasma/${_dirver}/kwin-${pkgver}.tar.xz.sig"
        disable-native-tiling-6.8.patch)

# The KDE tarball is authenticated by its detached signature and the key
# allow-list below. The static release workflow also checks the known SHA-256
# for the baseline KWin 6.8.1 source before building it.
sha256sums=('SKIP'
            'SKIP'
            '6aae75198b0bd8514981bbdce121675b5d50f10638436e8e58980b2e9056171e')

validpgpkeys=('E0A3EB202F8E57528E13E72FD7574483BB57B18D'
              '0AAC775BB6437A8D9AF7A3ACFE0784117FBCE11D'
              'D07BD8662C56CB291B316EB2F5675605C74E02CF'
              '90A968ACA84537CC27B99EAF2C8DF587A6D4AAC1'
              '1FA881591C26B276D7A5518EEAAF29B42A678C20')

prepare() {
  patch --batch --fuzz=0 -d "kwin-${pkgver}" -Np0 \
    -i ../disable-native-tiling-6.8.patch
}

build() {
  cmake -B build -S "kwin-${pkgver}" \
    -DCMAKE_INSTALL_LIBEXECDIR=lib \
    -DBUILD_TESTING=OFF
  cmake --build build
}

package() {
  DESTDIR="$pkgdir" cmake --install build
  setcap CAP_SYS_NICE=+ep "$pkgdir"/usr/bin/kwin_wayland
}
