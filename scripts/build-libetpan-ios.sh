#!/bin/sh
set -x

pushd "`dirname "$0"`" > /dev/null
scriptpath="`pwd`"
popd > /dev/null

. "$scriptpath/include.sh/build-dep.sh"

url="git@github.com:readdle/libetpan.git"
rev=3655f4ddfecb663f15d06568b06e01ac5de8986f
name="libetpan-ios"
xcode_target="libetpan ios"
xcode_project="libetpan.xcodeproj"
library="libetpan-ios.a"
xcframework="libetpan-ios.xcframework"
embedded_deps="libsasl-ios"

build_git_ios
