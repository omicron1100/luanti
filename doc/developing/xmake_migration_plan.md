# Migrating Luanti off CMake to Xmake

Status: draft, for review.
Goal: a fresh clone builds, tests, installs, packages and releases Luanti with
Xmake alone. CMake is removed from the repository at the end.

This plan assumes the existing `xmake.lua` (added in `397e916d0`, cleaned up in
`a2ef60f78`) stays the single build script and is extended, not rewritten.

---

## 1. Where the migration stands today

`xmake.lua` (~1070 lines) already covers the *compile* step on Linux:

- project/version, `set_languages("c99", "gnuxx17")`, build modes including the
  custom `semidebug` mode
- ~30 configuration options (client/server/unittests/benchmarks, `run_in_place`,
  `dev_build`, `lto`, `warn_all`, all feature switches)
- dependency handling incl. bundled fallbacks (`lib/gmp` mini-gmp,
  `lib/jsoncpp`, `lib/lua`, `lib/bitop`, `lib/sha256`, `lib/lstrpack`,
  `lib/catch2`, `lib/tiniergltf`)
- `IrrlichtMt` and the client/server targets with glob-based source lists that
  mirror `src/CMakeLists.txt`
- codegen: `builtin_files.cpp` (sha256-hashed `builtin/**.lua|json`) and
  `cmake_config_githash.h`
- config header generation and capability probes (`endian.h`, `strlcpy`,
  `malloc_trim`, `ngettext`, curses headers)
- compiler/linker settings per platform (windows, mingw, macosx, bsd, haiku,
  android, wasm)

It builds locally (`bin/luanti`, `bin/luantiserver` exist). Note that xmake's
configuration lives in `.xmake/`, which is gitignored — the current local
configuration is machine-local and CI must configure from scratch.

What still belongs to CMake is everything *around* the build:

| Area | CMake-only artifact | Used by |
|---|---|---|
| Config headers | `src/cmake_config.h.in`, `lib/sha256/cmake_config.h.in`, `src/cmake_config_githash.h.in` are `#cmakedefine01` templates that `xmake.lua:add_cmake_configfile()` shims by parsing/rewriting them | xmake (temporarily), CMake |
| Generated version | `cmake/Modules/GenerateVersion.cmake` | CMake |
| Builtin hashing | `cmake/Modules/HashBuiltinFiles.cmake`, `builtin/CMakeLists.txt` `BUILTIN_SRCS` | CMake |
| Install rules | `CMakeLists.txt` install sections, `src/CMakeLists.txt` install sections, `CUSTOM_*DIR` options, legacy `minetest`/`minetestserver` aliases, `INSTALL_DEVTEST` | releases, distro packages |
| Translations | `cmake/Modules/FindGettextLib.cmake` `set_mo_paths`, `translations` target (`msgfmt`), `src/unsupported_language_list.txt` blacklist | runtime i18n |
| Packaging | CPack (ZIP/TGZ/NSIS), `misc/sfx-launcher.nsi`, `misc/meta.nsh.in`, `misc/AppImageBuilder.yml` | releases |
| Docs target | `doc/Doxyfile.in` configured with `@PROJECT_NAME_CAPITALIZED@` etc. | `BUILD_DOCUMENTATION` |
| Windows | `vcpkg.json` + vcpkg toolchain, DLL collection (vcpkg applocal / `EXTRA_DLL` / `util/bundle_dlls.sh`), `util/buildbot/*` release cross-builds, `util/buildbot/toolchain_*.cmake` | CI, releases |
| macOS | `misc/macos/Info.plist.in`, `.app` bundle layout, `fixup_bundle`, Xcode project/archive flow, `util/xcode/install_resources.cmake` | CI, releases |
| Android | `android/native/build.gradle` `externalNativeBuild.cmake` pointing at the root `CMakeLists.txt`, prebuilt deps layout | CI, Play Store |
| CI | `linux.yml`, `macos.yml`, `windows.yml`, `android.yml`, `docker_image.yml`, `cpp_lint.yml` (path filters + invocations), `util/ci/build.sh`, `build_macos.sh`, `clang-tidy.sh`, `common.sh` (installs cmake) | CI |
| Docker/Nix | `Dockerfile`, `shell.nix`, `.dockerignore` | images, dev shells |
| Docs/IDE | `doc/compiling/README.md` (CMake options), `linux.md`, `macos.md`, `windows_msvc.md`, `windows_msys2.md`, `doc/ides/{vscode,visual_studio,jetbrains}.md`, `doc/developing/os-compatibility.md`, `.vscode/` | users, contributors |
| Tooling | `util/bump_version.sh` (reads/writes `CMakeLists.txt`), `util/gather_git_credits.py`, `.editorconfig`, `.gitignore`, `CMakePresets.json` | maintainers |
| Source specifics | `USE_CMAKE_CONFIG_H` guard in `src/config.h`, `src/version.cpp`, `misc/winresource.rc` | compiled code |

Also note: `build/` currently contains a stale CMake cache (from
`util/ci/build.sh`, Nov 2025) mixed with current xmake artifacts, and
`bin/minetest` is the legacy `minetest` alias symlink that CMake's
`CreateLegacyAlias` defines — xmake must replicate that alias. Both need
cleanup/attention.

Rough size of the remaining work: the build port is ~80% done, but platform
release paths (Windows, macOS, Android) and CI are the bulk of what is left —
plan for this being a multi-week effort, with the Linux path finishable quickly.

---

## 2. Decisions to make before starting

1. **Dependency sourcing.** `xmake.lua` currently fetches/builds packages from
   `xmake-repo` when system packages are missing, while CMake relied on
   find_package/vcpkg. Recommendation:
   - Linux/BSD: prefer system packages only; fail loudly when missing, so
     distro builds never hit the network. Provide an explicit opt-in to fetch
     (`xmake f --system_deps=n` or a `pkg_policy` option).
   - Windows: decide between (a) `xmake-repo` packages (drops `vcpkg.json` and
     the vcpkg baseline, single toolchain for devs and CI) or (b) keeping vcpkg
     only as a *dependency provider*. (a) is needed to truly remove CMake but is
     the riskiest port; (b) keeps `vcpkg.json`.
   - Add a requires lock (`package.requires_lock` policy / `xmake-requires.lock`)
     for reproducibility in CI.
2. **macOS Xcode/archive flow.** CI currently builds both a Makefile build and
   an Xcode project + `luanti.xcarchive`, and diffs the two `.app`s. Xmake
   cannot produce `xcarchive`s. Recommendation: generate an Xcode project with
   `xmake project -k xcode` if a signing/archive flow is required, otherwise
   drop the Xcode leg and keep a scripted `.app` bundle + `codesign`.
3. **Android.** Gradle must stay (app packaging, Java glue). Recommendation:
   replace only `externalNativeBuild` with a Gradle `Exec` task that calls
   `xmake f -p android -a <abi> --ndk=...` and `xmake install` into
   `jniLibs`/build intermediates. Keep the prebuilt deps archive layout and
   teach xmake to find it (or move to `xmake-repo` packages for Android too).
4. **Minimum xmake version.** `xmake pack` (packaging) needs ≥ 2.9; current
   `set_xmakever("2.8.0")` is too old for the packaging phase. Recommendation:
   bump to the version the CI will pin (e.g. 2.9.x) and document install methods
   per platform.
5. **LTO default.** CMake enables LTO by default for release except
   macOS/win-gcc; xmake defaults `lto=false`. Recommendation: match CMake's
   policy initially to keep artifacts comparable, then revisit.
6. **Precompiled headers / `USE_GPROF` / `ENABLE_UPDATE_CHECKER` toggle.**
   CMake has `PRECOMPILE_HEADERS` and `USE_GPROF`; xmake has neither yet.
   Recommendation: port `USE_GPROF` (trivial), keep PCH as an optional
   `xmake` feature (`add_pcheader`) but leave it off by default, and add an
   explicit `update_checker` option instead of deriving it from `dev_build`.
7. **Sign-off for deleting CMake.** Keep CMake until xmake CI is green on all
   platforms *and* one release dry-run has been produced (see phase 6).

---

## 3. Phases

### Phase 0 — Parity baseline and safety net (small, do first)

- Add an xmake CI workflow (or jobs) that builds and runs unittests on
  Linux, macOS, Windows (mingw + MSVC), and Android **in parallel with the
  existing CMake jobs**. No deletion until all of these are green.
- Freeze "flags of record": for the reference configurations (Linux release,
  Windows release, macOS release, Android release), keep CMake build logs and
  generated headers so xmake output can be diffed against them.
- Clean the working tree: remove the stale CMake tree under `build/` (or keep
  it read-only for diffing), and reconcile `bin/` artifacts.
- Exit criteria: xmake jobs exist and pass on all CI platforms; reference
  artifacts archived.

### Phase 1 — Make xmake self-contained for the build (small/medium)

Remove the last build-time dependency on CMake templates.

1. Add native templates, e.g. `src/luanti_config.h.in` and
   `lib/sha256/luanti_config.h.in` (or `.config.h.in`) using plain `@VAR@`
   placeholders only, and generate them from Lua values (the values are already
   computed in `configure_target()`), including 0/1 booleans.
2. Delete the `#cmakedefine01` rewriting shim (`add_cmake_configfile()` in
   `xmake.lua`) and the intermediate `build/xmake-templates` trick.
3. Rename the generated header away from `cmake_config.h` /
   `cmake_config_githash.h` (e.g. `luanti_config.h`, `luanti_config_githash.h`)
   and simplify the `USE_CMAKE_CONFIG_H` indirection in:
   - `src/config.h` (always include the generated header; drop the `#warning`)
   - `src/version.cpp`
   - `misc/winresource.rc` (drop the define dance)
   - `xmake.lua`'s `target:add("defines", "USE_CMAKE_CONFIG_H")`
   - `.gitignore` entries for `src/cmake_config*.h`
4. Make `xmake.lua` the single source of truth for the version: remove the
   hardcoded duplicate in `util/bump_version.sh` reading `CMakeLists.txt`
   (phase 4 item, but keep in sync until then).
5. Keep `xmake build` output identical in behavior: run unittests and compare
   `--version` / `g_build_info` against a CMake build.
- Exit criteria: no file under `cmake/` is read by xmake; config header values
  match the reference build; unittests pass.

### Phase 2 — Build/install/package feature parity (medium)

1. **Translations.** Port `FindGettextLib.cmake`'s `set_mo_paths` +
   `translations` target into `xmake.lua`:
   - probe for `msgfmt` (disable gettext with a warning if absent, as CMake
     effectively does),
   - compile `po/<lang>/luanti.po` → `locale/<lang>/LC_MESSAGES/luanti.mo`,
     honoring `src/unsupported_language_list.txt`,
   - write into the source `locale/` for `run_in_place` builds and into the
     build dir otherwise,
   - hook it into the client/server build the way CMake's `ALL`-target did.
   (`android/app/build.gradle` has its own msgfmt loop; keep until phase 3.)
2. **Install rules.** Implement `on_install` / `add_installfiles` for:
   - binaries + `minetest`/`minetestserver` legacy aliases, plus the symlink in
     the build output dir (replaces `CreateLegacyAlias`),
   - `builtin/`, `client/shaders`, `textures/base/pack`, `fonts/*.ttf|txt`,
     `clientmods` + `client/serverlist` (run_in_place only), `locale/*.mo`,
     docs (`README.md`, `doc/lua_api.md`, `client_lua_api.md`,
     `menu_lua_api.md`, `texture_packs.md`, `world_format.md`),
     `minetest.conf.example`, man pages, desktop file, metainfo, hicolor icons,
   - Windows layout (`SHAREDIR="."`, `BINDIR="bin"`, …), macOS `.app` layout,
     Linux `GNUInstallDirs` layout,
   - `CUSTOM_SHAREDIR/BINDIR/DOCDIR/MANDIR/EXAMPLE_CONF_DIR/XDG_APPS_DIR/ICONDIR/LOCALEDIR`
     equivalents, `INSTALL_DEVTEST`, and the `STATIC_SHAREDIR`/`STATIC_LOCALEDIR`
     config values staying consistent with where files land.
3. **Packaging.** Reproduce, via `xmake pack` (confirmed formats include
   `zip`, `targz`, `tarxz`, `nsis`) and/or small scripts:
   - Linux TGZ, Windows/macOS ZIP (name pattern `luanti-<version>-<os>`),
   - Windows NSIS flow: `misc/meta.nsh.in` needs a non-CMake generator
     (xmake config var substitution) and the zip → `makensis sfx-launcher.nsi`
     step must be driven by a script,
   - AppImage recipe (`misc/AppImageBuilder.yml`) rewritten to call xmake.
4. **Doxygen.** Replace `doc/Doxyfile.in` configuration with an xmake
   `on_install`-independent target/rule (or a small script) that fills in
   project name/version/paths. Provide `xmake build doc` or similar.
5. **Extras:** `USE_GPROF`, explicit `update_checker` option, and decide on LTO
   default (see decisions).
- Exit criteria: `xmake -m release build`, `xmake install -o <prefix>`
  produce trees that `diff -r` clean (modulo timestamps) against
  `cmake --install`, and packaged archives match CPack archives in layout;
  client runs translated UI from installed tree.

### Phase 3 — Platform parity (large; can run in parallel once phase 2 lands)

**Windows**
- MinGW cross builds: replace `util/buildbot/toolchain_*.cmake` with
  `xmake f -p mingw -a x86_64 --toolchain=llvm-mingw` style config; port
  `util/buildbot/buildwin{32,64}.sh` and `common.sh` (library downloads +
  `add_cmake_libs`) to xmake config, preserving the pinned library versions and
  sha256 checks; produce the same packaged ZIPs and NSIS payloads.
- DLL bundling: replicate `EXTRA_DLL`/`bundle_dlls.sh`/vcpkg-applocal behavior
  in `on_install` (copy runtime DLLs next to the binaries).
- MSVC: xmake-repo packages (decision 1) and the same `luanti.exe` resource
  flow (`misc/winresource.rc` already compiles under xmake for windows/mingw).
- Keep `misc/luanti.exe.manifest` wiring.

**macOS**
- `.app` bundle assembly: `Info.plist` generation (port `Info.plist.in` to an
  xmake-configured file), `Contents/MacOS` + `Contents/Resources` layout,
  icon, and dylib fixup (replace `fixup_bundle` with `install_name_tool`/
  `otool` scripting or xmake's package install).
- Deps: keep using the precompiled static deps archive
  (`luanti_macos_deps`) by exposing search paths via a config option, mirroring
  `util/ci/build_macos.sh`'s explicit library paths; or move to xmake-repo.
- Decide on Xcode project/archive support (decision 2) and update
  `macos.yml` accordingly (bundle diff test can compare xmake vs CMake output
  during migration).

**Android**
- Replace `externalNativeBuild` in `android/native/build.gradle` with an xmake
  invocation per ABI (or a single multi-ABI loop task) writing `libluanti.so`
  into the Gradle intermediates/jniLibs.
- Keep the `luanti_android_deps` download task; point xmake at the extracted
  include/lib dirs.
- Keep Java/JNI glue and `prepareAssets` untouched except for dropping the
  `**/CMakeLists.txt` exclusion once the files are gone.
- Verify all four ABIs in CI and check asset locale generation (gradle's
  `msgfmt` loop can later reuse the xmake translations output).

**Others (BSD/Haiku/WASM):** xmake branches exist but are untested; no CMake CI
exists either. Treat as best-effort, document under "untested platforms".

- Exit criteria: Windows/macOS/Android CI jobs produce runnable artifacts
  (wine run, unittests, APK install smoke test) equivalent to today's.

### Phase 4 — Tooling, CI and containers (medium)

- `util/ci/build.sh` → xmake (`xmake f … && xmake build`), including the
  `CMAKE_FLAGS` env contract (rename to `XMAKE_FLAGS` or map old vars).
- `util/ci/build_macos.sh` → xmake with `DEPS_DIR`.
- `util/ci/clang-tidy.sh` → `xmake project -k compile_commands` (optionally
  `--lsp=clangd`; note the output path differs from CMake's `build/`) + existing
  `run-clang-tidy.py`; drop the
  `GenerateVersion GenerateBuiltinFilesCpp` target call (use
  `xmake build luanti_codegen` equivalent).
- `util/ci/common.sh` → drop `cmake` from apt/brew lists; keep gettext.
- `util/bump_version.sh` → read/write `xmake.lua` (version locals +
  `dev_build` default), keep `android/build.gradle` and doc version updates.
- `util/gather_git_credits.py` → stop expecting `CMakeLists.txt`/`.cmake`.
- Workflows: update `paths:` filters (`**/CMakeLists.txt`, `cmake/Modules/**` →
  `xmake.lua`, `xmake/**` if scripts are split out), replace CMake steps with
  xmake in `linux.yml`, `macos.yml`, `windows.yml`, `android.yml`,
  `docker_image.yml`, `cpp_lint.yml`; add xmake install action
  (`xmake-io/github-action-setup-xmake`) and package cache keyed on
  `xmake.lua`/lock file.
- `Dockerfile`: install xmake, build server with xmake, adjust
  `cmake --install` → `xmake install`; the prometheus-cpp/libspatialindex/
  LuaJIT third-party builds inside the image can stay on their own build
  systems, or move to xmake-repo if a "no cmake anywhere" image is wanted.
- `shell.nix`: replace `pkgs.cmake` with `pkgs.xmake`.
- `.gitignore`: drop CMake entries, keep `build/`, `.xmake/`; add generated
  config header names.
- `.editorconfig`: `*.cmake` pattern can go.
- `CMakePresets.json`/`vcpkg.json`: delete when their consumers are gone.

### Phase 5 — Documentation and IDE support (small)

- `doc/compiling/README.md`: rewrite the options table as xmake options with an
  old→new mapping (`-DBUILD_SERVER=TRUE` → `xmake f --server=y`, etc.).
- `doc/compiling/linux.md`, `macos.md`, `windows_msvc.md`, `windows_msys2.md`:
  xmake configure/build/install/run/test commands; dependency install lists
  without cmake, plus xmake itself.
- `doc/ides/vscode.md`, `visual_studio.md`, `jetbrains.md`: xmake workflows
  (`xmake project -k compile_commands|vsxmake|xcode`, xmake VS Code plugin).
- `.vscode/extensions.json`: add the xmake extension.
- `doc/developing/os-compatibility.md`: build-tool requirements (xmake version
  instead of CMake versions).
- `doc/Doxyfile.in` consumers: update developer docs that mention
  `-DBUILD_DOCUMENTATION`.

### Phase 6 — Remove CMake (small but irreversible; do last)

Delete, in reviewable chunks:

- all 45 `CMakeLists.txt` files (root, `src/**`, `lib/**`, `irr/**`,
  `builtin/**`), `cmake/` (14 modules incl. `GenerateVersion.cmake`,
  `HashBuiltinFiles.cmake`), `CMakePresets.json`, `vcpkg.json`,
  `util/buildbot/toolchain_*.cmake`, `util/xcode/` (`.cmake` scripts),
  `src/cmake_config*.h.in`, `lib/sha256/cmake_config.h.in`.
- remaining `USE_CMAKE_CONFIG_H` references and `cmake_config*.h` names.
- update `README.md`/`doc/*` links that pointed at CMake files.

Then run the acceptance test: a container/VM **without cmake installed**
(config build-essential, deps, xmake only) must build, test, install and
package from a clean clone on Linux, macOS and Windows.

### Phase 7 — Release dry-run and stabilization

- Cut one release (or dry-run of `util/bump_version.sh` + buildbot scripts +
  AppImage + NSIS) entirely on xmake; compare artifacts against the previous
  CMake release.
- Keep the old CMake build instructions in a git tag/commit message for
  archaeology; no need to keep dead files around.

---

## 4. Verification checklist (use throughout)

- [ ] `xmake f -m release && xmake build` on Linux/macOS/Windows/Android CI
- [ ] client and server unittests pass (`--run-unittests`), including the
      `nowrite`-directory test behavior
- [ ] `g_build_info` / `--version` output matches reference builds
      (config header values, version string, `RUN_IN_PLACE`, features)
- [ ] `xmake install -o <prefix>` tree diffs clean against `cmake --install`
- [ ] packaged archives (zip/tgz/nsis/appimage) match layout and run
- [ ] runtime tests: `util/test_singleplayer.sh` (GLES + GL3),
      `util/test_multiplayer.sh`, `util/test_error_cases.sh`
- [ ] translation smoke test: launch with a non-English locale from the
      installed tree
- [ ] no `cmake` binary on PATH during the final acceptance run
- [ ] release scripts (`util/buildbot/buildwin*.sh`, AppImage recipe) run
      end-to-end

## 5. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Windows MSVC dependency sourcing without vcpkg | blocks MSVC CI/release | phase 0 CI job validates xmake-repo MSVC build early; keep vcpkg fallback until proven |
| macOS Xcode/archive flow has no direct xmake equivalent | blocks macOS release if App Store/signing flow is required | decide early (decision 2); `xmake project -k xcode` as interim |
| xmake behaviors differ subtly (flags, warnings, defines) | runtime/ABI differences | diff generated headers and install trees; keep CMake artifacts as reference during migration |
| Distro packaging expects no network fetches | packagers can't build | system-only dependency mode + documented override |
| Android prebuilt deps layout not understood by xmake | Android build breaks | keep deps layout, add explicit search-path options; validate early in phase 0 CI |
| Duplicate version numbers in `xmake.lua` and `CMakeLists.txt` drift during migration | bogus version strings | make xmake.lua authoritative in phase 1 and update `bump_version.sh` immediately |
| Local build dirs are polluted (`build/` mixes CMake + xmake) | confusing failures | document `xmake f -c` / clean-clone validation; keep `build/` and `out/` ignored |

## 6. Quick command mapping (for docs/CI rewrites)

| CMake | Xmake |
|---|---|
| `cmake -B build -DCMAKE_BUILD_TYPE=Debug` | `xmake f -m debug` |
| `cmake -B build -DRUN_IN_PLACE=TRUE` | `xmake f --run_in_place=y` |
| `cmake -B build -DBUILD_SERVER=TRUE -DBUILD_CLIENT=FALSE` | `xmake f --client=n --server=y` |
| `cmake -B build -DENABLE_CURL=0 -DENABLE_SOUND=0` | `xmake f --curl=n --sound=n` |
| `cmake --build build -j$(nproc)` | `xmake build -j$(nproc)` |
| `cmake --build build --target luanti` | `xmake build luanti` |
| `cmake --install build --prefix /usr/local` | `xmake install -o /usr/local` |
| `cpack -G TGZ` | `xmake pack -f targz` (verify per platform) |
| `./bin/luanti --run-unittests` | `xmake run luanti --run-unittests` |
| `cmake . -LH` | `xmake f --menu` / `xmake show` |
