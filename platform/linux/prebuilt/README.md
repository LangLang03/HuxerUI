# Linux vendored third-party libraries

The Linux backend vendors its graphics/text stack as static libraries so every
checkout builds against the exact same third-party versions. X11/Xext/Xrandr/
xkbcommon remain system dynamic libraries (platform APIs) and Vulkan uses the
vendored headers with the system loader.

## Contents

| Architecture | Location |
|---|---|
| x86_64 | `platform/linux/prebuilt/x86_64/` |
| aarch64 | `platform/linux/prebuilt/aarch64/` |

Each directory contains `include/` and `lib/` (static archives plus the
`pkgconfig` files used when rebuilding).

## Pinned versions

| Library | Version | Source checksum (SHA-256) |
|---|---|---|
| zlib | 1.3.2 | `b99a0b86c0ba9360ec7e78c4f1e43b1cbdf1e6936c8fa0f6835c0cd694a495a1` |
| expat | 2.8.2 | `ef7d1994f533c9e7343d6c19f31064fc8ebbcbcaa144be3812b4f43052a05f4c` |
| libpng | 1.6.58 | `8c9b05b675ca7301a458df2c2e46f26e1d41ff36b8863f8c33530bc58c2e6225` |
| libjpeg-turbo | 3.2.0 | `6f30092cef9fb839779646608f4ee14ae3cbac989c47fa05e841b0841f09878e` |
| pixman | 0.46.4 | `d09c44ebc3bd5bee7021c79f922fe8fb2fb57f7320f55e97ff9914d2346a591c` |
| freetype | 2.14.3 | `e61b31ab26358b946e767ed7eb7f4bb2e507da1cfefeb7a8861ace7fd5c899a1` |
| harfbuzz | 14.3.0 | `16070d77cfc4ba1f1e7327e83bf9b3f55898081cabdb94e56a33e04fc8874eae` |
| fontconfig | 2.18.2 | git commit `a4e25ec391d417e4bca052fbfa5cd7ce5f7fd39e` |
| cairo | 1.18.4 | `445ed8208a6e4823de1226a74ca319d3600e83f6369f99b14265006599c32ccb` |
| Vulkan-Headers | vulkan-sdk-1.4.350.0 | header-only, vendored at `3dparty/vulkan-headers/` |

Optional dependencies are disabled to keep the archives minimal: harfbuzz
without glib/gobject/graphite/icu/cairo, freetype without
brotli/bzip2/png/harfbuzz integration, cairo without X11/xcb/png/zlib/glib
backends, fontconfig with the expat XML backend only.

## Rebuilding

```bash
# x86_64 (native)
scripts/build_linux_prebuilt.sh --arch x86_64

# aarch64 (cross; requires aarch64-linux-gnu toolchain + meson + gperf)
scripts/build_linux_prebuilt.sh --arch aarch64
```

The script downloads pinned sources into `huxerui-prebuilt/`, verifies every
checksum, builds static archives into a staging prefix, and installs them here.
Use `--work-dir DIR` to relocate the scratch space.
