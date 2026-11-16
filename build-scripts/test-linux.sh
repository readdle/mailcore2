#!/bin/bash
set -ex

# Create reports folder
mkdir -p .build/reports

# Test; XCTest writes the xUnit report only for a parallel run
BUILD_LINUX=1 swift test -Xmanifest -DTARGET_LINUX -Xcc -DUNIT_TESTS --parallel --xunit-output .build/reports/junit.xml
