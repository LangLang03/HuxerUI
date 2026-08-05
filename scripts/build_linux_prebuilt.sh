#!/usr/bin/env bash
# Builds the vendored static libraries for the HuxerUI Linux backend.
#
# The Linux backend vendors its graphics/text stack (cairo, pixman, freetype,
# harfbuzz, fontconfig, expat, zlib, libpng, libjpeg-turbo) as static libraries
# so that every checkout builds against the exact same third-party versions.
# X11/Xext/Xrandr/xkbcommon remain system dynamic libraries (platform APIs),
# and Vulkan uses vendored headers with the system loader.
#
# Usage:
#   scripts/build_linux_prebuilt.sh [--arch x86_64|aarch64|all] [--work-dir DIR]
#
# Each library version is pinned below with its source checksum. The script
# downloads to the work directory (default: ./huxerui-prebuilt), builds static
# libraries with optional dependencies disabled, and installs headers and
# archives into platform/linux/prebuilt/<arch>/. Re-running is idempotent.
#
# aarch64 builds require an aarch64 cross toolchain:
#   sudo pacman -S aarch64-linux-gnu-gcc aarch64-linux-gnu-glibc \
#       aarch64-linux-gnu-linux-api-headers meson gperf

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT}/platform/linux/prebuilt"

ARCH_LIST=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)
      shift
      if [[ "${1:-}" == "all" ]]; then
        ARCH_LIST=(x86_64 aarch64)
      else
        ARCH_LIST=("${1:-}")
      fi
      ;;
    --work-dir)
      shift
      WORK_DIR="${1:-}"
      ;;
    *)
      ARCH_LIST+=("$1")
      ;;
  esac
  shift
done
if [[ ${#ARCH_LIST[@]} -eq 0 ]]; then
  ARCH_LIST=(x86_64 aarch64)
fi

if [[ -z "${WORK_DIR:-}" ]]; then
  WORK_DIR="${HUXERUI_PREBUILT_WORK:-${TMPDIR:-/tmp}/huxerui-prebuilt}"
fi
mkdir -p "${WORK_DIR}/src" "${WORK_DIR}/logs"

fetch() {
  # fetch <archive> <url> <sha256>
  local archive="$1" url="$2" expected="$3"
  local dest="${WORK_DIR}/src/${archive}"
  if [[ -f "${dest}" ]]; then
    local actual
    actual="$(sha256sum "${dest}" | cut -d' ' -f1)"
    if [[ "${actual}" == "${expected}" ]]; then
      return
    fi
  fi
  curl -L --fail --silent --show-error -o "${dest}" "${url}"
  local actual
  actual="$(sha256sum "${dest}" | cut -d' ' -f1)"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "checksum mismatch for ${archive}: expected ${expected}, got ${actual}" >&2
    exit 1
  fi
}

extract() {
  # extract <archive> <dir>
  local archive="${WORK_DIR}/src/$1" dir="$2"
  if [[ ! -d "${dir}" ]]; then
    mkdir -p "${dir}"
    tar -x -C "${dir}" --strip-components=1 -f "${archive}"
  fi
}

# Version pins. Checksums cover the exact tarballs below; fontconfig is
# fetched by git commit because its release tarballs are not reliably
# reachable from this environment.
ZLIB_SHA256="b99a0b86c0ba9360ec7e78c4f1e43b1cbdf1e6936c8fa0f6835c0cd694a495a1"
EXPAT_SHA256="ef7d1994f533c9e7343d6c19f31064fc8ebbcbcaa144be3812b4f43052a05f4c"
LIBPNG_SHA256="8c9b05b675ca7301a458df2c2e46f26e1d41ff36b8863f8c33530bc58c2e6225"
JPEG_SHA256="6f30092cef9fb839779646608f4ee14ae3cbac989c47fa05e841b0841f09878e"
PIXMAN_SHA256="d09c44ebc3bd5bee7021c79f922fe8fb2fb57f7320f55e97ff9914d2346a591c"
FREETYPE_SHA256="e61b31ab26358b946e767ed7eb7f4bb2e507da1cfefeb7a8861ace7fd5c899a1"
HARFBUZZ_SHA256="16070d77cfc4ba1f1e7327e83bf9b3f55898081cabdb94e56a33e04fc8874eae"
CAIRO_SHA256="445ed8208a6e4823de1226a74ca319d3600e83f6369f99b14265006599c32ccb"
FONTCONFIG_COMMIT="a4e25ec391d417e4bca052fbfa5cd7ce5f7fd39e"

build_zlib() {
  local arch="$1" src="$2" build="$3" stage="$4"
  rm -rf "${build}"
  cmake -S "${src}" -B "${build}" \
      -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
      -DZLIB_BUILD_EXAMPLES=OFF -DCMAKE_INSTALL_PREFIX="${stage}" -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
      ${CMAKE_CROSS_FLAGS:-} >/dev/null
  cmake --build "${build}" -j"$(nproc)" >/dev/null
  cmake --install "${build}" >/dev/null
}

build_expat() {
  local arch="$1" src="$2" build="$3" stage="$4"
  rm -rf "${build}"
  cmake -S "${src}" -B "${build}" \
      -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
      -DEXPAT_BUILD_TOOLS=OFF -DEXPAT_BUILD_EXAMPLES=OFF \
      -DEXPAT_BUILD_TESTS=OFF -DEXPAT_BUILD_DOCS=OFF \
      -DCMAKE_INSTALL_PREFIX="${stage}" -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_POSITION_INDEPENDENT_CODE=ON ${CMAKE_CROSS_FLAGS:-} >/dev/null
  cmake --build "${build}" -j"$(nproc)" >/dev/null
  cmake --install "${build}" >/dev/null
}

build_libpng() {
  local arch="$1" src="$2" build="$3" stage="$4"
  rm -rf "${build}"
  cmake -S "${src}" -B "${build}" \
      -DCMAKE_BUILD_TYPE=Release -DPNG_SHARED=OFF -DPNG_STATIC=ON \
      -DPNG_TESTS=OFF -DPNG_TOOLS=OFF \
      -DCMAKE_PREFIX_PATH="${stage}" -DZLIB_ROOT="${stage}" \
      -DCMAKE_INSTALL_PREFIX="${stage}" -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_POSITION_INDEPENDENT_CODE=ON ${CMAKE_CROSS_FLAGS:-} >/dev/null
  cmake --build "${build}" -j"$(nproc)" >/dev/null
  cmake --install "${build}" >/dev/null
}

build_libjpeg() {
  local arch="$1" src="$2" build="$3" stage="$4"
  rm -rf "${build}"
  local simd=OFF
  if [[ "${arch}" == "x86_64" ]]; then
    simd=ON
  fi
  cmake -S "${src}" -B "${build}" \
      -DCMAKE_BUILD_TYPE=Release -DENABLE_SHARED=OFF -DENABLE_STATIC=ON \
      -DWITH_TURBOJPEG=OFF -DWITH_TOOLS=OFF -DWITH_TESTS=OFF -DWITH_DOCS=OFF \
      -DWITH_SIMD="${simd}" \
      -DCMAKE_INSTALL_PREFIX="${stage}" -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_POSITION_INDEPENDENT_CODE=ON ${CMAKE_CROSS_FLAGS:-} >/dev/null
  cmake --build "${build}" -j"$(nproc)" >/dev/null
  cmake --install "${build}" >/dev/null
}

build_pixman() {
  local arch="$1" src="$2" build="$3" stage="$4"
  rm -rf "${build}"
  meson setup "${build}" "${src}" \
      --buildtype=release --default-library=static \
      -Dtests=disabled -Ddemos=disabled -Dgtk=disabled -Dopenmp=disabled \
      -Dprefix="${stage}" -Dlibdir=lib -Db_staticpic=true ${MESON_CROSS_ARGS:-} >/dev/null
  meson compile -C "${build}" >/dev/null
  meson install -C "${build}" >/dev/null
}

build_freetype() {
  local arch="$1" src="$2" build="$3" stage="$4"
  rm -rf "${build}"
  cmake -S "${src}" -B "${build}" \
      -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
      -DFT_DISABLE_BROTLI=TRUE -DFT_DISABLE_BZIP2=TRUE \
      -DFT_DISABLE_PNG=TRUE -DFT_DISABLE_HARFBUZZ=TRUE \
      -DCMAKE_PREFIX_PATH="${stage}" \
      -DCMAKE_INSTALL_PREFIX="${stage}" -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_POSITION_INDEPENDENT_CODE=ON ${CMAKE_CROSS_FLAGS:-} >/dev/null
  cmake --build "${build}" -j"$(nproc)" >/dev/null
  cmake --install "${build}" >/dev/null
}

build_harfbuzz() {
  local arch="$1" src="$2" build="$3" stage="$4"
  rm -rf "${build}"
  meson setup "${build}" "${src}" \
      --buildtype=release --default-library=static \
      -Dglib=disabled -Dgobject=disabled -Dgraphite=disabled \
      -Dicu=disabled -Dcairo=disabled -Dfreetype=enabled \
      -Dtests=disabled -Dintrospection=disabled -Ddocs=disabled \
      -Dutilities=disabled -Dbenchmark=disabled \
      -Dprefix="${stage}" -Dlibdir=lib -Db_staticpic=true ${MESON_CROSS_ARGS:-} >/dev/null
  meson compile -C "${build}" >/dev/null
  meson install -C "${build}" >/dev/null
}

build_fontconfig() {
  local arch="$1" src="$2" build="$3" stage="$4"
  rm -rf "${build}"
  meson setup "${build}" "${src}" \
      --buildtype=release --default-library=static \
      -Ddoc=disabled -Dtools=disabled -Dtests=disabled \
      -Dxml-backend=expat \
      -Dprefix="${stage}" -Dlibdir=lib -Db_staticpic=true ${MESON_CROSS_ARGS:-} >/dev/null
  meson compile -C "${build}" >/dev/null
  meson install -C "${build}" >/dev/null
}

build_cairo() {
  local arch="$1" src="$2" build="$3" stage="$4"
  rm -rf "${build}"
  meson setup "${build}" "${src}" \
      --buildtype=release --default-library=static \
      -Dtests=disabled -Dpng=disabled -Dzlib=disabled -Dglib=disabled \
      -Dxlib=disabled -Dxcb=disabled -Dquartz=disabled \
      -Dfontconfig=enabled -Dfreetype=enabled \
      -Ddwrite=disabled \
      -Dprefix="${stage}" -Dlibdir=lib -Db_staticpic=true ${MESON_CROSS_ARGS:-} >/dev/null
  meson compile -C "${build}" >/dev/null
  meson install -C "${build}" >/dev/null
}

fetch_fontconfig_source() {
  local dir="${WORK_DIR}/src/fontconfig-2.18.2"
  if [[ ! -d "${dir}/.git" ]]; then
    git clone --quiet --depth 1 \
        https://gitlab.freedesktop.org/fontconfig/fontconfig.git "${dir}"
    git -C "${dir}" fetch --quiet --depth 1 origin "${FONTCONFIG_COMMIT}"
    git -C "${dir}" checkout --quiet "${FONTCONFIG_COMMIT}"
  fi
  local actual
  actual="$(git -C "${dir}" rev-parse HEAD)"
  if [[ "${actual}" != "${FONTCONFIG_COMMIT}" ]]; then
    echo "fontconfig commit mismatch: expected ${FONTCONFIG_COMMIT}, got ${actual}" >&2
    exit 1
  fi
}

build_arch() {
  local arch="$1"
  local stage="${WORK_DIR}/stage-${arch}"
  local build_root="${WORK_DIR}/build-${arch}"
  mkdir -p "${stage}" "${build_root}"

  export CMAKE_CROSS_FLAGS=""
  export MESON_CROSS_ARGS=""
  local meson_cross_file="${WORK_DIR}/meson-cross-${arch}.ini"
  if [[ "${arch}" == "aarch64" ]]; then
    if ! command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
      echo "aarch64 cross toolchain missing; install aarch64-linux-gnu-gcc" >&2
      exit 1
    fi
    export CMAKE_CROSS_FLAGS="-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
        -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
        -DCMAKE_AR=$(command -v aarch64-linux-gnu-ar) -DCMAKE_RANLIB=$(command -v aarch64-linux-gnu-ranlib) \
        -DCMAKE_FIND_ROOT_PATH=${stage} \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
        -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY"
    cat > "${meson_cross_file}" <<EOF
[binaries]
c = 'aarch64-linux-gnu-gcc'
cpp = 'aarch64-linux-gnu-g++'
ar = 'aarch64-linux-gnu-ar'
strip = 'aarch64-linux-gnu-strip'
pkgconfig = 'pkg-config'

[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
EOF
    export MESON_CROSS_ARGS="--cross-file=${meson_cross_file}"
  fi

  # pkg-config must resolve staged dependencies only, never the host system.
  export PKG_CONFIG_LIBDIR="${stage}/lib/pkgconfig"
  export PKG_CONFIG_PATH=""

  local log="${WORK_DIR}/logs/${arch}.log"
  exec > >(tee "${log}") 2>&1

  echo "=== building ${arch} third-party libraries ==="

  fetch "zlib-1.3.2.tar.gz" \
      "https://github.com/madler/zlib/archive/refs/tags/v1.3.2.tar.gz" \
      "${ZLIB_SHA256}"
  extract "zlib-1.3.2.tar.gz" "${WORK_DIR}/zlib-src-${arch}"
  build_zlib "${arch}" "${WORK_DIR}/zlib-src-${arch}" "${build_root}/zlib" "${stage}"

  fetch "expat-2.8.2.tar.gz" \
      "https://github.com/libexpat/libexpat/releases/download/R_2_8_2/expat-2.8.2.tar.gz" \
      "${EXPAT_SHA256}"
  extract "expat-2.8.2.tar.gz" "${WORK_DIR}/expat-src-${arch}"
  build_expat "${arch}" "${WORK_DIR}/expat-src-${arch}" "${build_root}/expat" "${stage}"

  fetch "libpng-1.6.58.tar.gz" \
      "https://download.sourceforge.net/libpng/libpng-1.6.58.tar.gz" \
      "${LIBPNG_SHA256}"
  extract "libpng-1.6.58.tar.gz" "${WORK_DIR}/libpng-src-${arch}"
  build_libpng "${arch}" "${WORK_DIR}/libpng-src-${arch}" "${build_root}/libpng" "${stage}"

  fetch "libjpeg-turbo-3.2.0.tar.gz" \
      "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.2.0/libjpeg-turbo-3.2.0.tar.gz" \
      "${JPEG_SHA256}"
  extract "libjpeg-turbo-3.2.0.tar.gz" "${WORK_DIR}/libjpeg-src-${arch}"
  build_libjpeg "${arch}" "${WORK_DIR}/libjpeg-src-${arch}" "${build_root}/libjpeg" "${stage}"

  fetch "pixman-0.46.4.tar.gz" \
      "https://www.cairographics.org/releases/pixman-0.46.4.tar.gz" \
      "${PIXMAN_SHA256}"
  extract "pixman-0.46.4.tar.gz" "${WORK_DIR}/pixman-src-${arch}"
  build_pixman "${arch}" "${WORK_DIR}/pixman-src-${arch}" "${build_root}/pixman" "${stage}"

  fetch "freetype-2.14.3.tar.gz" \
      "https://download.savannah.gnu.org/releases/freetype/freetype-2.14.3.tar.gz" \
      "${FREETYPE_SHA256}"
  extract "freetype-2.14.3.tar.gz" "${WORK_DIR}/freetype-src-${arch}"
  build_freetype "${arch}" "${WORK_DIR}/freetype-src-${arch}" "${build_root}/freetype" "${stage}"

  fetch "harfbuzz-14.3.0.tar.xz" \
      "https://github.com/harfbuzz/harfbuzz/releases/download/14.3.0/harfbuzz-14.3.0.tar.xz" \
      "${HARFBUZZ_SHA256}"
  extract "harfbuzz-14.3.0.tar.xz" "${WORK_DIR}/harfbuzz-src-${arch}"
  build_harfbuzz "${arch}" "${WORK_DIR}/harfbuzz-src-${arch}" "${build_root}/harfbuzz" "${stage}"

  fetch_fontconfig_source
  build_fontconfig "${arch}" "${WORK_DIR}/src/fontconfig-2.18.2" \
      "${build_root}/fontconfig" "${stage}"

  fetch "cairo-1.18.4.tar.xz" \
      "https://www.cairographics.org/releases/cairo-1.18.4.tar.xz" \
      "${CAIRO_SHA256}"
  extract "cairo-1.18.4.tar.xz" "${WORK_DIR}/cairo-src-${arch}"
  build_cairo "${arch}" "${WORK_DIR}/cairo-src-${arch}" "${build_root}/cairo" "${stage}"

  # Install into the repository. Keep only archives, headers, and pc files.
  local dest="${OUT_DIR}/${arch}"
  rm -rf "${dest}"
  mkdir -p "${dest}/lib" "${dest}/include"
  cp -a "${stage}/include/." "${dest}/include/"
  find "${stage}" -name '*.a' -exec cp {} "${dest}/lib/" \;
  mkdir -p "${dest}/lib/pkgconfig"
  cp -a "${stage}/lib/pkgconfig/." "${dest}/lib/pkgconfig/"
  # pc files embed the ephemeral stage prefix; point them at the repository path.
  sed -i "s|${stage}|${dest}|g" "${dest}"/lib/pkgconfig/*.pc
  echo "installed ${dest}"
}

for arch in "${ARCH_LIST[@]}"; do
  case "${arch}" in
    x86_64|aarch64) ;;
    *)
      echo "unknown arch: ${arch} (expected x86_64 or aarch64)" >&2
      exit 1
      ;;
  esac
  build_arch "${arch}"
done

echo "done"
