// swift-tools-version:5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

var CMailCoreExcludes = [
    "core/basetypes/MCDataMac.mm",
    "core/rfc822/MCMessageParserMac.mm",

    "core/zip/MiniZip/MiniZip64_Changes.txt",
    "core/zip/MiniZip/unzip.c",
    "core/zip/MiniZip/Makefile",
    "core/zip/MiniZip/mztools.c",
    "core/zip/MiniZip/MiniZip64_info.txt",
    "core/zip/MiniZip/make_vms.com",
    "core/zip/MiniZip/iowin32.c",
    "core/zip/MiniZip/minizip.c",
    "core/zip/MiniZip/miniunz.c",

    "core/basetypes/icu-ucsdet/ucsdet.cpp",
    "core/basetypes/icu-ucsdet/csrutf8.cpp",
    "core/basetypes/icu-ucsdet/csdetect.cpp",
    "core/basetypes/icu-ucsdet/uinvchar.c",
    "core/basetypes/icu-ucsdet/csrucode.cpp",
    "core/basetypes/icu-ucsdet/uarrsort.c",
    "core/basetypes/icu-ucsdet/ucln_in.cpp",
    "core/basetypes/icu-ucsdet/csrsbcs.cpp",
    "core/basetypes/icu-ucsdet/ucln_cmn.cpp",
    "core/basetypes/icu-ucsdet/csr2022.cpp",
    "core/basetypes/icu-ucsdet/inputext.cpp",
    "core/basetypes/icu-ucsdet/cmemory.c",
    "core/basetypes/icu-ucsdet/uenum.c",
    "core/basetypes/icu-ucsdet/umutex.cpp",
    "core/basetypes/icu-ucsdet/csrmbcs.cpp",
    "core/basetypes/icu-ucsdet/utrace.c",
    "core/basetypes/icu-ucsdet/csmatch.cpp",
    "core/basetypes/icu-ucsdet/ustring.cpp",
    "core/basetypes/icu-ucsdet/udataswp.c",
    "core/basetypes/icu-ucsdet/cstring.c",
    "core/basetypes/icu-ucsdet/uobject.cpp",
    "core/basetypes/icu-ucsdet/csrecog.cpp",

    "objc/abstract/MCOAbstractPart.mm",
    "objc/abstract/MCOAbstractMultipart.mm",
    "objc/abstract/MCOMessageHeader.mm",
    "objc/abstract/MCOAbstractMessage.mm",
    "objc/abstract/MCOAbstractMessageRendererCallback.mm",
    "objc/abstract/MCOAbstractMessagePart.mm",
    "objc/abstract/MCOAddress.mm",
    "objc/pop/MCOPOPFetchMessageOperation.mm",
    "objc/pop/MCOPOPNoopOperation.mm",
    "objc/pop/MCOPOPSession.mm",
    "objc/pop/MCOPOPMessageInfo.mm",
    "objc/pop/MCOPOPFetchHeaderOperation.mm",
    "objc/pop/MCOPOPOperation.mm",
    "objc/pop/MCOPOPFetchMessagesOperation.mm",
    "objc/imap/MCOIMAPCustomCommandOperation.mm",
    "objc/imap/MCOIMAPCheckAccountOperation.mm",
    "objc/imap/MCOIMAPIdentityOperation.mm",
    "objc/imap/MCOIMAPFolderInfo.mm",
    "objc/imap/MCOIMAPMultipart.mm",
    "objc/imap/MCOIMAPFetchMessagesOperation.mm",
    "objc/imap/MCOIMAPSession.mm",
    "objc/imap/MCOIMAPMessage.mm",
    "objc/imap/MCOIMAPMultiDisconnectOperation.mm",
    "objc/imap/MCOIMAPBaseOperation.mm",
    "objc/imap/MCOIMAPAppendMessageOperation.mm",
    "objc/imap/MCOIMAPMoveMessagesOperation.mm",
    "objc/imap/MCOIMAPFolderInfoOperation.mm",
    "objc/imap/MCOIMAPOperation.mm",
    "objc/imap/MCOIMAPFetchContentToFileOperation.mm",
    "objc/imap/MCOIMAPQuotaOperation.mm",
    "objc/imap/MCOIMAPFolderStatusOperation.mm",
    "objc/imap/MCOIMAPIdentity.mm",
    "objc/imap/MCOIMAPMessagePart.mm",
    "objc/imap/MCOIMAPFolder.mm",
    "objc/imap/MCOIMAPNamespaceItem.mm",
    "objc/imap/MCOIMAPFolderStatus.mm",
    "objc/imap/MCOIMAPFetchParsedContentOperation.mm",
    "objc/imap/MCOIMAPSearchExpression.mm",
    "objc/imap/MCOIMAPFetchFoldersOperation.mm",
    "objc/imap/MCOIMAPNamespace.mm",
    "objc/imap/MCOIMAPNoopOperation.mm",
    "objc/imap/MCOIMAPFetchNamespaceOperation.mm",
    "objc/imap/MCOIMAPSearchOperation.mm",
    "objc/imap/MCOIMAPCapabilityOperation.mm",
    "objc/imap/MCOIMAPIdleOperation.mm",
    "objc/imap/MCOIMAPFetchContentOperation.mm",
    "objc/imap/MCOIMAPPart.mm",
    "objc/imap/MCOIMAPCopyMessagesOperation.mm",
    "objc/imap/MCOIMAPMessageRenderingOperation.mm",
    "objc/rfc822/MCOMessageBuilder.mm",
    "objc/rfc822/MCOMessagePart.mm",
    "objc/rfc822/MCOMessageParser.mm",
    "objc/rfc822/MCOMultipart.mm",
    "objc/rfc822/MCOAttachment.mm",
    "objc/provider/MCOAccountValidator.mm",
    "objc/provider/MCONetService.mm",
    "objc/provider/MCOMailProvidersManager.mm",
    "objc/provider/MCOMailProvider.mm",
    "objc/utils/MCORange.mm",
    "objc/utils/NSDictionary+MCO.mm",
    "objc/utils/NSArray+MCO.mm",
    "objc/utils/NSSet+MCO.mm",
    "objc/utils/MCOIndexSet.mm",
    "objc/utils/NSObject+MCO.mm",
    "objc/utils/MCOOperation.mm",
    "objc/utils/NSError+MCO.mm",
    "objc/utils/NSValue+MCO.mm",
    "objc/utils/NSString+MCO.mm",
    "objc/utils/NSData+MCO.mm",
    "objc/smtp/MCOSMTPSession.mm",
    "objc/smtp/MCOSMTPLoginOperation.mm",
    "objc/smtp/MCOSMTPNoopOperation.mm",
    "objc/smtp/MCOSMTPSendOperation.mm",
    "objc/smtp/MCOSMTPOperation.mm",
    "objc/nntp/MCONNTPDisconnectOperation.mm",
    "objc/nntp/MCONNTPListNewsgroupsOperation.mm",
    "objc/nntp/MCONNTPFetchOverviewOperation.mm",
    "objc/nntp/MCONNTPOperation.mm",
    "objc/nntp/MCONNTPGroupInfo.mm",
    "objc/nntp/MCONNTPFetchServerTimeOperation.mm",
    "objc/nntp/MCONNTPFetchHeaderOperation.mm",
    "objc/nntp/MCONNTPPostOperation.mm",
    "objc/nntp/MCONNTPFetchAllArticlesOperation.mm",
    "objc/nntp/MCONNTPFetchArticleOperation.mm",
    "objc/nntp/MCONNTPSession.mm",
]

var mailcoreExcludes = [
    "utils/RSMLibetpanHelper.mm",
]

#if TARGET_ANDROID

CMailCoreExcludes += [
    "core/basetypes/MCMainThreadMac.mm",
    "core/basetypes/MCAutoreleasePoolMac.mm",
    "core/basetypes/MCObjectMac.mm",
    "core/zip/MCZipMac.mm",
    "objc/utils/MCOObjectWrapper.mm",
]

let CMailCoreExtensionFiles: [String] = [
    "core/zip/MiniZip/zip.c",
    "core/zip/MiniZip/ioapi.c"
]

let mailcoreResources: [Resource] = []

mailcoreExcludes += [
    "resources/providers.json"
]

#else

let CMailCoreExtensionFiles: [String] = [
    "core/basetypes/MCMainThreadMac.mm",
    "core/basetypes/MCAutoreleasePoolMac.mm",
    "core/basetypes/MCObjectMac.mm",
    "core/zip/MCZipMac.mm",
    "objc/utils/MCOObjectWrapper.mm",
    "core/zip/MiniZip/zip.c",
    "core/zip/MiniZip/ioapi.c"
]

let mailcoreResources: [Resource] = [
    .copy("resources/providers.json")
]

#endif

let products: [Product] = [
    .library(name: "MailCore", type: .dynamic, targets: ["MailCore"]),
]

let dependencies: [Package.Dependency] = [
    .package(name: "libetpan", url: "https://github.com/readdle/libetpan.git", .exact("1.9.3-readdle.9")),
    .package(name: "tidy-html5", url: "https://github.com/readdle/tidy-html5.git", .exact("5.4.0-readdle.29")),
    .package(name: "ctemplate", url: "https://github.com/readdle/ctemplate.git", .exact("2.2.3-readdle.4")),
    .package(name: "unicode", url: "https://github.com/readdle/swift-unicode", .exact("68.2.0"))
]

var targets: [Target] = [
    .target(
        name: "CMailCore",
        dependencies: [
            .product(name: "etpan", package: "libetpan"),
            .product(name: "RDHtml5Tidy", package: "tidy-html5"),
            .product(name: "ctemplate", package: "ctemplate"),
            .product(name: "unicode", package: "unicode", condition: .when(platforms: [.iOS, .macOS])),
        ],
        path: "src",
        exclude: [
            "core/basetypes/MCWin32.cpp",
            "core/basetypes/MCStringWin32.cpp",
            "core/basetypes/MCMainThreadGTK.cpp",
            "core/basetypes/MCMainThreadAndroid.cpp",
            "core/basetypes/MCMainThreadWin32.cpp"
        ] + CMailCoreExcludes,
        sources: [
            "async",
            "c",
            "core"
        ] + CMailCoreExtensionFiles,
        cSettings: [
            .headerSearchPath("async/imap"),
            .headerSearchPath("async/pop"),
            .headerSearchPath("async/smtp"),
            .headerSearchPath("core/basetypes"),
            .headerSearchPath("core/zip/MiniZip"),
            .headerSearchPath("core/abstract"),
            .headerSearchPath("core/basetypes"),
            .headerSearchPath("core/imap"),
            .headerSearchPath("core/nntp"),
            .headerSearchPath("core/pop"),
            .headerSearchPath("core/renderer"),
            .headerSearchPath("core/rfc822"),
            .headerSearchPath("core/security"),
            .headerSearchPath("core/smtp"),
            .headerSearchPath("core/zip"),
            .headerSearchPath("c"),
            .headerSearchPath("c/abstract"),
            .headerSearchPath("c/basetypes"),
            .headerSearchPath("c/imap"),
            .headerSearchPath("c/provider"),
            .headerSearchPath("c/rfc822"),
            .headerSearchPath("c/smtp"),
            .headerSearchPath("c/utils"),
            .headerSearchPath("objc/utils"),
            .define("ANDROID", .when(platforms: [.android])),
            .define("UCHAR_TYPE", to: "uint16_t", .when(platforms: [.macOS, .iOS])),
            .unsafeFlags(["-fsigned-char"], .when(platforms: [.android])),
            .unsafeFlags(["-fno-objc-arc"], .when(platforms: [.macOS, .iOS]))
        ],
        linkerSettings: [
            .linkedLibrary("z"),
            .linkedLibrary("xml2"),
            .linkedLibrary("resolv", .when(platforms: [.iOS, .macOS])),
            .linkedLibrary("log", .when(platforms: [.android])),
            .linkedLibrary("_FoundationICU", .when(platforms: [.android]))
        ]
    ),
    .target(
        name: "MailCore",
        dependencies: [
            .product(name: "etpan", package: "libetpan"),
            "CMailCore"
        ],
        path: "src/swift",
        exclude: mailcoreExcludes,
        resources: mailcoreResources,
        linkerSettings: [
            .unsafeFlags(["-Xlinker", "-soname", "-Xlinker", "libMailCore.so"], .when(platforms: [.android]))
        ]
    ),
    .testTarget(
        name: "MailCoreTests", 
        dependencies: ["MailCore"],
        path: "unittest",
        exclude: [
            "Info.plist",
            "CMakeLists.txt",
            "unittest.cpp",
            "unittest.mm"
        ],
        sources: ["IMAPInterruptCurrentCommandTests.swift", "LibetpanHelperTests.swift", "unittest.swift"],
        resources: [
            .copy("data")
        ]
    )
]

let package = Package(
    name: "MailCore",
    defaultLocalization: "en",
    products: products,
    dependencies: dependencies,
    targets: targets,
    swiftLanguageVersions: [.v5],
    cxxLanguageStandard: .cxx11
)
