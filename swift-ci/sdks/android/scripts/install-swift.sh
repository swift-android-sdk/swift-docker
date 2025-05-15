#!/bin/bash
#
# ===----------------------------------------------------------------------===
#
#  Swift Android SDK: Install Swift
#
# ===----------------------------------------------------------------------===

set -e

echo "Installing Swift"

# Get latest toolchain info
latest_build=$(curl -s ${SWIFT_WEBROOT}/latest-build.yml)
download=$(echo "$latest_build" | grep '^download: ' | sed 's/^download: //g')
download_signature=$(echo "$latest_build " | grep '^download_signature: ' | sed 's/^download_signature: //g')
download_dir=$(echo "$latest_build" | grep '^dir: ' | sed 's/^dir: //g')

echo "Latest build is ${download_dir}"

# Make a temporary directory
tmpdir=$(mktemp -d)
function cleanup {
    rm -rf "$tmpdir"
}
trap cleanup EXIT

pushd "$tmpdir" >/dev/null
export GNUPGHOME="$tmpdir"

# Fetch the toolchain and signature
echo "Going to fetch ${SWIFT_WEBROOT}/${download_dir}/${download}"

curl -fsSL "${SWIFT_WEBROOT}/${download_dir}/${download}" -o toolchain.tar.gz

echo "Going to fetch ${SWIFT_WEBROOT}/${download_dir}/${download_signature}"

curl -fsSL "${SWIFT_WEBROOT}/${download_dir}/${download_signature}" -o toolchain.sig

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

