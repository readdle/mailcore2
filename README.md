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

## Windows prebuilt ##

Windows builds of spark-core do **not** compile the mailcore2 C++ from source. They compile
only the Swift bindings (`src/swift`) and download a prebuilt archive of the C/C++ libraries,
published as a release asset of this repository. Everything involved lives in
[`windows/`](windows).

The archive is **named after the content of the sources it was built from**, not after a
version number:

```text
mailcore2-all-<digest>.zip
```

The digest is a hash of git's tree entries for everything that determines the binaries — `src`
without `src/swift`, `CMakeLists.txt`, and `windows/pins.json` (the pinned dependency revisions
and toolchain). It is computed the same way on every platform:
`core.autocrlf` cannot change it, because git already stores a hash per blob.

Two consequences, and they are the whole point:

- **Nothing to bump, nothing to forget.** A change that does not touch the C/C++ sources — a
  Swift-only fix, a README edit — keeps the same digest and reuses the published archive. No
  pin, no PR, no tag ordering to get right.
- **A missing prebuilt cannot pass silently.** The `mailcore2 - Windows prebuilt` pull-request
  check asks whether an archive exists for the sources being merged, and goes red with:

  ```text
  There is no Windows prebuilt for these sources: mailcore2-all-<digest>.zip
  Have you built and uploaded it yet?
  ```

  Should one slip past anyway, the spark-core build stops with the same question.

### The pull-request check ###

`.github/workflows/pull-request-check.yml` runs
[`windows/Check-PrebuiltPublished.ps1`](windows/Check-PrebuiltPublished.ps1) on every pull
request. It builds nothing: the digest is a hash of git tree entries, so a Linux runner
computes it in seconds and then asks the release whether that archive is there. The answer is
written to the pull request page, not only into the log.

It checks the **merge result**, because that is what lands on the base branch and gets tagged.
When the base has moved since you published, your branch head has an archive and the merge
result does not — the check says so and tells you to rebase, rather than leaving you to guess.

A pull request that does not touch the C/C++ sources keeps the same digest and goes green
without anyone doing anything, which is the point of naming archives after content.

The check is only advisory until `mailcore2 - Windows prebuilt` is added to the branch
protection rules for `spark2`. Worth waiting until the first archive has been published:
before that there is no release at all, so every pull request touching the C/C++ goes red,
correctly but uselessly.

### The release, set up once ###

The archives live on a permanent [`windows-prebuilt`](https://github.com/readdle/mailcore2/releases/tag/windows-prebuilt)
release — a container for binaries, not a code release. Created by hand, one time:
tag `windows-prebuilt`, marked as a pre-release, with `mailcore2-windows-deps-1.zip` attached.
`Publish-Mailcore2Prebuilt.ps1` then only adds `mailcore2-all-<digest>.zip` archives to it.

### What to do when it is red ###

Someone with a Windows machine has to build and upload. The whole job is one command, in a
checkout of this repository at the revision that needs the archive:

```powershell
.\windows\Publish-Mailcore2Prebuilt.ps1
```

That is also all an agent needs to be told — "build and upload the Windows prebuilt for this
revision". [AGENTS.md](AGENTS.md) carries the procedure, the failure modes and the rules
(chiefly: publishing commits nothing to this repository). Re-run the check afterwards; nothing
needs to be pushed for it to turn green.

It computes the digest, exits early if that archive is already published, verifies the
toolchain against `windows/pins.json`, fetches the dependency archive, clears the previous
install tree, builds, checks the install tree really came from the pinned revisions, stamps
`etc/mailcore2-source-digest`, packages, verifies, and adds it to the release.

Commit, PR and tag as usual — in any order, at any time. The archive is named after the
sources, so the revision that needs it finds it.

### What is in `windows/` ###

| | |
|---|---|
| `pins.json` | Everything besides the C/C++ sources that determines the binaries. Part of the digest. |
| `Publish-Mailcore2Prebuilt.ps1` | Build + verify + add to the release. The one command that matters. |
| `Get-Mailcore2.ps1` | Downloads the archive for the current sources. Called by the Swift build. |
| `Build-Mailcore2.ps1` | Builds the C/C++ from source. |
| `Build-SwiftMailcore.ps1` | Builds `src/swift` on top of either of the two. spark-core's entry point. |
| `Build-Helpers.ps1`, `Common.ps1` | Digest, archive naming, and stand-ins for the internal RD modules. |
| `Check-PrebuiltPublished.ps1` | Asks whether these sources have a published archive. The pull-request check. |
| `bin/`, `vs/`, `mailcore2/` | Redistributables and the Visual Studio project files. |
| `legacy-vs2019/` | The superseded pre-Swift-5.10 scripts. Do not use; they still expect the retired S3 bucket. |

### Requirements ###

No AWS key, no `C:\Library` layout and no SSH access are required — the repository and every
dependency are public. Nothing here installs a toolchain for you; a machine that does not match
the pins says which version it is missing and stops.

- Windows 10 or 11 x64, PowerShell 7, Git.
- Visual Studio 2022 Build Tools with the C++ workload, CMake and Ninja.
- The versions pinned in `windows/pins.json`: MSVC toolset **14.39.33519**, Windows SDK
  **10.0.26100.0**, Swift **5.10.1** for Windows. The toolset matters: Swift 5.10.1 ships
  clang 16, and the 14.40+ STL requires clang 17 and fails with `STL1000`. Toolsets install
  side by side, and the build puts the pinned one on PATH rather than whatever is default.
- `gh` authenticated with write access — for publishing only. Downloading needs no credentials.

Changing any pinned value is deliberate: it changes the digest, so every consumer will ask for
a new archive.

Publishing the prebuilt needs no internal RD PowerShell modules. `Build-SwiftMailcore.ps1` is
the exception — it uses `Initialize-SDK` and `Invoke-BuildModuleTarget`, which are not
reimplemented, and runs inside the Spark CI image where they exist.

### The dependency archive ###

The binary build inputs travel as one public asset, `mailcore2-windows-deps-<n>.zip`, with a
single top-level directory:

```text
mailcore2-windows-deps/
  icu-69.1/usr/{bin,include,lib/x64}
  libxml2-2.11.5/usr/{include,lib/x64}
  openssl/{bin,include,lib64}
  sasl/{bin,include,lib64}
  zlib/{include,lib64}
```

It is attached to the release by hand once and downloaded automatically from then on; it has
never changed.

How the current one was assembled, in case it ever needs regenerating: ICU 69.1 is the official
`icu4c-69_1-Win64-MSVC2019.zip` distribution, relaid under `icu-69.1/usr` (`bin64` to `usr/bin`,
`lib64` to `usr/lib/x64`); libxml2 2.11.5 is built from source with CMake/Ninja and MSVC
14.39.33519 (`CMAKE_BUILD_TYPE=Release`, `BUILD_SHARED_LIBS=OFF`, and
`LIBXML2_WITH_ICONV/ICU/LZMA/MODULES/PROGRAMS/PYTHON/TESTS/ZLIB` all `OFF`), installed straight
into `libxml2-2.11.5/usr` with the import library also copied to `usr/lib/x64`; openssl, sasl
and zlib are the previously S3-hosted binary zips, unchanged.

Replacing it means attaching the new one by hand and editing `dependenciesArchive` in
`pins.json`, which changes the digest and asks every consumer for a new `mailcore2-all`
archive. That is intended.

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

plus `msvcp120.dll` and `msvcr120.dll`, which the prebuilt ctemplate and libetpan still link
against. PDB files stay in the archive: they are needed to symbolicate production crashes.

The build uses the Windows SDK `mt.exe`. Do not replace it with Swift's `llvm-mt`: that one
depends on libxml2 and fails when the Windows profile path contains non-ASCII characters.

### Limits of the guarantee ###

The digest covers the sources, the pins and nothing else — deliberately, so that editing a
build script does not invalidate good binaries. The flip side: a script change that alters
*what lands in the archive* (adding a DLL to the install step, changing an install path)
produces different contents under an unchanged name. Re-publish the affected archives with
`-Force` when you make one. Ordinary script edits need nothing.

Everything else the digest promises is enforced rather than assumed: the pinned toolchain is
the one put on PATH, dependency checkouts are re-pointed at the pinned revisions and verified
after the build, and previous build output is deleted before a publish.

### Retention ###

Never delete a published `mailcore2-all-<digest>.zip` — revisions built against it keep
downloading it by name. Re-uploading the same digest after a rebuild is the only legitimate
replacement (`-Force`), and it is safe by construction: same digest means same sources.

### Local testing without a prebuilt ###

To test unreleased C++ changes, add `-BuildMailcore2` to the `Build-SwiftMailcore.ps1`
invocation in `Build-SparkCore.ps1` — mailcore2 is then compiled from the pinned checkout
instead of downloading the archive. It needs no credentials: the dependency archive is fetched
automatically. Slower (~10-15 min extra), for test builds only; remove it before release.

### History ###

Archives used to live in the `spark-prebuilt-binaries` S3 bucket, keyed by a version number
that had to be bumped inside the shipped tag, and the scripts lived in `build-windows-5.10/`.
Anything outside this repository that invoked them by path — `Build-SparkCore.ps1` in
spark-core-mono calls `Build-SwiftMailcore.ps1` — needs the new `windows/` path, and only from
the tag that first contains this change.
Tags published that way keep working — they run their own copy of `Get-Mailcore2.ps1` from
their own checkout — but this revision no longer has an S3 path at all. The whole arrangement
goes away when the Windows build moves to SwiftPM like the other platforms.


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
