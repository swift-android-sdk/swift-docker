#!/bin/bash -ex

patches_dir=$(dirname $(realpath -- "${BASH_SOURCE[0]}"))
cd ${1}

# https://github.com/swiftlang/swift/pull/81596
git apply -v -C1 ${patches_dir}/page-size-16KB-81398-AddSwiftStdlib.patch
git apply -v -C1 ${patches_dir}/page-size-16KB-81398-targets.patch

case "${BUILD_SCHEME}" in
    swift-*-branch)
        git apply -v -C1 ${patches_dir}/swift-android.patch
        git apply -v -C1 ${patches_dir}/swift-android-devel.patch
        ;;
    development)
        git apply -v -C1 ${patches_dir}/swift-android.patch
        git apply -v -C1 ${patches_dir}/swift-android-trunk.patch
        ;;
    *)
        echo "$0: invalid BUILD_SCHEME=${BUILD_SCHEME}"
        exit 1
        ;;
esac

# disable backtrace() for Android (needs either API33+ or libandroid-execinfo, or to manually add in backtrace backport)
perl -pi -e 's;os\(Android\);os\(AndroidDISABLED\);g' swift-testing/Sources/Testing/SourceAttribution/Backtrace.swift

