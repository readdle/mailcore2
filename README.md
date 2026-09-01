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
bindings (`src/swift`) and downloads the prebuilt C++ libraries
(`Get-Mailcore2.ps1`). **Any C++ change reaches Windows only through a new
prebuilt archive** — merging a PR or moving a tag is not enough.

The archive is a **release asset of this repository**, named after a digest of
the sources it was built from:

```text
mailcore2-windows-<digest>.zip
```

It used to be `mailcore2-all-<N>.zip` in the `spark-prebuilt-binaries` S3
bucket, behind `SPARK_PREBUILT_KEY`, with the version bumped by hand inside the
shipped tag. Nothing about the build changed — only where the archive lives and
how it is named. Two things follow:

- **Nothing to bump.** The digest covers `src` (without `src/swift`),
  `CMakeLists.txt` and `build-windows-5.10`, so a checkout already knows which
  archive it needs. A change that touches none of those reuses the published one.
- **A missing archive cannot pass silently.** The `mailcore2 - Windows prebuilt`
  pull-request check says so before the spark-core build ever runs.

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
- ssh access to `git@github.com:readdle/{ctemplate,libetpan,tidy-html5}`.

`SPARK_PREBUILT_KEY` is no longer needed: zlib/sasl/openssl come from a public
release asset. Publishing additionally needs the GitHub CLI, authenticated as a
user with write access — that one cannot be baked into the image:

```powershell
gh auth login
```

### Build ###

```powershell
powershell -ExecutionPolicy Bypass -File .\build-windows-5.10\Build-Mailcore2.ps1 -Install
```

The script clones and builds ctemplate/libetpan/tidy, downloads the binary
deps (openssl/sasl/zlib, now from the release instead of S3), then builds
mailcore2/CMailCore with CMake + Ninja using `clang-cl` from the Swift
toolchain. `-Install` lays the result out in `.build\install`
(`bin`, `include`, `lib`, `etc`).

- After a **failed** run, delete `.build` before retrying — stale CMake
  caches keep the old configuration (wrong install prefix, wrong build type)
  and produce confusing errors. `Publish-Mailcore2Prebuilt.ps1` does this for
  you; a direct run does not.
- Verify what was built: `type .build\install\etc\mailcore2-git-rev` must be
  the commit you intend to ship.

### Publish ###

Packaging and uploading are one command, run in a checkout **at the revision
that needs the prebuilt**:

```powershell
.\build-windows-5.10\Publish-Mailcore2Prebuilt.ps1
```

It computes the digest, exits early if that archive is already published,
fetches the dependency archive, clears the previous build output, builds through
`Build-Mailcore2.ps1`, stamps `etc/mailcore2-source-digest`, packages
`mailcore2-all/`, verifies the package, and adds it to the
[`windows-prebuilt`](https://github.com/readdle/mailcore2/releases/tag/windows-prebuilt)
release. `-Force` rebuilds and replaces an archive that is already published;
`-SkipUpload` stops after verifying.

Nothing needs to be committed afterwards — the archive is named after the
sources, so the revision that needs it finds it.

The `windows-prebuilt` release is a permanent container for binaries, not a code
release. It was created by hand, once, along with
`mailcore2-windows-deps-1.zip`: openssl, sasl and zlib, the three binaries that
used to come from S3, unchanged. No script creates the release or attaches that
archive.

Never delete a published `mailcore2-windows-<digest>.zip` — revisions built
against it keep downloading it by name.

### Pull request check ###

`.github/workflows/pull-request-check.yml` runs
[`build-windows-5.10/Check-PrebuiltPublished.ps1`](build-windows-5.10/Check-PrebuiltPublished.ps1)
on every pull request. It builds nothing and needs no Windows: the digest is a
hash of git tree entries, identical on every platform, so a Linux runner
computes it in seconds and asks the release whether that archive is there.

It checks the merge result, because that is what lands on the base branch and
gets tagged. When the base has moved since you published, your branch head has
an archive and the merge result does not — the check says so and tells you to
rebase.

Re-run it after publishing; nothing needs to be pushed for it to turn green. It
is advisory until `mailcore2 - Windows prebuilt` is added to the branch
protection rules for `spark2`.

### Switch builds to the new prebuilt ###

1. Publish the prebuilt for the revision you are shipping (above). There is no
   version to bump and nothing to commit for it.
2. Tag the merge with the next `2.1.x` tag.
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
