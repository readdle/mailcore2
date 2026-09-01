# Working in this repository

This is Readdle's fork of MailCore 2. Most of it is the upstream C++ library; the parts we
maintain are the C wrapper (`src/c`), the Swift bindings (`src/swift`) and the Windows build
under `build-windows-5.10`.

## Publishing the Windows prebuilt

Spark's Windows build does not compile the mailcore2 C++ from source. It downloads a prebuilt
archive whose name is derived from the content of the C/C++ sources, so **sources that were
never built simply have no archive** and the Spark build says so:

```
Prebuilt MailCore not found: mailcore2-all-<digest>.zip
Have you built and uploaded it yet?
```

There is no Windows CI. When that error appears, someone has to build and publish from a
Windows machine — that is what "build and upload the Windows changes" means.

### The whole procedure

On a Windows machine, in a checkout of this repository **at the revision that needs the
prebuilt** (a branch head, a tag, anything committed):

```powershell
.\build-windows-5.10\Publish-Mailcore2Prebuilt.ps1
```

That is the entire job. The script computes the digest, checks whether that archive already
exists (if so it exits without building), verifies the toolchain against
`windows-build-pins.json`, builds, stamps the digest into the install tree, packages, verifies
the package, and uploads it as a release asset.

**Do not commit anything to mailcore2 afterwards.** The archive is named after the sources, so
the revision that needs it will find it. Committing, opening the PR and tagging are the
developer's job, not the agent's.

### Requirements

- Windows machine with the toolchain listed in `windows-build-pins.json` (Swift, MSVC toolset,
  Windows SDK). The versions are pinned because they change the binaries.
- `gh` authenticated as a user with write access (`gh auth login`). Nothing else: the
  repository is public, its dependencies are public, and the build needs no AWS key.
- A committed working tree. The digest describes `HEAD`, so uncommitted changes under `src`,
  `CMakeLists.txt` or `windows-build-pins.json` make the script refuse to run.

### When it fails

- *Uncommitted changes under …* — commit them first, or test locally by passing
  `-BuildMailcore2` to `Build-SwiftMailcore.ps1` instead of publishing.
- *MSVC toolset / Windows SDK / Swift … not found* — the machine does not match the pins.
  Install the pinned version. Changing `windows-build-pins.json` is a deliberate act: it
  changes the digest, so every consumer will need a new archive.
- *Could not download the dependency archive* — the build inputs (ICU, libxml2, openssl, sasl,
  zlib) are published once as `mailcore2-windows-deps-<n>.zip`. Publish it with
  `-PublishDependenciesArchive <path>` or point at a local copy with
  `-PrebuiltDependenciesArchive <path>`.
- *GitHub CLI is not authenticated* — `gh auth login`. Do not work around this with a token
  pasted into the shell.

### What not to do

- Do not edit the archive by hand or upload one built from an uncommitted tree.
- Do not delete or overwrite a published `mailcore2-all-<digest>.zip`: revisions that were
  built against it keep downloading it by name. Re-uploading the *same* digest after a rebuild
  is the only legitimate replacement.
- Do not add a version number anywhere. The digest replaced it; there is nothing to bump.

## Building without the internal RD modules

`build-windows-5.10/Build-Helpers.ps1` provides the small subset of the internal
`RDBuildCMake` / `RDBuildMSVC` / `RDDependency` modules that this build uses, and is loaded
automatically when they are absent. A plain clone plus the pinned toolchain is enough to build.
