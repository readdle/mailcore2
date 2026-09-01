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

Windows builds of spark-core do **not** compile the mailcore2 C++ from source. They compile
only the Swift bindings (`src/swift`) and download a prebuilt archive of the C/C++ libraries,
published as a release asset of this repository.

The archive is **named after the content of the sources it was built from**, not after a
version number:

```text
mailcore2-all-<digest>.zip
```

The digest is a hash of git's tree entries for everything that determines the binaries — `src`
without `src/swift`, `CMakeLists.txt`, and `windows-build-pins.json` (the pinned dependency
revisions and toolchain). It is computed the same way on every platform: `core.autocrlf` cannot
change it, because git already stores a hash per blob.

Two consequences, and they are the whole point:

- **Nothing to bump, nothing to forget.** A change that does not touch the C/C++ sources — a
  Swift-only fix, a README edit — keeps the same digest and reuses the published archive. No
  pin, no PR, no tag ordering to get right.
- **A missing prebuilt cannot pass silently.** There is no Windows CI, so the first thing that
  notices is the spark-core build, and it stops with:

  ```text
  Prebuilt MailCore not found: mailcore2-all-<digest>.zip
  Have you built and uploaded it yet?
  ```

### Publishing a prebuilt ###

On a Windows machine, in a checkout of this repository at the revision that needs the archive:

```powershell
.\build-windows-5.10\Publish-Mailcore2Prebuilt.ps1
```

The script computes the digest, exits early if that archive is already published, verifies the
toolchain against `windows-build-pins.json`, fetches the dependency archive, builds, stamps
`etc/mailcore2-source-digest` into the install tree, packages `mailcore2-all/`, verifies the
package (digest, the runtime DLLs, the public headers) and uploads it with `gh`.

**Nothing is committed to mailcore2 afterwards.** The archive is named after the sources, so
the revision that needs it finds it. Commit, PR and tag as usual — in any order, at any time.

Only `-PublishDependenciesArchive <path>` is ever needed besides: the build inputs (ICU 69.1,
libxml2 2.11.5, openssl, sasl, zlib) are published once as `mailcore2-windows-deps-<n>.zip` and
change almost never.

### Requirements ###

Verified on a clean Windows machine. No AWS key, no `C:\Library` layout, no SSH access and no
internal RD PowerShell modules are required — the repository and every dependency are public,
and `Build-Helpers.ps1` supplies the RD functions when those modules are absent.

- Windows 10 or 11 x64.
- Visual Studio 2022 Build Tools with the C++ workload, CMake and Ninja.
- The versions pinned in `windows-build-pins.json`: MSVC toolset **14.39.33519**, Windows SDK
  **10.0.26100.0**, Swift **5.10.1** for Windows. The toolset matters: Swift 5.10.1 ships
  clang 16, and the 14.40+ STL requires clang 17 and fails with `STL1000`. Toolsets install
  side by side.
- Git, PowerShell 7 and `gh` authenticated with write access (`winget install --id GitHub.cli`,
  then `gh auth login`) — for publishing only. Downloading needs no credentials at all.

Changing any pinned version is deliberate: it changes the digest, so every consumer will ask
for a new archive.

### The dependency archive ###

`mailcore2-windows-deps-<n>.zip` has one top-level directory and this layout:

```text
mailcore2-windows-deps/
  icu-69.1/usr/{bin,include,lib/x64}
  libxml2-2.11.5/usr/{include,lib/x64}
  openssl/{bin,include,lib64}
  sasl/{bin,include,lib64}
  zlib/{include,lib64}
```

How the current one was assembled, in case it ever needs regenerating: ICU 69.1 is the official
`icu4c-69_1-Win64-MSVC2019.zip` distribution, relaid under `icu-69.1/usr`; libxml2 2.11.5 is
built from source with CMake/Ninja and MSVC 14.39.33519 (`CMAKE_BUILD_TYPE=Release`,
`BUILD_SHARED_LIBS=OFF`, and `LIBXML2_WITH_ICONV/ICU/LZMA/MODULES/PROGRAMS/PYTHON/TESTS/ZLIB`
all `OFF`), installed straight into `libxml2-2.11.5/usr`; openssl, sasl and zlib are the
previously S3-hosted binary zips, unchanged.

### What the archive must contain ###

The package step checks this, but when diagnosing a load failure by hand: `bin` must have the
direct non-system dependencies

```text
mailcore2.dll, CMailCore.dll
libetpan.dll, libctemplate.dll, rdtidy.dll
libcrypto-1_1-x64.dll, libssl-1_1-x64.dll, zlib.dll, sasl2.dll
icuuc69.dll, icuin69.dll, icudt69.dll
dispatch.dll, BlocksRuntime.dll
msvcp140.dll, vcruntime140.dll (VC143 redistributable)
```

PDB files stay in the archive: they are needed to symbolicate production crashes.

The build uses the Windows SDK `mt.exe`. Do not replace it with Swift's `llvm-mt`: that one
depends on libxml2 and fails when the Windows profile path contains non-ASCII characters.

### Retention ###

Never delete or overwrite a published `mailcore2-all-<digest>.zip` — revisions built against it
keep downloading it by name. Re-uploading the same digest after a rebuild is the only
legitimate replacement, and it is safe by construction: same digest means same sources.

### Migrating from the S3 flow ###

Archives used to live in the `spark-prebuilt-binaries` S3 bucket, keyed by a version number
that had to be bumped inside the shipped tag. Tags published that way keep working: they run
their own copy of `Get-Mailcore2.ps1`. In this revision the S3 path survives only behind
`-LegacyS3Version <n>`, still requiring `SPARK_PREBUILT_KEY`, and will be removed once the
Windows build moves to SwiftPM like the other platforms.

### Local testing without a prebuilt ###

To test unreleased C++ changes, add `-BuildMailcore2` to the `Build-SwiftMailcore.ps1`
invocation in `Build-SparkCore.ps1` — mailcore2 is then compiled from the pinned checkout
instead of downloading the archive. Slower (~10-15 min extra), for test builds only; remove it
before release.

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
