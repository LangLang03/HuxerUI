function(huxerui_platform_configure)
    find_package(PkgConfig REQUIRED)

    # Platform APIs stay system dynamic libraries. The graphics/text stack is
    # vendored as static archives under platform/linux/prebuilt/<arch>.
    pkg_check_modules(HUXERUI_X11 REQUIRED IMPORTED_TARGET x11)
    pkg_check_modules(HUXERUI_XEXT REQUIRED IMPORTED_TARGET xext)
    pkg_check_modules(HUXERUI_XKBCOMMON REQUIRED IMPORTED_TARGET xkbcommon)
    pkg_check_modules(HUXERUI_XRANDR REQUIRED IMPORTED_TARGET xrandr)
    pkg_check_modules(HUXERUI_VULKAN REQUIRED IMPORTED_TARGET vulkan)

    if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
        set(HUXERUI_LINUX_PREBUILT_ARCH aarch64)
    else()
        set(HUXERUI_LINUX_PREBUILT_ARCH x86_64)
    endif()
    set(HUXERUI_LINUX_PREBUILT_DIR "${HUXERUI_PROJECT_DIR}/platform/linux/prebuilt/${HUXERUI_LINUX_PREBUILT_ARCH}")
    if(NOT EXISTS "${HUXERUI_LINUX_PREBUILT_DIR}/lib")
        message(FATAL_ERROR "HuxerUI Linux prebuilt libraries are missing for ${HUXERUI_LINUX_PREBUILT_ARCH}; "
                "run scripts/build_linux_prebuilt.sh")
    endif()

    set(HUXERUI_PLATFORM_SOURCE_FILES
            "${HUXERUI_PROJECT_DIR}/platform/linux/linux_adapter.cpp"
            "${HUXERUI_PROJECT_DIR}/platform/linux/linux_renderer.cpp"
            "${HUXERUI_PROJECT_DIR}/platform/linux/linux_text_input.cpp"
            PARENT_SCOPE
    )
    set(HUXERUI_PLATFORM_INCLUDE_DIRECTORIES
            ${HUXERUI_X11_INCLUDE_DIRS}
            ${HUXERUI_XKBCOMMON_INCLUDE_DIRS}
            ${HUXERUI_XRANDR_INCLUDE_DIRS}
            "${HUXERUI_PROJECT_DIR}/3dparty/vulkan-headers/include"
            "${HUXERUI_LINUX_PREBUILT_DIR}/include"
            "${HUXERUI_LINUX_PREBUILT_DIR}/include/freetype2"
            PARENT_SCOPE
    )

    # Static-link order follows the dependency chain: cairo -> pixman,
    # fontconfig -> freetype -> zlib, harfbuzz -> freetype, libpng -> zlib.
    foreach(lib IN ITEMS cairo fontconfig harfbuzz freetype png16 jpeg expat z pixman-1)
        find_library(HUXERUI_PREBUILT_${lib}
                NAMES ${lib}
                PATHS "${HUXERUI_LINUX_PREBUILT_DIR}/lib"
                NO_DEFAULT_PATH
                REQUIRED)
        list(APPEND HUXERUI_PLATFORM_LINK_LIBRARIES "${HUXERUI_PREBUILT_${lib}}")
    endforeach()
    list(APPEND HUXERUI_PLATFORM_LINK_LIBRARIES m pthread dl)

    set(HUXERUI_PLATFORM_LINK_LIBRARIES
            ${HUXERUI_PLATFORM_LINK_LIBRARIES}
            PkgConfig::HUXERUI_X11
            PkgConfig::HUXERUI_XEXT
            PkgConfig::HUXERUI_XKBCOMMON
            PkgConfig::HUXERUI_XRANDR
            PkgConfig::HUXERUI_VULKAN
            PARENT_SCOPE
    )
endfunction()
