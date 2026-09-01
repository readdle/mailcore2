## MailCore 2: Introduction ##

MailCore 2 provides a simple and asynchronous Objective-C API to work with the e-mail protocols **IMAP**, **POP** and **SMTP**. The API has been redesigned from the ground up.  It features:

- **POP**, **IMAP** and **SMTP** support
- **[RFC822](http://www.ietf.org/rfc/rfc0822.txt)** parser and generator
- **Asynchronous** APIs
- **HTML** rendering of messages
- **iOS** and **Mac** support

[![Build Status](https://travis-ci.org/MailCore/mailcore2.png?branch=master)](https://travis-ci.org/MailCore/mailcore2)


## Installation ##

### Build for iOS/OSX ###

Read [instructions for iOS/OSX](https://github.com/MailCore/mailcore2/blob/master/build-mac/README.md).

### Build for Android ###

Read [instructions for Android](https://github.com/MailCore/mailcore2/blob/master/build-android/README.md).

### Build for Windows ###

Read [instructions for Windows](https://github.com/MailCore/mailcore2/blob/master/build-windows/README.md).

### Build for Linux ###

Read [instructions for Linux](https://github.com/MailCore/mailcore2/blob/master/build-linux/README.md).

## Updating mailcore2 on Windows (Spark prebuilt flow) ##

Windows builds of spark-core do **not** compile mailcore2 C++ from source.
`Build-SparkCore.ps1` clones this repo at a pinned tag and runs
`build-windows-5.10\Build-SwiftMailcore.ps1`, which compiles only the Swift
bindings (`src/swift`) and downloads the prebuilt C/C++ libraries
(`Get-Mailcore2.ps1`, `mailcore2-all-<N>.zip`). The prebuilt archives are
stored as **GitHub Release assets of this repository** (Releases page of
`readdle/mailcore2`). **Any C++ change reaches Windows only through a new
prebuilt archive** — merging a PR or moving a tag is not enough.

### Prerequisites ###

Everything below is preinstalled in the CI image
`ghcr.io/readdle/spark-js-addon-windows-builder` — building inside it is the
easiest path. On a bare machine you need:

- VS2022 Build Tools with an MSVC toolset whose STL accepts the Swift
  toolchain's clang. Swift 5.10.1 ships clang 16, so the toolset must be
  **14.39 (17.9) or older** — the 14.40+ STL requires clang 17 and fails with
  `STL1000`. Install the side-by-side component
  `Microsoft.VisualStudio.Component.VC.14.39.17.9.x86.x64` and make it the
  default via `VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt` if a
  newer toolset is also installed.
- Windows SDK **10.0.18362** (version 1903, from the Windows SDK archive) —
  the RD build modules pin it when configuring the VS environment.
- RD PowerShell modules (`RDBuildCMake`, `RDBuildMSVC`, `RDDependency`) in
  `PSModulePath`.
- Swift **5.10.1** toolchain (provides `clang-cl` and the Windows SDK with
  dispatch/BlocksRuntime).
- ICU 69.1 at `C:\Library\icu-69.1\usr`, libxml2 2.11.5 at
  `C:\Library\libxml2-2.11.5\usr` (paths are hardcoded in the script).
- `SPARK_PREBUILT_KEY` env var — download token for
  `spark-prebuilt-binaries.s3.amazonaws.com` (zlib/sasl/openssl prebuilts).
- ssh access to `git@github.com:readdle/{ctemplate,libetpan,tidy-html5}`.

### Build ###

```powershell
$env:SPARK_PREBUILT_KEY = "<key>"
powershell -ExecutionPolicy Bypass -File .\build-windows-5.10\Build-Mailcore2.ps1 -Install
```

The script clones and builds ctemplate/libetpan/tidy, downloads the binary
deps, then builds mailcore2/CMailCore with CMake + Ninja using `clang-cl`
from the Swift toolchain. `-Install` lays the result out in `.build\install`
(`bin`, `include`, `lib`, `etc`).

- After a **failed** run, delete `.build` before retrying — stale CMake
  caches keep the old configuration (wrong install prefix, wrong build type)
  and produce confusing errors.
- Verify what was built: `type .build\install\etc\mailcore2-git-rev` must be
  the commit you intend to ship.

### Package ###

The zip must contain a single top-level folder named exactly `mailcore2-all`
(that is the path `Get-Mailcore2.ps1` extracts):

```powershell
cd .\.build
Copy-Item -Recurse install mailcore2-all
tar -a -cf mailcore2-all-<N+1>.zip mailcore2-all
```

Sanity check against the current archive: `tar -tf` both files and compare
the top-level layout.

### Upload ###

The archives live as release assets of this repository. Attach the new zip to
the release that holds the prebuilt binaries (create it from the shipped tag
with `gh release create` on first use):

```bash
gh release upload <release-tag> mailcore2-all-<N+1>.zip --repo readdle/mailcore2
```

Verify the asset is in place and downloadable:

```bash
gh release view <release-tag> --repo readdle/mailcore2
gh release download <release-tag> --pattern "mailcore2-all-<N+1>.zip" --repo readdle/mailcore2 --output /tmp/check.zip
```

The repository is private, so a plain browser URL needs authentication — the
build downloads the asset with the token configured for it (see
`Get-Mailcore2.ps1`). Never delete or overwrite an existing
`mailcore2-all-<N>.zip` asset — older tags keep downloading it by name.

### Switch builds to the new prebuilt ###

1. In this repo: bump `$PrebuiltMailcoreVersion` in
   `build-windows-5.10/Get-Mailcore2.ps1` (and make sure its download URL
   points at the release asset the archive was uploaded to), PR into
   `spark2`.
2. Tag the merge with the next `2.1.x` tag. The bump **must be inside the
   tag** — spark-core runs `Get-Mailcore2.ps1` from its mailcore checkout at
   that tag, so a tag without the bump silently downloads the previous
   archive.
3. In `spark-core-mono`, update every mailcore pin to the new tag — the
   versions must match across platforms:
   - `spark-core/build-scripts/Windows-5.10/Build-SparkCore.ps1`
     (`GitBranch` of the MailCore dependency) — Windows;
   - `spark-core/Package.swift` and `spark-core/SparkCoreNano/Package.swift`
     (`.package(... branch:)`) — Mac/Android SPM;
   - `spark-js-addon/scripts/mac/configure.rb` (`RemoteSwiftPackage`) — the
     source the addon workspace is generated from;
   - `spark-js-addon/SparkCoreAddon.xcworkspace/xcshareddata/swiftpm/Package.resolved`
     — autogenerated from `configure.rb` but tracked in git; update the
     `branch`/`revision` pair so CI resolves without a regeneration step.

### Local testing without a prebuilt ###

To test unreleased C++ changes, add `-BuildMailcore2` to the
`Build-SwiftMailcore.ps1` invocation in `Build-SparkCore.ps1` — mailcore2 is
then compiled from the pinned checkout instead of downloading the archive.
Slower (~10–15 min extra), for test builds only; remove it before release.

## Basic IMAP Usage ##

Using MailCore 2 is just a little more complex conceptually than the original MailCore.  All fetch requests in MailCore 2 are made asynchronously through a queue.  What does this mean?  Well, let's take a look at a simple example:

```objc
    MCOIMAPSession *session = [[MCOIMAPSession alloc] init];
    [session setHostname:@"imap.gmail.com"];
    [session setPort:993];
    [session setUsername:@"ADDRESS@gmail.com"];
    [session setPassword:@"123456"];
    [session setConnectionType:MCOConnectionTypeTLS];

    MCOIMAPMessagesRequestKind requestKind = MCOIMAPMessagesRequestKindHeaders;
    NSString *folder = @"INBOX";
    MCOIndexSet *uids = [MCOIndexSet indexSetWithRange:MCORangeMake(1, UINT64_MAX)];

    MCOIMAPFetchMessagesOperation *fetchOperation = [session fetchMessagesOperationWithFolder:folder requestKind:requestKind uids:uids];

    [fetchOperation start:^(NSError * error, NSArray * fetchedMessages, MCOIndexSet * vanishedMessages) {
        //We've finished downloading the messages!

        //Let's check if there was an error:
        if(error) {
            NSLog(@"Error downloading message headers:%@", error);
        }

        //And, let's print out the messages...
        NSLog(@"The post man delivereth:%@", fetchedMessages);
    }];
```

In this sample, we retrieved and printed a list of email headers from an IMAP server.  In order to execute the fetch, we request an asynchronous operation object from the `MCOIMAPSession` instance with our parameters (more on this later).  This operation object is able to initiate a connection to Gmail when we call the `start` method.  Now here's where things get a little tricky.  We call the `start` function with an Objective-C block, which is executed on the main thread when the fetch operation completes.  The actual fetching from IMAP is done on a **background thread**, leaving your UI and other processing **free to use the main thread**.

## Documentation ##

* Class documentation [Obj-C](http://libmailcore.com/api/objc/index.html) / [Java](http://libmailcore.com/api/java/index.html)
* [Wiki](https://github.com/MailCore/mailcore2/wiki)

## License ##

MailCore 2 is BSD-Licensed.
