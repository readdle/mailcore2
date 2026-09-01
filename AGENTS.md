# Working in this repository

This is Readdle's fork of MailCore 2. Most of it is the upstream C++ library; the parts we
maintain are the C wrapper (`src/c`), the Swift bindings (`src/swift`) and the Windows build
under `build-windows-5.10`.

## Publishing the Windows prebuilt

Spark's Windows build does not compile the mailcore2 C++ from source. It downloads an archive
whose name is derived from the content of the C/C++ sources, so **sources that were never built
simply have no archive** and the Spark build says so:

```
Prebuilt MailCore not found: mailcore2-windows-<digest>.zip
Have you built and uploaded it yet?
```

There is no Windows CI. The `mailcore2 - Windows prebuilt` pull-request check asks the same
question earlier, on every pull request, and goes red when the answer is no. Either way,
someone has to build and publish from a Windows machine — that is what "build and upload the
Windows changes" means.

You can ask the same question yourself, from anywhere, without a Windows machine:

```powershell
pwsh ./build-windows-5.10/Check-PrebuiltPublished.ps1
```

### The whole procedure

On a Windows build machine, in a checkout of this repository **at the revision that needs the
prebuilt** (a branch head, a tag, anything committed):

```powershell
.\build-windows-5.10\Publish-Mailcore2Prebuilt.ps1
```

That is the entire job. It computes the digest, exits early if that archive already exists,
fetches the dependency archive, clears the previous build output, builds through
`Build-Mailcore2.ps1`, stamps the digest, packages, verifies the package, and adds it to the
release.

**Do not commit anything to mailcore2 afterwards.** The archive is named after the sources, so
the revision that needs it will find it. Committing, opening the PR and tagging are the
developer's job, not the agent's.

### The release

Archives live on the permanent `windows-prebuilt` release, set up by hand once.
`Publish-Mailcore2Prebuilt.ps1` only adds `mailcore2-windows-<digest>.zip` to it. If it is
somehow missing, say so rather than creating one.

### Requirements

The same machine that has always built mailcore2 for Windows: the toolchain the build expects
(Swift for Windows, VS 2022 Build Tools, the Windows SDK) and the internal RD PowerShell
modules. Nothing about the build changed.

What did change: no AWS credential. `SPARK_PREBUILT_KEY` is gone, and the three binaries it
used to fetch travel as one public asset on the release. Publishing additionally needs `gh`
authenticated as a user with write access (`gh auth login`).

The working tree must be committed. The digest describes `HEAD`, so uncommitted changes under
`src` (excluding `src/swift`), `CMakeLists.txt` or `build-windows-5.10` make the script refuse
to run.

### When it fails

- *Uncommitted changes under …* — commit them first, or test locally by passing
  `-BuildMailcore2` to `Build-SwiftMailcore.ps1` instead of publishing.
- *The windows-prebuilt release does not exist* — ask the developer; see "The release" above.
- *Could not download the dependency archive* — `mailcore2-windows-deps-<n>.zip` carries
  openssl, sasl and zlib and is attached to the release by hand. If it is not there, ask the
  developer to attach it, or point at a local copy with `-PrebuiltDependenciesArchive <path>`.
- *GitHub CLI is not authenticated* — `gh auth login`. Do not work around this with a token
  pasted into the shell.
- Anything about ICU, libxml2 or the toolchain — that is the build machine's setup, unchanged by
  this flow. Do not try to install or relocate it.

### What not to do

- Do not edit the archive by hand or upload one built from an uncommitted tree.
- Do not delete a published `mailcore2-windows-<digest>.zip`: revisions that were built against
  it keep downloading it by name. Re-uploading the *same* digest after a rebuild is the only
  legitimate replacement, and `-Force` exists for exactly that.
- Do not create the release or attach the dependency archive. Both are the developer's.
- Do not add a version number anywhere. The digest replaced it; there is nothing to bump.

### What the digest covers

`src` (without `src/swift`), `CMakeLists.txt`, and `build-windows-5.10` — the scripts included,
because they decide what gets compiled, which project files and redistributables get copied in,
and what ends up in the package. So there is no way to change the contents of an archive without
changing its name.

The price is the other direction: editing any script here, even a message or the pull-request
check, produces a new digest and asks for a rebuild. Expect that, and prefer to land script edits
together with whatever else needs republishing.
