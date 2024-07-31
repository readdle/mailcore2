#!/bin/bash

set -ex

export SWIFT_ANDROID_ICU_VERSION="73"

function finish {
  exit_code=$?
    adb -s $ANDROID_SERIAL emu kill
    exit $exit_code
}
trap finish EXIT

# Create reports folder
mkdir -p .build/reports

# Start write adb logcat to file
adb logcat | ndk-stack -sym .build/debug > .build/reports/ndk-stack.log &

# Build
pass_to_swiftc="-Xbuild -Xswiftc -Xbuild"
pass_to_frontend="$pass_to_swiftc -Xfrontend $pass_to_swiftc"

swift-test --deploy \
    $pass_to_frontend -experimental-disable-objc-attr

# Test
swift-test --just-run | tee .build/reports/test.log
return_code=${PIPESTATUS[0]}

cat .build/reports/test.log | xcpretty --report junit --output .build/reports/junit.xml

cat .build/reports/ndk-stack.log

# return code
exit ${return_code}
