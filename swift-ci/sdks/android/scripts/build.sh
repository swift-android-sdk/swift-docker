#!/bin/bash
# Swift SDK for Android: Build Script
set -ex

# Docker sets TERM to xterm if using a pty; we probably want
# xterm-256color, otherwise we only get eight colors
if [ -t 1 ]; then
    if [[ "$TERM" == "xterm" ]]; then
        export TERM=xterm-256color
    fi
fi

if [[ -n "$TERM" ]]; then
  bold=""
  white=""
  grey=""
  reset=""
else
  bold=$(tput bold)
  white=$(tput setaf 15)
  grey=$(tput setaf 8)
  reset=$(tput sgr0)
fi

function cleanup {
    echo "${reset}"
}
trap cleanup EXIT

function header {
    local text="$1"
    echo ""
    echo "${white}${bold}*** ${text} ***${reset}${grey}"
    echo ""
}

function usage {
    cat <<EOF
usage: build.sh --source-dir <path> --products-dir <path> --ndk-home <path> --host-toolchain <path>
                [--name <sdk-name>] [--version <version>] [--build-dir <path>]
                [--archs <arch>[,<arch> ...]]

Build the Swift Android SDK.

Options:

  --name <sdk-name>     Specify the name of the SDK bundle.
  --version <version>   Specify the version of the Android SDK.
  --source-dir <path>   Specify the path in which the sources can be found.
  --ndk-home <path>     Specify the path to the Android NDK
  --host-toolchain <tc> Specify the path to the host Swift toolchain
  --products-dir <path> Specify the path in which the products should be written.
  --build-dir <path>    Specify the path in which intermediates should be stored.
  --android-api <api>   Specify the Android API level
                        (Default is ${android_api}).
  --archs <arch>[,<arch> ...]
                        Specify the architectures for which we should build
                        the SDK.
                        (Default is ${archs}).
  --build <type>        Specify the CMake build type to use (Release, Debug,
                        RelWithDebInfo).
                        (Default is ${build_type}).
  -j <count>
  --jobs <count>        Specify the number of parallel jobs to run at a time.
                        (Default is ${parallel_jobs}.)
EOF
}

# Declare all the packages we depend on
declare -a packages

function declare_package
{
    local name=$1
    local userVisibleName=$2
    local license=$3
    local url=$4

    local snake=$(echo ${name} | tr '_' '-')

    declare -g ${name}_snake="$snake"
    declare -g ${name}_name="$userVisibleName"
    declare -g ${name}_license="$license"
    declare -g ${name}_url="$url"

    packages+=(${name})
}

declare_package android_sdk \
                "Swift SDK for Android" \
                "Apache-2.0" "https://swift.org/install"
declare_package swift "swift" "Apache-2.0" "https://swift.org"
declare_package libxml2 "libxml2" "MIT" \
                "https://github.com/GNOME/libxml2"
declare_package curl "curl" "MIT" "https://curl.se"
declare_package boringssl "boringssl" "OpenSSL AND ISC AND MIT" \
                "https://boringssl.googlesource.com/boringssl/"
declare_package zlib "zlib" "Zlib" "https://zlib.net"

# Parse command line arguments
android_sdk_version=0.1
sdk_name=
archs=aarch64,armv7,x86_64
android_api=28
build_type=Release
parallel_jobs=$(($(nproc --all) + 2))
source_dir=
ndk_home=${ANDROID_NDK}
build_dir=$(pwd)/build
products_dir=

while [ "$#" -gt 0 ]; do
    case "$1" in
        --source-dir)
            source_dir="$2"; shift ;;
        --ndk-home)
            ndk_home="$2"; shift ;;
        --host-toolchain)
            host_toolchain="$2"; shift ;;
        --build-dir)
            build_dir="$2"; shift ;;
        --android-api)
            android_api="$2"; shift ;;
        --products-dir)
            products_dir="$2"; shift ;;
        --name)
            sdk_name="$2"; shift ;;
        --archs)
            archs="$2"; shift ;;
        --version)
            android_sdk_version="$2"; shift ;;
        -j|--jobs)
            parallel_jobs=$2; shift ;;
        *)
            echo "Unknown argument '$1'"; usage; exit 0 ;;
    esac
    shift
done

# Change the commas for spaces
archs="${archs//,/ }"

if [[ -z "$source_dir" || -z "$products_dir" || -z "$ndk_home" || -z "$host_toolchain" ]]; then
    usage
    exit 1
fi

if ! swiftc=$(which swiftc); then
    echo "build.sh: Unable to find Swift compiler.  You must have a Swift toolchain installed to build the Android SDK."
    exit 1
fi

script_dir=$(dirname -- "${BASH_SOURCE[0]}")
resource_dir="${script_dir}/../resources"

# Find the version numbers of the various dependencies
function describe {
    pushd $1 >/dev/null 2>&1
    git describe --tags
    popd >/dev/null 2>&1
}
function versionFromTag {
    desc=$(describe $1)
    if [[ $desc == v* ]]; then
        echo "${desc#v}"
    else
        echo "${desc}"
    fi
}

swift_version=$(describe ${source_dir}/swift-project/swift)
if [[ $swift_version == swift-* ]]; then
    swift_version=${swift_version#swift-}
fi

if [[ -z "$sdk_name" ]]; then
    sdk_name=swift-${swift_version}_android-${android_sdk_version}
fi

libxml2_version=$(versionFromTag ${source_dir}/libxml2)

curl_desc=$(describe ${source_dir}/curl | tr '_' '.')
curl_version=${curl_desc#curl-}

boringssl_version=$(describe ${source_dir}/boringssl)

zlib_version=$(versionFromTag ${source_dir}/zlib)

function quiet_pushd {
    pushd "$1" >/dev/null 2>&1
}
function quiet_popd {
    popd >/dev/null 2>&1
}

header "Swift Android SDK build script"

swift_dir=$(realpath $(dirname "$swiftc")/..)
HOST=linux-x86_64
#HOST=$(uname -s -m | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
ndk_toolchain=$ndk_home/toolchains/llvm/prebuilt/$HOST


echo "Swift found at ${swift_dir}"
echo "Host toolchain found at ${host_toolchain}"
${host_toolchain}/bin/swift --version
echo "Android NDK found at ${ndk_home}"
${ndk_toolchain}/bin/clang --version
echo "Building for ${archs}"
echo "Sources are in ${source_dir}"
echo "Build will happen in ${build_dir}"
echo "Products will be placed in ${products_dir}"
echo
echo "Building from:"
echo "  - Swift ${swift_version}"
echo "  - libxml2 ${libxml2_version}"
echo "  - curl ${curl_version}"
echo "  - BoringSSL ${boringssl_version}"
echo "  - zlib ${zlib_version}"

function run() {
    echo "$@"
    "$@"
}

for arch in $archs; do
    # enable short-circuiting the individual builds
    if [[ ! -z "$SKIP_ARCH_BUILD" ]]; then
        continue
    fi

    case $arch in
        armv7) target_host="arm-linux-androideabi"; compiler_target_host="armv7a-linux-androideabi$android_api"; android_abi="armeabi-v7a" ;;
        aarch64) target_host="aarch64-linux-android"; compiler_target_host="$target_host$android_api"; android_abi="arm64-v8a" ;;
        x86_64) target_host="x86_64-linux-android"; compiler_target_host="$target_host$android_api"; android_abi="x86_64" ;;
        x86) target_host="x86-linux-android"; compiler_target_host="$target_host$android_api"; android_abi="x86" ;;
        *) echo "Unknown architecture '$1'"; usage; exit 0 ;;
    esac

    sdk_root=${build_dir}/sdk_root/${arch}
    mkdir -p "$sdk_root"

    header "Building libxml2 for $arch"
    quiet_pushd ${source_dir}/libxml2
        run cmake \
            -G Ninja \
            -S ${source_dir}/libxml2 \
            -B ${build_dir}/$arch/libxml2 \
            -DANDROID_ABI=$android_abi \
            -DANDROID_PLATFORM=android-$android_api \
            -DCMAKE_TOOLCHAIN_FILE=$ndk_home/build/cmake/android.toolchain.cmake \
            -DCMAKE_BUILD_TYPE=$build_type \
            -DCMAKE_EXTRA_LINK_FLAGS="-rtlib=compiler-rt -unwindlib=libunwind -stdlib=libc++ -fuse-ld=lld -lc++ -lc++abi" \
            -DCMAKE_BUILD_TYPE=$build_type \
            -DCMAKE_INSTALL_PREFIX=$sdk_root/usr \
            -DLIBXML2_WITH_PYTHON=NO \
            -DLIBXML2_WITH_ICU=NO \
            -DLIBXML2_WITH_ICONV=NO \
            -DLIBXML2_WITH_LZMA=NO \
            -DBUILD_SHARED_LIBS=OFF \
            -DBUILD_STATIC_LIBS=ON

        quiet_pushd ${build_dir}/$arch/libxml2
            run ninja -j$parallel_jobs
        quiet_popd

        header "Installing libxml2 for $arch"
        quiet_pushd ${build_dir}/$arch/libxml2
            run ninja -j$parallel_jobs install
        quiet_popd
    quiet_popd

    header "Building boringssl for ${compiler_target_host}"
    quiet_pushd ${source_dir}/boringssl
        run cmake \
            -GNinja \
            -B ${build_dir}/$arch/boringssl \
            -DANDROID_ABI=$android_abi \
            -DANDROID_PLATFORM=android-$android_api \
            -DCMAKE_TOOLCHAIN_FILE=$ndk_home/build/cmake/android.toolchain.cmake \
            -DCMAKE_BUILD_TYPE=$build_type \
            -DCMAKE_INSTALL_PREFIX=$sdk_root/usr \
            -DBUILD_SHARED_LIBS=OFF \
            -DBUILD_STATIC_LIBS=ON \
            -DBUILD_TESTING=OFF

        quiet_pushd ${build_dir}/$arch/boringssl
            run ninja -j$parallel_jobs
        quiet_popd

        header "Installing BoringSSL for $arch"
        quiet_pushd ${build_dir}/$arch/boringssl
            run ninja -j$parallel_jobs install
        quiet_popd
    quiet_popd

    header "Building libcurl for ${compiler_target_host}"
    quiet_pushd ${source_dir}/curl
        run cmake \
            -G Ninja \
            -S ${source_dir}/curl \
            -B ${build_dir}/$arch/curl \
            -DANDROID_ABI=$android_abi \
            -DANDROID_PLATFORM=android-$android_api \
            -DCMAKE_TOOLCHAIN_FILE=$ndk_home/build/cmake/android.toolchain.cmake \
            -DCMAKE_BUILD_TYPE=$build_type \
            -DCMAKE_INSTALL_PREFIX=$sdk_root/usr \
            -DOPENSSL_ROOT_DIR=$sdk_root/usr \
            -DOPENSSL_INCLUDE_DIR=$sdk_root/usr/include \
            -DOPENSSL_SSL_LIBRARY=$sdk_root/usr/lib/libssl.a \
            -DOPENSSL_CRYPTO_LIBRARY=$sdk_root/usr/lib/libcrypto.a \
            -DCURL_USE_OPENSSL=ON \
            -DCURLSSLOPT_NATIVE_CA=ON \
            -DTHREADS_PREFER_PTHREAD_FLAG=OFF \
            -DCMAKE_THREAD_PREFER_PTHREAD=OFF \
            -DCMAKE_THREADS_PREFER_PTHREAD_FLAG=OFF \
            -DCMAKE_HAVE_LIBC_PTHREAD=YES \
            -DBUILD_CURL_EXE=NO \
            -DBUILD_SHARED_LIBS=OFF \
            -DBUILD_STATIC_LIBS=ON \
            -DCURL_BUILD_TESTS=OFF

        quiet_pushd ${build_dir}/$arch/curl
            run ninja -j$parallel_jobs
        quiet_popd

        header "Installing libcurl for $arch"
        quiet_pushd ${build_dir}/$arch/curl
            run ninja -j$parallel_jobs install
        quiet_popd
    quiet_popd

    header "Building Android SDK for ${compiler_target_host}"
    quiet_pushd ${source_dir}/swift-project
        build_type_flag="--debug"
        case $build_type in
            Debug) build_type_flag="--debug" ;;
            Release) build_type_flag="--release" ;;
            RelWithDebInfo) build_type_flag="--release-debuginfo" ;;
        esac

        # use an out-of-tree build folder, otherwise subsequent arch builds have conflicts
        export SWIFT_BUILD_ROOT=${build_dir}/$arch/swift-project

        # need to remove symlink that gets created in the NDK to the previous arch's build
        # or else we get errors like:
        # error: could not find module '_Builtin_float' for target 'x86_64-unknown-linux-android'; found: aarch64-unknown-linux-android, at: /home/runner/work/_temp/swift-android-sdk/ndk/android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/swift/android/_Builtin_float.swiftmodule
        rm -f $ndk_toolchain/sysroot/usr/lib/swift

        ./swift/utils/build-script \
            $build_type_flag \
            --reconfigure \
            --no-assertions \
            --android \
            --android-ndk=$ndk_home \
            --android-arch=$arch \
            --android-api-level=$android_api \
            --native-swift-tools-path=$host_toolchain/bin \
            --native-clang-tools-path=$host_toolchain/bin \
            --cross-compile-hosts=android-$arch \
            --cross-compile-deps-path=$sdk_root \
            --install-destdir=$sdk_root \
            --build-llvm=0 \
            --build-swift-tools=0 \
            --skip-build-cmark \
            --skip-local-build \
            --build-swift-static-stdlib \
            --install-swift \
            --install-libdispatch \
            --install-foundation \
            --xctest --install-xctest \
            --swift-testing --install-swift-testing \
            --cross-compile-append-host-target-to-destdir=False

            #--clean-install-destdir \
            #--clean \
    quiet_popd

    header "Completed build for $arch in $sdk_root"
done

# Now generate the bundle
header "Bundling SDK"

sdk_name=swift-${swift_version}_static-linux-${static_linux_sdk_version}
bundle="${sdk_name}.artifactbundle"

rm -rf "${build_dir}/$bundle"
mkdir -p "${build_dir}/$bundle/$sdk_name/swift-linux-musl"

quiet_pushd ${build_dir}/$bundle

# First the info.json, for SwiftPM
cat > info.json <<EOF
{
  "schemaVersion": "1.0",
  "artifacts": {
    "$sdk_name": {
      "variants": [
        {
          "path": "$sdk_name/swift-linux-musl"
        }
      ],
      "version": "0.0.1",
      "type": "swiftSDK"
    }
  }
}
EOF


cd "$sdk_name/swift-linux-musl"

cat > swift-sdk.json <<EOF
{
  "schemaVersion": "4.0",
  "targetTriples": {
EOF

first=true
for arch in $archs; do
    if [[ "$first" == "true" ]]; then
        first=false
    else
        cat >> swift-sdk.json <<EOF
    },
EOF
    fi
    cat >> swift-sdk.json <<EOF
    "${arch}-swift-linux-musl": {
      "toolsetPaths": [
        "toolset.json"
      ],
      "sdkRootPath": "musl-${musl_version}.sdk/${arch}",
      "swiftResourcesPath": "musl-${musl_version}.sdk/${arch}/usr/lib/swift_static",
      "swiftStaticResourcesPath": "musl-${musl_version}.sdk/${arch}/usr/lib/swift_static"
EOF
done

cat >> swift-sdk.json <<EOF
    }
  }
}
EOF

mkdir "musl-${musl_version}.sdk"
quiet_pushd "musl-${musl_version}.sdk"
cp -R ${build_dir}/sdk_root/* .
quiet_popd

mkdir -p swift.xctoolchain/usr/bin

cat > toolset.json <<EOF
{
  "rootPath": "swift.xctoolchain/usr/bin",
  "swiftCompiler" : {
    "extraCLIOptions" : [
      "-static-executable",
      "-static-stdlib"
    ]
  },
  "schemaVersion": "1.0"
}
EOF

quiet_popd

#tree ${build_dir}/$bundle
#tree $products_dir

#header "Outputting compressed bundle"

#quiet_pushd "${build_dir}"
#mkdir -p "${products_dir}"
#tar cvzf "${products_dir}/${bundle}.tar.gz" "${bundle}"
#quiet_popd


