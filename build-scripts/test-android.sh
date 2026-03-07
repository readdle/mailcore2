#!/bin/bash

set -ex

# Create variables
export SWIFT_ANDROID_API_LEVEL=29

# Emulator
export BUILD_ANDROID=1
export EMULATOR_PORT=5558
export EMULATOR_SDK_VERSION=36
export EMULATOR_NAME=ci-test-$EMULATOR_SDK_VERSION-$EMULATOR_PORT
export ANDROID_SERIAL=emulator-$EMULATOR_PORT
export EMULATOR_ARCH=arm64-v8a
export EMULATOR_PACKAGE="system-images;android-$EMULATOR_SDK_VERSION;google_apis;$EMULATOR_ARCH"
export EMULATOR_ABI=google_apis/$EMULATOR_ARCH

function finish {
  exit_code=$?
    adb -s $ANDROID_SERIAL emu kill
    exit $exit_code
}
trap finish EXIT

# Delete emulator if needed
if $ANDROID_HOME/emulator/emulator -list-avds | grep -q $EMULATOR_NAME
then
    avdmanager delete avd --name $EMULATOR_NAME
fi

# Just in case
rm -rf ~/.android/avd/$EMULATOR_NAME.avd

$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager create avd -n $EMULATOR_NAME -k "$EMULATOR_PACKAGE" -d "pixel" --abi $EMULATOR_ABI

# Start adb server
adb start-server

# Start emulator
$ANDROID_HOME/emulator/emulator -no-window -avd $EMULATOR_NAME -noaudio -port $EMULATOR_PORT -partition-size 4000 > /dev/null &

# Wait until enmulator actually started
adb -s emulator-$EMULATOR_PORT wait-for-any-device;

# Clear logcat from previous sessions
bash -c "adb logcat -c || true"

# Create reports folder
mkdir -p .build/reports

# Start write adb logcat to file
mkdir -p .build/debug
adb logcat | ndk-stack -sym .build/debug > .build/reports/ndk-stack.log &

swift-android test --deploy -Xbuild -Xcc -Xbuild -DUNIT_TESTS

# Test
swift-android test --just-run --isolate | tee .build/reports/test.log
return_code=${PIPESTATUS[0]}

cat .build/reports/test.log | xcbeautify --report junit --report-path .build/reports

cat .build/reports/ndk-stack.log

# return code
exit ${return_code}
