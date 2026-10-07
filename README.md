# HEPbrew

Homebrew packages for detector software. The tap is `paulgessinger/hep`,
hosted in the GitHub repository `paulgessinger/homebrew-hep`.

## Install

After the repository is published:

```sh
brew install paulgessinger/hep/dd4hep
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
CMake and Ninja are build dependencies.
The C++ standard is read from `root-config --cxxstandard`.

Included: detector geometry, DDRec, DDDetectors, DDCond, DDAlign, DDDigi,
DDEve and utility applications, with ROOT dictionaries and Python bindings.
Geant4/DDG4, CAD/Assimp, LCIO, EDM4hep, HepMC3 and TBB integration are disabled.
The XML backend is bundled TinyXML. Upstream examples, documentation and the
upstream test suite are not built; `brew test` runs an installed-package test.

Homebrew upgrades Python patch releases independently of ROOT. A small CMake
adjustment requires the same Python major/minor as ROOT, while allowing patch
updates. It also applies to installed CMake files used by downstream projects.
The broader upstream `DD4HEP_RELAX_PYVER` switch remains disabled.
The DD4hep-only setup script also includes Homebrew ROOT's library directory,
which DD4hep's Python loader needs for dictionary autoloading in a clean shell.

For a CMake consumer:

```cmake
find_package(DD4hep REQUIRED CONFIG COMPONENTS DDCore)
target_compile_features(my_detector PRIVATE cxx_std_${DD4hep_BUILD_CXX_STANDARD})
target_link_libraries(my_detector PRIVATE DD4hep::DDCore)
```

Configure with `-DDD4hep_DIR="$(brew --prefix dd4hep)/cmake"`.

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
It also checks that the installed CMake package has no DDG4 target.

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

ROOT or Python major/minor upgrades can require a DD4hep formula revision and
new bottles. Re-run the installed-package tests when these dependencies change.
Geant4 support is deferred to a separate change.

## References

- [DD4hep](https://github.com/AIDASoft/DD4hep)
- [Homebrew tap maintenance](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Homebrew bottles](https://docs.brew.sh/Bottles)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [davidchall/homebrew-hep](https://github.com/davidchall/homebrew-hep), the inspiration for this tap
