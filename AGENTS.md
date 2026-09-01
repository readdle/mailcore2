# Working in this repository

This is Readdle's fork of MailCore 2. Most of it is the upstream C++ library; the parts we
maintain are the C wrapper (`src/c`), the Swift bindings (`src/swift`) and the Windows build
under `windows/`.

MailCore is standalone. How Spark consumes it is Spark's business — the one thing this
repository owes Windows consumers is a published prebuilt archive for every revision of the
C/C++ sources that needs one.

## Publishing the Windows prebuilt

Spark's Windows build does not compile the mailcore2 C++ from source. It downloads an archive
whose name is derived from the content of the C/C++ sources, so **sources that were never built
simply have no archive** and the Spark build says so:

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
.\windows\Setup-Machine.ps1
.\windows\Publish-Mailcore2Prebuilt.ps1
```

`Setup-Machine.ps1` reports every prerequisite and prints the install command for whatever is
missing; it changes nothing unless given `-Install`. Run it first on an unfamiliar machine,
skip it once it has come back green.

`Publish-Mailcore2Prebuilt.ps1` is the entire job. It computes the digest, exits early if that
archive already exists, verifies the toolchain against `windows\pins.json`, fetches the
dependency archive, cleans previous build output, builds, checks the install tree really came
from the pinned revisions, stamps the digest, packages, verifies the package, and uploads it as
a release asset.

**Do not commit anything to mailcore2 afterwards.** The archive is named after the sources, so
the revision that needs it will find it. Committing, opening the PR and tagging are the
developer's job, not the agent's.

### Requirements

Everything is checked by `Setup-Machine.ps1`; this is what it checks for.

- Windows machine with the toolchain pinned in `windows\pins.json` (Swift, MSVC toolset,
  Windows SDK). Those versions are not advisory — the build puts exactly them on PATH and
  refuses to run otherwise.
- `gh` authenticated as a user with write access (`gh auth login`). Nothing else: the
  repository is public, its dependencies are public, and the build needs no AWS key.
- A committed working tree. The digest describes `HEAD`, so uncommitted changes under `src`
  (excluding `src/swift`), `CMakeLists.txt` or `windows/pins.json` make the script refuse to
  run.

### When it fails

- *Uncommitted changes under …* — commit them first, or test locally by passing
  `-BuildMailcore2` to `Build-SwiftMailcore.ps1` instead of publishing.
- *MSVC toolset / Windows SDK / Swift … not found* — the machine does not match the pins. Run
  `.\windows\Setup-Machine.ps1` and follow it. Editing `windows\pins.json` to match the machine
  instead is a deliberate act: it changes the digest, so every consumer will need a new archive.
- *Could not download the dependency archive* — the build inputs (ICU, libxml2, openssl, sasl,
  zlib) are published once as `mailcore2-windows-deps-<n>.zip`. Rebuild it with
  `.\windows\New-DependenciesArchive.ps1`, publish it with
  `Publish-Mailcore2Prebuilt.ps1 -PublishDependenciesArchive <path>`, or point at a local copy
  with `-PrebuiltDependenciesArchive <path>`.
- *GitHub CLI is not authenticated* — `gh auth login`. Do not work around this with a token
  pasted into the shell.
- *`<name>-git-rev` is X but pins.json says Y* — the build used a dependency checkout at the
  wrong revision. Delete `.build\prebuilt\build-dependencies` and re-run.

### What not to do

- Do not edit the archive by hand or upload one built from an uncommitted tree.
- Do not delete a published `mailcore2-all-<digest>.zip`: revisions that were built against it
  keep downloading it by name. Re-uploading the *same* digest after a rebuild is the only
  legitimate replacement, and `-Force` exists for exactly that.
- Do not add a version number anywhere. The digest replaced it; there is nothing to bump.

### The one thing the digest does not cover

The digest is computed over `src`, `CMakeLists.txt` and `windows/pins.json` — not over the
build scripts, so that editing them does not invalidate good binaries. The cost of that choice:
**a script change that alters what lands in the archive** (adding a DLL to the install step,
changing an install path) **produces different contents under an unchanged name.** When you
make such a change, re-publish the affected archives with `-Force`. Ordinary script edits —
logging, error messages, refactoring — need nothing.

## Building without the internal RD modules

`windows\Build-Helpers.ps1` provides the subset of the internal `RDBuildCMake` / `RDBuildMSVC`
/ `RDDependency` modules that the C/C++ build uses, and `Common.ps1` dot-sources it after
importing those modules so it wins even where they are installed — the pinned toolchain has to
be the one that actually runs. A plain clone plus the pinned toolchain is enough to build and
publish the prebuilt.

The Swift build (`Build-SwiftMailcore.ps1`) is the exception: `Initialize-SDK` and
`Invoke-BuildModuleTarget` are not reimplemented, so that script still needs the real RD
modules. It runs inside the Spark CI image, which has them.
