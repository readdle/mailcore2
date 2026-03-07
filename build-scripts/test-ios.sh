#!/bin/bash
set -ex

# Create reports folder
mkdir -p .build-ios/reports

# Test
MANIFEST_TARGET_PLATFORM=iOS \
  xcodebuild test -scheme MailCore \
  -destination "OS=26.2,name=iPhone 17" \
  -derivedDataPath ./.build-ios | tee .build-ios/reports/test.log
return_code=${PIPESTATUS[0]}

# Generate junit report
cat .build-ios/reports/test.log | xcpretty --report junit --output .build-ios/reports/junit.xml

# return code
exit ${return_code}
