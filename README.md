# HEPbrew

Homebrew packages for detector software. The tap is `paulgessinger/hep`,
hosted in the GitHub repository `paulgessinger/homebrew-hep`.

## Install

After the repository is published:

```sh
brew install paulgessinger/hep/dd4hep
source "$(brew --prefix geant4)/bin/geant4.sh"
source "$(brew --prefix dd4hep)/bin/thisdd4hep_only.sh"
"$(brew --prefix python@3.14)/bin/python3.14" -c 'import dd4hep'
```

The setup script supports bash and zsh and sets the paths required for DD4hep
plugins and Python bindings. Use `thisdd4hep_only.sh`: ROOT is already provided
by Homebrew and does not need the full upstream environment setup script.
DD4hep is keg-only because its `JSON` headers collide with jsoncpp's `json`
headers on case-insensitive filesystems. The setup script adds its tools to PATH;
do not force-link the package over another package's headers.

Homebrew automatically uses a matching published bottle, otherwise it builds
from source. The initial CI target is Apple Silicon on macOS 26 (`arm64_tahoe`).
Intel macOS and Linux are not yet validated.

## DD4hep

The formula packages DD4hep 1.38.0 (upstream tag `v01-38`) against Homebrew's
`root`, `boost`, `python@3.14`, and `vdt` (linked through ROOT's exported targets).
Simulation uses this tap's `paulgessinger/hep/geant4` formula.
CMake and Ninja are build dependencies.
The C++ standard is read from `root-config --cxxstandard`.

Included: detector geometry, DDRec, DDDetectors, DDCond, DDAlign, DDDigi,
DDEve, Geant4/DDG4 simulation and utility applications, with ROOT dictionaries
and Python bindings. CAD/Assimp, LCIO, EDM4hep, HepMC3 and TBB integration are disabled.
The XML backend is bundled TinyXML. Upstream examples, documentation and the
upstream test suite are not built; `brew test` runs an installed-package test.

Homebrew upgrades Python patch releases independently of ROOT. A small CMake
adjustment requires the same Python major/minor as ROOT, while allowing patch
updates. It also applies to installed CMake files used by downstream projects.
The broader upstream `DD4HEP_RELAX_PYVER` switch remains disabled.
The DD4hep-only setup script includes ROOT and Geant4 library paths and Geant4
headers for dictionary autoloading. Source `geant4.sh` first to configure the
physics datasets for simulation.

For a CMake consumer:

```cmake
find_package(DD4hep REQUIRED CONFIG COMPONENTS DDCore)
target_compile_features(my_detector PRIVATE cxx_std_${DD4hep_BUILD_CXX_STANDARD})
target_link_libraries(my_detector PRIVATE DD4hep::DDCore)
```

Configure with `-DDD4hep_DIR="$(brew --prefix dd4hep)/cmake"`.
Simulation clients can also request the `DDG4` component and link `DD4hep::DDG4`.

## Geant4

```sh
brew install paulgessinger/hep/geant4
source "$(brew --prefix geant4)/bin/geant4.sh"
```

Geant4 11.4.3 is built with C++20, shared libraries, multithreading and GDML
support through Xerces-C. It uses upstream's bundled CLHEP and PTL, and Homebrew
Expat and zlib. The exported CMake package records these dependency locations
to avoid macOS SDK header-ordering problems. Qt and OpenGL visualization are disabled.
The thread-local storage model is `global-dynamic`, as required by DD4hep's
plugin-based simulation integration.

All twelve standard physics datasets are installed under
`$(brew --prefix geant4)/share/geant4/data`. They are pinned Homebrew resources
with SHA-256 checksums, so neither the CMake build nor the first simulation
downloads data. The optional TENDL, NuDEXLib and URRPT datasets are not included.
The datasets make the download and installed package substantially larger than
the libraries alone.

For CMake clients, use `find_package(Geant4 REQUIRED gdml multithreaded)` and
configure with `-DGeant4_DIR="$(brew --prefix geant4)/lib/cmake/Geant4"`.
The formula test builds a separate CMake client, writes a water geometry to
GDML, and transports five photons with FTFP_BERT using two worker threads.

This product includes software developed by Members of the Geant4
Collaboration (https://cern.ch/geant4). The upstream Geant4 Software License
is installed with the package.

## Local development

To work directly from a checkout, register it as a local tap. If the tap is
already installed, edit its existing checkout instead of creating the symlink:

```sh
mkdir -p "$(brew --repository)/Library/Taps/paulgessinger"
ln -s "$PWD" "$(brew --repository)/Library/Taps/paulgessinger/homebrew-hep"
brew install --build-bottle paulgessinger/hep/dd4hep
brew test paulgessinger/hep/dd4hep
brew audit --strict paulgessinger/hep/dd4hep
brew style Formula/dd4hep.rb
```

For ordinary source rebuilds, use
`brew reinstall --build-from-source paulgessinger/hep/dd4hep`. To prepare a new
local bottle, uninstall DD4hep first and install it again with `--build-bottle`.
Homebrew may upgrade dependencies during builds.

The formula test compiles a separate CMake consumer, loads a compact XML
geometry through the installed `DD4hep_BoxSegment` plugin, checks its geometry,
then loads the same geometry using Python after sourcing the setup script.
It also links the installed `DD4hep::DDG4` target, then uses DDG4's Python
bindings to convert that geometry to Geant4, transport three photons with
FTFP_BERT, and verify three events in the ROOT output file.

## Bottles on GitHub Packages

The workflows are adapted from `brew tap-new --github-packages`:

- `tests.yml`: syntax checks on main and PRs; PR builds run `brew test-bot`,
  which builds, tests and bottles changed formulae and uploads bottle artifacts.
- `publish.yml`: manually dispatch **brew pr-pull** with the PR number and its
  exact head SHA after all checks pass. It publishes bottles to GHCR, incorporates
  the PR and bottle metadata, and pushes the resulting commits to `main`.
- Dependabot maintains the pinned GitHub Actions versions.

The bottle root is `https://ghcr.io/v2/paulgessinger/hep`. Publishing uses
the repository's `GITHUB_TOKEN` with `packages: write` and `contents: write`;
no personal token is configured. Repository rules must permit the publishing
workflow to push to `main`.

For the first release:

1. Create the public `paulgessinger/homebrew-hep` repository and put the
   scaffolding/workflows on `main`.
2. Add the DD4hep formula in a PR so the workflow has a formula change to build.
3. Wait for the PR checks, then dispatch **brew pr-pull** with the PR number and
   reviewed head SHA. Let that workflow incorporate the PR; do not merge it first.
4. Check the GHCR package's visibility and set it to **public** if necessary so
   users can download bottles anonymously.
5. Verify installation on a clean Apple Silicon macOS 26 machine uses the bottle.

There is intentionally no `bottle do` block until real bottles have been
published. The publishing workflow adds their URLs and checksums.

Each formula has its own bottle. The current CI runs one job per platform,
building changed formulae in dependency order. Dependencies with compatible
published bottles are installed from those bottles; they do not need to be
compiled again. Separate jobs can also exchange bottle artifacts, provided
the downstream job installs the matching dependency bottle before building.
Until the Geant4 bottle is published, fresh DD4hep builds compile it from source.

ROOT or Python major/minor upgrades can require a DD4hep formula revision and
new bottles. Re-run the installed-package tests when these dependencies change.
Geant4 upgrades can also require rebuilding and retesting DD4hep.

## References

- [DD4hep](https://github.com/AIDASoft/DD4hep)
- [Geant4](https://github.com/Geant4/geant4)
- [Homebrew tap maintenance](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Homebrew bottles](https://docs.brew.sh/Bottles)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [davidchall/homebrew-hep](https://github.com/davidchall/homebrew-hep), the inspiration for this tap
