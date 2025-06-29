#!/bin/bash -ex

patches_dir=$(dirname $(realpath -- "${BASH_SOURCE[0]}"))
cd ${1}

case "${BUILD_SCHEME}" in
    swift-*-branch)
        git apply -v -C1 ${patches_dir}/swift-android.patch
        git apply -v -C1 ${patches_dir}/swift-android-testing-except-release.patch
        ;;
    development)
        git apply -v -C1 ${patches_dir}/swift-android.patch
        git apply -v -C1 ${patches_dir}/swift-android-trunk-libdispatch.patch
        git apply -v -C1 ${patches_dir}/swift-android-testing-except-release.patch
        ;;
    *)
        echo "$0: invalid BUILD_SCHEME=${BUILD_SCHEME}"
        exit 1
        ;;
esac

# disable backtrace() for Android (needs either API33+ or libandroid-execinfo, or to manually add in backtrace backport)
perl -pi -e 's;os\(Android\);os\(AndroidDISABLED\);g' swift-testing/Sources/Testing/SourceAttribution/Backtrace.swift

# need to un-apply libandroid-spawn since we don't need it for API28+
perl -pi -e 's;MATCHES "Android";MATCHES "AndroidDISABLED";g' llbuild/lib/llvm/Support/CMakeLists.txt
perl -pi -e 's; STREQUAL Android\); STREQUAL AndroidDISABLED\);g' swift-corelibs-foundation/Sources/Foundation/CMakeLists.txt


