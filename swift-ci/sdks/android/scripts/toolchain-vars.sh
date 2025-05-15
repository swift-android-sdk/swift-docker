#!/bin/bash -e

case "${BUILD_VERSION}" in
    release)
        LATEST_TOOLCHAIN_VERSION=$(curl -sL https://github.com/apple/swift/releases | grep -m1 swift-6.1 | cut -d- -f2)
        SWIFT_TAG="swift-${LATEST_TOOLCHAIN_VERSION}-RELEASE"
        SWIFT_BRANCH="swift-$(echo $SWIFT_TAG | cut -d- -f2)-release"
        ;;
    devel)
        LATEST_TOOLCHAIN_VERSION=$(curl -sL https://github.com/apple/swift/tags | grep -m1 swift-6.2-DEV | cut -d- -f8-10)
        SWIFT_TAG="swift-6.2-DEVELOPMENT-SNAPSHOT-${LATEST_TOOLCHAIN_VERSION}-a"
        SWIFT_BRANCH="swift-$(echo $SWIFT_TAG | cut -d- -f2)-branch"
        ;;
    trunk)
        LATEST_TOOLCHAIN_VERSION=$(curl -sL https://github.com/apple/swift/tags | grep -m1 swift-DEV | cut -d- -f7-9)
        SWIFT_TAG="swift-DEVELOPMENT-SNAPSHOT-${LATEST_TOOLCHAIN_VERSION}-a"
        SWIFT_BRANCH="development"
        ;;
    *)
        echo "$0: invalid BUILD_VERSION=${BUILD_VERSION}"
        exit 1
        ;;
esac

SWIFT_BASE=$SWIFT_TAG-$HOST_OS
SWIFT_TOOLCHAIN_URL="https://download.swift.org/$SWIFT_BRANCH/$(echo $HOST_OS | tr -d '.')/$SWIFT_TAG/$SWIFT_BASE.tar.gz"

