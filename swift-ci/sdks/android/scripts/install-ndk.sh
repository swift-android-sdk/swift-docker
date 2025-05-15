#!/bin/bash
#
# ===----------------------------------------------------------------------===
#
#  Swift Android SDK: Install NDK
#
# ===----------------------------------------------------------------------===

set -e

echo "Installing Android NDK"

mkdir -p /usr/local/ndk
pushd /usr/local/ndk >/dev/null
NDKFILE=${NDK_VERSION}-linux.zip
curl -fsSL "https://dl.google.com/android/repository/${NDKFILE}" -o ${NDKFILE}
unzip -q ${NDKFILE}
rm ${NDKFILE}
popd >/dev/null

