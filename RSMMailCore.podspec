Pod::Spec.new do |s|
  s.name         = "RSMMailCore"
  s.version      = "2.1.36"
  s.summary      = "Mailcore 2"
  s.description  = "MailCore 2 provide a simple and asynchronous API to work with e-mail protocols IMAP, POP and SMTP. The API has been redesigned from ground up."

  s.homepage     = 'https://github.com/readdle/mailcore2.git'
  s.license      = { :type => 'Copyright 2017 Readdle Inc.', :text => 'Copyright 2017 Readdle Inc.' }

  s.author       = { "Viktor Gedzenko" => "fox@readdle.com" }
  s.source       = { :git => "https://github.com/readdle/mailcore2.git", :tag => "2.1.36"}
  s.platforms    = { :ios => "9.0", :osx => "10.11" }

  s.framework  = "Foundation", "Security"

  s.ios.xcconfig = { "HEADER_SEARCH_PATHS" => "\"$(PODS_TARGET_SRCROOT)/Externals/ctemplate-ios/include/\" \"$(PODS_TARGET_SRCROOT)/Externals/libetpan-ios/include/\" \"$(PODS_TARGET_SRCROOT)/Externals/libsasl-ios/include/\"",
    "SWIFT_INCLUDE_PATHS" => "\"$(PODS_TARGET_SRCROOT)/build-mac/CMailCore\" \"$(PODS_TARGET_SRCROOT)/Externals/libetpan-ios/include/\"",
    "OTHER_CPLUSPLUSFLAGS" => "-DSWIFT -DUCHAR_TYPE=uint16_t"
  }


  s.osx.xcconfig = { "HEADER_SEARCH_PATHS" => "\"$(PODS_TARGET_SRCROOT)/Externals/ctemplate-osx/include/\" \"$(PODS_TARGET_SRCROOT)/Externals/libetpan-osx/include/\"",
    "SWIFT_INCLUDE_PATHS" => "\"$(PODS_TARGET_SRCROOT)/build-mac/CMailCore\" \"$(PODS_TARGET_SRCROOT)/Externals/libetpan-osx/include/\"",
    "OTHER_CPLUSPLUSFLAGS" => "-DSWIFT -DUCHAR_TYPE=uint16_t"
  }


  s.prepare_command = <<-CMD
    scripts/get-ios.sh
    scripts/get-mac.sh
    sed -i '' 's#<tidy/tidy.h>#<rdtidy/tidy.h>#g' ./src/core/basetypes/MCHTMLCleaner.cpp
    sed -i '' 's#<tidy/buffio.h>#<rdtidy/buffio.h>#g' ./src/core/basetypes/MCHTMLCleaner.cpp
    mv src/core/zip/MiniZip/zip.h src/core/zip/MiniZip/rsmmczip.h
    sed -i '' 's#"zip.h"#"rsmmczip.h"#g' src/core/zip/MCZip.cpp
    sed -i '' 's#"zip.h"#"rsmmczip.h"#g' src/core/zip/MiniZip/zip.c
  CMD

  s.dependency 'RDTidyHtml5'
  s.dependency 'RDICU4c'

  s.default_subspec = 'core'
  s.requires_arc = false

  s.header_dir = 'MailCore'
  s.libraries = "xml2", "iconv", "z", "resolv", "c++", "objc"

  s.module_map = "build-mac/MailCore.modulemap"

  s.subspec 'core' do |ss|
    ss.source_files = "src/c/**/*.{h,cpp}",
      "src/core/**/*.{h,cpp,c,mm}",
      "src/async/**/*.{h,cpp}",
      "src/objc/utils/MCOObjectWrapper.{mm,h}",
      "src/objc/utils/NSObject+MCO.h",
      "src/swift/**/*.swift",
      "src/MailCore.h",
      "src/AbstractMessageRendererCallbackWrapper.h"

    ss.exclude_files = "src/core/zip/MiniZip/iowin32.{h,c}",
      "src/core/zip/MiniZip/mini*",
      "src/core/zip/MiniZip/mz*",
      "src/core/basetypes/**/*Win32*.cpp",
      "src/core/basetypes/**/*Android*",
      "src/core/basetypes/**/*GTK*",
      "src/core/basetypes/MCDataMac.mm",
      "src/core/rfc822/MCMessageParserMac.mm",
      "src/swift/utils/AndroidShim.swift",
      "src/core/basetypes/icu-ucsdet/**/*"

    ss.public_header_files =
      "src/MailCore.h",
      "src/core/**/**/MC*.h",
      "src/async/**/**/MC*.h",
      "src/c/**/**/C*.h",
      "src/c/basetypes/MailCoreString.h"

    ss.private_header_files =
      "src/core/basetypes/MCJSONParser.h",
      "src/core/basetypes/MCConnectionLoggerUtils.h",
      "src/core/basetypes/MCLibetpan.h",
      "src/core/basetypes/MCValuePrivate.h",
      "src/core/security/MCCertificateUtils.h",
      "src/core/zip/MCZipPrivate.h",
      "src/c/CBase+Private.h"

    ss.preserve_paths =
      "build-mac/CMailCore/**/*.{h,modulemap}",
      "build-mac/MailCore.modulemap"

    ss.resources = "resources/providers.json"
    ss.resources = "resources/Reactions.json"
    ss.dependency "RSMMailCore/etpan"
    ss.dependency "RSMMailCore/ctemplate"
    ss.dependency "RSMMailCore/sasl2"
  end

  s.subspec 'etpan' do |ss|
    ss.ios.vendored_frameworks = "Externals/libetpan-ios/lib/libetpan-ios.xcframework"
    ss.ios.private_header_files = "Externals/libetpan-ios/include/libetpan/*.h"
    ss.ios.source_files = "Externals/libetpan-ios/include/libetpan/*.h"
    ss.ios.preserve_paths = "Externals/libetpan-ios/include/libetpan/*.h", "Externals/libetpan-ios/lib/**/*"

    ss.osx.vendored_libraries = "Externals/libetpan-osx/lib/libetpan.a"
    ss.osx.private_header_files = "Externals/libetpan-osx/include/libetpan/*.h"
    ss.osx.source_files = "Externals/libetpan-osx/include/libetpan/*.h"
    ss.osx.preserve_paths = "Externals/libetpan-osx/include/libetpan/*.h"
  end

  s.subspec 'sasl2' do |ss|
    ss.osx.libraries = "sasl2"
    ss.ios.vendored_frameworks = "Externals/libsasl-ios/lib/sasl.xcframework"
    ss.ios.private_header_files = "Externals/libsasl-ios/include/sasl/*.h"
    ss.ios.source_files = "Externals/libsasl-ios/include/sasl/*.h"
    ss.ios.preserve_paths = "Externals/libsasl-ios/include/sasl/*.h", "Externals/libsasl-ios/lib/**/*"
  end

  s.subspec 'ctemplate' do |ss|
    ss.ios.vendored_frameworks = "Externals/ctemplate-ios/lib/libctemplate-ios.xcframework"
    ss.ios.private_header_files = "Externals/ctemplate-ios/include/ctemplate/*.h"
    ss.ios.source_files = "Externals/ctemplate-ios/include/ctemplate/*.h"
    ss.ios.preserve_paths = "Externals/ctemplate-ios/include/ctemplate/*.h", "Externals/ctemplate-ios/lib/**/*"

    ss.osx.vendored_libraries = "Externals/ctemplate-osx/lib/libctemplate.a"
    ss.osx.private_header_files = "Externals/ctemplate-osx/include/ctemplate/*.h"
    ss.osx.source_files = "Externals/ctemplate-osx/include/ctemplate/*.h"
    ss.osx.preserve_paths = "Externals/ctemplate-osx/include/ctemplate/*.h"
  end
end
