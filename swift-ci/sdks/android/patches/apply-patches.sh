#!/bin/bash -ex

patches_dir=$(dirname $(realpath -- "${BASH_SOURCE[0]}"))
cd ${1}
git apply -v -C1 ${patches_dir}/swift-android.patch

if [[ "${BUILD_SCHEME}" == "swift-6.2-branch" ]]; then
    git apply -v -C1 ${patches_dir}/swift-android-devel.patch
else
    # This `git grep` invocation in a trunk test fails in our Docker for some
    # reason, so just turn it into a plain `grep` again.
    perl -pi -e 's:"git",:#:' swift/test/Misc/verify-swift-feature-testing.test-sh
fi

# disable backtrace() for Android (needs either API33+ or libandroid-execinfo, or to manually add in backtrace backport)
perl -pi -e 's;os\(Android\);os\(AndroidDISABLED\);g' swift-testing/Sources/Testing/SourceAttribution/Backtrace.swift
