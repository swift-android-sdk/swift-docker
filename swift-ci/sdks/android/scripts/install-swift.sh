#!/bin/bash
#
# ===----------------------------------------------------------------------===
#
#  Swift Android SDK: Install Swift
#
# ===----------------------------------------------------------------------===

set -e

if [[ "${SWIFT_TOOLCHAIN_URL}" == "" ]]; then
    echo "$0: Missing SWIFT_TOOLCHAIN_URL environment"
    exit 1
fi

echo "Installing Swift from: ${SWIFT_TOOLCHAIN_URL}"

# Make a temporary directory
tmpdir=$(mktemp -d)
function cleanup {
    rm -rf "$tmpdir"
}
trap cleanup EXIT

pushd "$tmpdir" >/dev/null
export GNUPGHOME="$tmpdir"

# Fetch the toolchain and signature
echo "Going to fetch ${SWIFT_TOOLCHAIN_URL}"

curl -fsSL "${SWIFT_TOOLCHAIN_URL}" -o toolchain.tar.gz

echo "Going to fetch ${SWIFT_TOOLCHAIN_URL}.sig"

curl -fsSL "${SWIFT_TOOLCHAIN_URL}.sig" -o toolchain.sig

echo "Fetching keys"

curl -fsSL --compressed https://swift.org/keys/all-keys.asc | gpg --import -

echo "Verifying signature"

gpg --batch --verify toolchain.sig toolchain.tar.gz

# Extract and install the toolchain
echo "Extracting Swift"

mkdir -p /usr/local/swift
tar -xzf toolchain.tar.gz --directory /usr/local/swift --strip-components=2
chmod -R o+r /usr/local/swift/lib/swift

popd >/dev/null

