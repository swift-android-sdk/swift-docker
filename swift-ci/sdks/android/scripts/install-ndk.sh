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

NDKURL="https://dl.google.com/android/repository/${NDKFILE}"
echo "Going to fetch ${NDKURL}"

curl -fsSL "${NDKURL}" -o ${NDKFILE}

echo "Extracting NDK"
unzip -q ${NDKFILE}

rm ${NDKFILE}

popd >/dev/null

