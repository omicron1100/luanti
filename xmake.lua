-- Luanti build script for Xmake.

local VERSION_MAJOR = 5
local VERSION_MINOR = 18
local VERSION_PATCH = 0
local VERSION = string.format(
    "%d.%d.%d",
    VERSION_MAJOR,
    VERSION_MINOR,
    VERSION_PATCH
)

set_project("luanti")
set_version(VERSION)
set_xmakever("2.8.0")

set_languages("c99", "gnuxx17")

if is_plat("android") then
    add_cxflags("-fPIC")
end

-- Build modes
add_rules("mode.debug", "mode.release", "mode.releasedbg", "mode.minsizerel")

rule("mode.semidebug")
    on_config(function (target)
        if is_mode("semidebug") then
            target:set("optimize", "fast")
            target:set("symbols", "debug")
            target:set("warnings", "all")
        end
    end)
rule_end()
add_rules("mode.semidebug")

if not get_config("mode") then
    set_defaultmode("release")
end

-- ============================================================================
-- Configuration options
-- ============================================================================
option("client",         {default = true,  showmenu = true, description = "Build client"})
option("server",         {default = false, showmenu = true, description = "Build server"})
option("unittests",      {default = true,  showmenu = true, description = "Build unittests"})
option("benchmarks",     {default = false, showmenu = true, description = "Build benchmarks"})
option("run_in_place",   {default = is_plat("windows", "mingw"), showmenu = true, description = "Run directly in the source tree"})
option("dev_build",      {default = true,  showmenu = true, description = "Development build"})
option("version_extra",  {default = "",    showmenu = true, description = "Suffix to append to the version string"})
option("lto",            {default = false, showmenu = true, description = "Enable link-time optimization"})
option("warn_all",       {default = true,  showmenu = true, description = "Enable warnings in release builds"})

-- Dependencies and features
option("system_gmp",     {default = true,  showmenu = true, description = "Use GMP from the system"})
option("system_jsoncpp", {default = true,  showmenu = true, description = "Use JsonCpp from the system"})
option("luajit",         {default = true,  showmenu = true, description = "Enable LuaJIT support"})
option("curl",           {default = true,  showmenu = true, description = "Enable cURL support"})
option("gettext",        {default = true,  showmenu = true, description = "Use GetText for internationalization"})
option("sound",          {default = true,  showmenu = true, description = "Enable sound"})
option("curses",         {default = false, showmenu = true, description = "Enable the ncurses console"})
option("postgresql",     {default = true,  showmenu = true, description = "Enable the PostgreSQL backend"})
option("leveldb",        {default = true,  showmenu = true, description = "Enable the LevelDB backend"})
option("redis",          {default = true,  showmenu = true, description = "Enable the Redis backend"})
option("prometheus",     {default = false, showmenu = true, description = "Enable Prometheus client support"})
option("spatial",        {default = true,  showmenu = true, description = "Enable the SpatialIndex AreaStore backend"})
option("openssl",        {default = true,  showmenu = true, description = "Use OpenSSL libcrypto for faster SHA"})
option("tracy",          {default = false, showmenu = true, description = "Build the Tracy profiler client"})

-- Irrlicht and graphics
option("sdl3",           {default = false, showmenu = true, description = "Use SDL3 instead of SDL2"})
option("opengl",         {default = not is_plat("android", "wasm"), showmenu = true, description = "Enable legacy OpenGL"})
option("opengl3",        {default = not is_plat("android"), showmenu = true, description = "Enable OpenGL 3+"})
option("gles2",          {default = is_plat("android", "wasm"), showmenu = true, description = "Enable OpenGL ES 2+"})

-- ============================================================================
-- Dependencies
-- ============================================================================

-- Packages with a bundled fallback.
local FALLBACK_PACKAGES = {
    {option = "system_gmp",     package = "gmp",     bundled = "gmp_bundled",     config = "USE_SYSTEM_GMP",     system = true},
    {option = "system_jsoncpp", package = "jsoncpp", bundled = "jsoncpp_bundled", config = "USE_SYSTEM_JSONCPP", system = true},
    {option = "luajit",         package = "luajit",  bundled = "lua_bundled",     config = "USE_LUAJIT"}
}

-- Optional engine features.
local FEATURES = {
    {option = "curl",       package = "libcurl",         requirement = "libcurl >=7.28.0", config = "USE_CURL"},
    {option = "curses",     package = "ncurses",                                            config = "USE_CURSES"},
    {option = "postgresql", package = "postgresql",                                         config = "USE_POSTGRESQL"},
    {option = "leveldb",    package = "leveldb",                                            config = "USE_LEVELDB"},
    {option = "redis",      package = "hiredis",                                            config = "USE_REDIS"},
    {option = "prometheus", package = "prometheus-cpp",                                     config = "USE_PROMETHEUS"},
    {option = "spatial",    package = "libspatialindex",                                    config = "USE_SPATIAL"},
    {option = "openssl",    package = "openssl3",                                           config = "USE_OPENSSL"},
    {option = "tracy",      package = "tracy",                                              config = "BUILD_WITH_TRACY"}
}

add_requires("zlib", "zstd", "sqlite3")

for _, dependency in ipairs(FALLBACK_PACKAGES) do
    if has_config(dependency.option) then
        add_requires(dependency.package, {
            optional = true,
            system = dependency.system
        })
    end
end

for _, feature in ipairs(FEATURES) do
    if has_config(feature.option) then
        -- Match CMake: a feature whose dependency is unavailable is disabled
        -- with a warning instead of failing the whole configuration.
        add_requires(feature.requirement or feature.package, {optional = true})
    end
end

-- gettext may live in libc (glibc), in which case no package is needed.
if has_config("gettext") then
    add_requires("libintl", {optional = true})
end

if has_config("client") then
    add_requires("libjpeg", "libpng", "freetype", "libzip >=1.7.2")
    add_requires(has_config("sdl3") and "libsdl3" or "libsdl2")

    if has_config("opengl") then
        add_requires("opengl")
    end

    if has_config("sound") then
        -- Disable sound rather than fail if OpenAL/Vorbis are unavailable,
        -- like the CMake build does.
        add_requires("openal-soft", "libvorbis", "libogg", {optional = true})
    end
end

if has_config("lto") then
    set_policy("build.optimization.lto", true)
end

-- ============================================================================
-- Helpers
-- ============================================================================

local MODE_NAMES = {
    debug = "Debug",
    release = "Release",
    releasedbg = "RelWithDebInfo",
    minsizerel = "MinSizeRel",
    semidebug = "SemiDebug"
}

local function version_string()
    local version = VERSION
    local extra = get_config("version_extra") or ""

    if extra ~= "" then
        version = version .. "-" .. extra
    elseif has_config("dev_build") then
        version = version .. "-dev"
    end

    if is_mode("debug") then
        version = version .. "-debug"
    end

    return version
end

local function package_enabled(option, package)
    return has_config(option) and has_package(package)
end

local function sound_enabled()
    return has_config("sound")
        and has_package("openal-soft")
        and has_package("libvorbis")
        and has_package("libogg")
end

local function warnings_enabled()
    local release_like = is_mode("release", "releasedbg", "minsizerel")
    return not release_like or has_config("warn_all")
end

local function set_bool_config(target, name, value)
    target:set("configvar", name, value and 1 or 0)
end

local function read_project_file(relative, runtime)
    local filename = runtime.path.join(runtime.os.projectdir(), relative)
    local content = runtime.io.readfile(filename)

    if not content then
        runtime.raise("Cannot read template: %s", filename)
    end

    return content
end

-- CMake-compatible config headers. The CMake templates stay authoritative
-- until the CMake build is removed.
local function add_cmake_configfile(target, template, filename, runtime)
    local content = read_project_file(template, runtime)

    content = content:gsub(
        "#cmakedefine01[ \t]+([%w_]+)",
        function (name)
            return "#define " .. name .. " @" .. name .. "@"
        end
    )

    content = content:gsub(
        "#cmakedefine[ \t]+([%w_]+)([^\r\n]*)",
        function (name, suffix)
            return table.concat({
                "#if @" .. name .. "@",
                "#define " .. name .. suffix,
                "#endif"
            }, "\n")
        end
    )

    local intermediate = runtime.path.join(
        runtime.path.absolute(target:autogendir(), runtime.os.projectdir()),
        "cmake-templates",
        template
    )

    runtime.os.mkdir(runtime.path.directory(intermediate))

    if not runtime.os.isfile(intermediate)
        or runtime.io.readfile(intermediate) ~= content then
        runtime.io.writefile(intermediate, content)
    end

    target:add("configfiles", intermediate, {
        filename = filename,
        pattern = "@(.-)@"
    })
end

local function add_lua_dependency(target)
    if package_enabled("luajit", "luajit") then
        target:add("packages", "luajit")
    else
        target:add("deps", "lua_bundled")
    end
end

local function add_jsoncpp_dependency(target)
    if package_enabled("system_jsoncpp", "jsoncpp") then
        target:add("packages", "jsoncpp", {public = true})
    else
        target:add("deps", "jsoncpp_bundled", {public = true})
    end
end

-- ============================================================================
-- Bundled libraries
-- ============================================================================
target("gmp_bundled")
    set_kind("static")
    set_default(false)
    add_files("lib/gmp/mini-gmp.c")
    add_includedirs("lib/gmp", {public = true})
target_end()

target("jsoncpp_bundled")
    set_kind("static")
    set_default(false)
    add_files("lib/jsoncpp/jsoncpp.cpp")
    add_includedirs("lib/jsoncpp", {public = true})
target_end()

target("lua_bundled")
    set_kind("static")
    set_default(false)
    add_files("lib/lua/src/*.c", {sourcekind = "cxx"})
    remove_files(
        "lib/lua/src/lua.c",
        "lib/lua/src/luac.c",
        "lib/lua/src/print.c"
    )
    add_includedirs("lib/lua/src", {public = true})

    if is_plat("macosx") then
        add_defines("LUA_USE_MACOSX", "LUA_USE_POSIX")
    elseif is_plat("linux", "bsd", "cygwin") then
        add_defines("LUA_USE_POSIX", "LUA_USE_DLOPEN")
        if is_plat("linux") then
            add_syslinks("dl", "m")
        end
    elseif is_plat("windows", "mingw") then
        add_defines("_CRT_SECURE_NO_WARNINGS")
    else
        add_defines("LUA_ANSI")
    end
target_end()

target("bitop")
    set_kind("static")
    set_default(false)
    add_files("lib/bitop/bit.cpp")
    add_includedirs("lib/bitop", {public = true})
    on_load(add_lua_dependency)
target_end()

target("lstrpack")
    set_kind("static")
    set_default(false)
    set_languages("c11")
    -- Keep C linkage; the source uses static_assert without <assert.h>.
    add_files("lib/lstrpack/lstrpack.c")
    add_defines("static_assert=_Static_assert")
    add_includedirs("lib/lstrpack", {public = true})
    on_load(add_lua_dependency)
target_end()

target("sha256")
    set_kind("static")
    set_default(false)
    add_files("lib/sha256/sha256.c")
    add_includedirs("lib/sha256", {public = true})

    if is_plat("linux") then
        add_defines("_DEFAULT_SOURCE")
    end

    on_load(function (target)
        local configdir = path.absolute(
            path.join(target:autogendir(), "config"),
            os.projectdir()
        )

        target:set("configdir", configdir)
        target:add("includedirs", configdir)

        add_cmake_configfile(
            target,
            "lib/sha256/cmake_config.h.in",
            "cmake_config.h",
            {
                io = io,
                os = os,
                path = path,
                raise = raise
            }
        )
    end)

    on_config(function (target)
        set_bool_config(
            target,
            "HAVE_ENDIAN_H",
            target:has_cincludes("endian.h")
        )
    end)
target_end()

if has_config("unittests") or has_config("benchmarks") then
    target("catch2")
        set_kind("static")
        set_default(false)
        add_files("lib/catch2/catch_amalgamated.cpp")
        add_defines("CATCH_CONFIG_NOSTDOUT", "CATCH_AMALGAMATED_CUSTOM_MAIN")
        add_includedirs("lib/catch2", {public = true})
    target_end()
end

target("tiniergltf")
    set_kind("headeronly")
    set_default(false)
    add_includedirs("lib/tiniergltf", "src", {public = true})
    on_load(add_jsoncpp_dependency)
target_end()

-- ============================================================================
-- IrrlichtMt
-- ============================================================================
target("IrrlichtHeaders")
    set_kind("headeronly")
    set_default(false)
    add_includedirs("irr/include", {public = true})

    if is_mode("debug") then
        add_defines("_DEBUG", {public = true})
    end
target_end()

target("IrrlichtMt")
    if has_config("client") then
        set_kind("static")
        set_default(false)

        add_deps("IrrlichtHeaders", "tiniergltf")
        add_packages("zlib", "libjpeg", "libpng")

        if has_config("tracy") then
            add_packages("tracy")
        end

        add_includedirs("irr/src", {private = true})

        if is_plat("windows", "mingw") then
            add_defines("_IRR_WINDOWS_", "_IRR_WINDOWS_API_", {public = true})
        elseif is_plat("macosx") then
            add_defines("_IRR_OSX_PLATFORM_", "GL_SILENCE_DEPRECATION")
        elseif is_plat("android") then
            add_defines("_IRR_ANDROID_PLATFORM_")
            add_syslinks("android", "log", "GLESv2", "GLESv1_CM", "OpenSLES")
        elseif is_plat("wasm") then
            add_defines("_IRR_EMSCRIPTEN_PLATFORM_", "_IRR_COMPILE_WITH_EGL_MANAGER_")
        else
            add_defines("_IRR_POSIX_API_")
        end

        add_defines("_IRR_COMPILE_WITH_SDL_DEVICE_")
        if not is_plat("bsd", "solaris", "wasm") then
            add_defines("_IRR_COMPILE_WITH_JOYSTICK_EVENTS_")
        end

        if has_config("sdl3") then
            add_packages("libsdl3")
            add_defines("_IRR_USE_SDL3_", "IRR_PREFER_SDL_GL_HEADER")
        else
            add_packages("libsdl2")
            add_defines("IRR_PREFER_SDL_GL_HEADER")
        end

        -- Device and OS sources; CMake compiles all of them as Objective-C++
        -- on macOS.
        local irr_device_sources = {
            "irr/src/CIrrDeviceSDL.cpp",
            "irr/src/CIrrDeviceStub.cpp",
            "irr/src/CLogger.cpp",
            "irr/src/COSOperator.cpp",
            "irr/src/Irrlicht.cpp",
            "irr/src/os.cpp"
        }

        local irr_sources = "irr/src/*.cpp"
        if not has_config("opengl") then
            irr_sources = irr_sources .. "|irr/src/COpenGL*.cpp"
        end
        if is_plat("macosx") then
            for _, source in ipairs(irr_device_sources) do
                irr_sources = irr_sources .. "|" .. source
            end
        end

        add_files(irr_sources)

        if is_plat("macosx") then
            add_files(irr_device_sources, {sourcekind = "mxx"})
        end

        if has_config("opengl") then
            add_defines("_IRR_COMPILE_WITH_OPENGL_")
            add_packages("opengl")
        end

        if has_config("opengl3") or has_config("gles2") then
            add_files("irr/src/OpenGL/*.cpp")
        end

        if has_config("opengl3") then
            add_defines("ENABLE_OPENGL3")
            add_files("irr/src/OpenGL3/*.cpp")
        end

        if has_config("gles2") then
            add_defines("_IRR_COMPILE_WITH_OGLES2_")
            add_files("irr/src/OpenGLES2/*.cpp")
        end

        if is_plat("windows") then
            add_defines(
                "_CRT_SECURE_NO_DEPRECATE",
                "_CRT_SECURE_NO_WARNINGS",
                "_USE_MATH_DEFINES",
                "NOMINMAX"
            )
            if is_arch("x86") then
                add_cxflags("/arch:SSE")
            end
        else
            add_cxflags("-Wall", "-pipe", "-fPIC")
            if is_arch("i386", "x86") then
                add_cxflags("-mfpmath=sse", "-msse")
            end
        end
    else
        set_kind("headeronly")
        set_default(false)
        add_deps("IrrlichtHeaders")
    end
target_end()

-- ============================================================================
-- Generated sources
-- ============================================================================
rule("luanti.codegen")
    on_build(function ()
        local projectdir = os.projectdir()
        local generated = path.absolute(
            path.join(get_config("builddir") or "build", "generated"),
            projectdir
        )

        os.mkdir(generated)

        local function write_if_changed(filename, content)
            if not os.isfile(filename) or io.readfile(filename) ~= content then
                io.writefile(filename, content)
            end
        end

        local function read_template(relative)
            local filename = path.join(projectdir, relative)
            local content = io.readfile(filename)

            if not content then
                raise("Cannot read generation template: %s", filename)
            end

            return content
        end

        -- cmake_config_githash.h
        local version = version_string()
        local githash = version

        if has_config("dev_build") then
            local revision = try {
                function ()
                    return os.iorunv("git", {
                        "-C", projectdir, "rev-parse", "--short", "HEAD"
                    })
                end
            }

            if revision then
                githash = version .. "-" .. revision:trim()

                local clean = try {
                    function ()
                        os.runv("git", {
                            "-C", projectdir, "diff-index", "--quiet", "HEAD", "--"
                        })
                        return true
                    end
                }

                if not clean then
                    githash = githash .. "-dirty"
                end
            else
                githash = version .. "-unknown"
            end
        end

        local git_content = read_template("src/cmake_config_githash.h.in")
            :gsub("@VERSION_GITHASH@", function ()
                return githash
            end)

        write_if_changed(
            path.join(generated, "cmake_config_githash.h"),
            git_content
        )

        -- builtin_files.cpp
        local builtin_dir = path.join(projectdir, "builtin")
        local files = os.files(path.join(builtin_dir, "**.lua"))
        table.join2(files, os.files(path.join(builtin_dir, "**.json")))
        table.sort(files)

        local function escape_cpp(value)
            value = value:gsub("\\", "\\\\")
            value = value:gsub('"', '\\"')
            value = value:gsub("\r", "\\r")
            value = value:gsub("\n", "\\n")
            return value
        end

        local entries = {}
        for _, filename in ipairs(files) do
            local relative = path.relative(filename, builtin_dir):gsub("\\", "/")
            local digest = hash.sha256(filename, {file = true})
            entries[#entries + 1] = string.format(
                '{"%s"sv, "%s"sv}',
                escape_cpp(relative),
                digest
            )
        end

        local builtin_content = read_template("src/builtin_files.cpp.in")
            :gsub("@BUILTIN_SHA256S_INITIALIZER_LIST@", function ()
                return table.concat(entries, ",\n")
            end)

        write_if_changed(
            path.join(generated, "builtin_files.cpp"),
            builtin_content
        )
    end)
rule_end()

target("luanti_codegen")
    set_kind("phony")
    set_default(false)
    set_policy("build.fence", true)
    add_rules("luanti.codegen")
target_end()

-- ============================================================================
-- Common target configuration
-- ============================================================================
local function configure_target(target, is_client)
    target:add("deps", "luanti_codegen", "sha256", "lstrpack", "IrrlichtHeaders")
    target:add("defines", "USE_CMAKE_CONFIG_H")
    target:add("includedirs", "$(builddir)/generated", "src", "src/script")
    target:add("packages", "zlib", "zstd", "sqlite3")

    if is_client then
        target:add("deps", "IrrlichtMt")
    end

    -- Packages with bundled fallbacks.
    local use_luajit = false
    for _, dependency in ipairs(FALLBACK_PACKAGES) do
        local enabled = package_enabled(dependency.option, dependency.package)

        if enabled then
            target:add("packages", dependency.package)
        else
            target:add("deps", dependency.bundled)
        end

        set_bool_config(target, dependency.config, enabled)

        if dependency.option == "luajit" then
            use_luajit = enabled
        end
    end

    if not use_luajit then
        target:add("deps", "bitop")

        -- Export the executable's Lua API for dynamically loaded modules.
        if is_plat("linux", "bsd") then
            target:add("ldflags", "-rdynamic")
        elseif is_plat("macosx") then
            target:add("ldflags", "-Wl,-export_dynamic")
        end
    end

    -- Optional engine features.
    for _, feature in ipairs(FEATURES) do
        local enabled = package_enabled(feature.option, feature.package)
        set_bool_config(target, feature.config, enabled)

        if enabled then
            target:add("packages", feature.package)
        end
    end

    -- gettext may come from libc; USE_GETTEXT is probed during configuration.
    if has_config("gettext") and has_package("libintl") then
        target:add("packages", "libintl")
    end

    local use_sound = is_client and sound_enabled()
    set_bool_config(target, "USE_SOUND", use_sound)

    if is_client then
        target:add(
            "packages",
            "freetype",
            "libzip",
            has_config("sdl3") and "libsdl3" or "libsdl2"
        )

        if use_sound then
            target:add("packages", "openal-soft", "libvorbis", "libogg")
            target:add("files", "src/client/sound/*.cpp")
        end
    end

    if has_config("unittests") or has_config("benchmarks") then
        target:add("deps", "catch2")
    end

    -- Platform libraries and compiler settings.
    if is_plat("windows") then
        target:add(
            "syslinks",
            "ws2_32", "version", "shlwapi", "winmm", "dbghelp"
        )
        target:add(
            "defines",
            "_WIN32_WINNT=0x0601",
            "WIN32_LEAN_AND_MEAN",
            "_CRT_SECURE_NO_WARNINGS",
            "_CRT_SECURE_NO_DEPRECATE",
            "_USE_MATH_DEFINES",
            "NOMINMAX"
        )

        if is_mode("release") then
            target:add(
                "cxflags",
                "/EHa", "/fp:precise", "/fp:except-",
                "/D_HAS_ITERATOR_DEBUGGING=0"
            )
            target:add(
                "ldflags",
                "/INCREMENTAL:NO", "/OPT:REF", "/OPT:ICF"
            )

            if is_client then
                target:add(
                    "ldflags",
                    "/SUBSYSTEM:WINDOWS", "/ENTRY:mainCRTStartup"
                )
            end
        end
    elseif is_plat("mingw") then
        target:add(
            "syslinks",
            "ws2_32", "version", "shlwapi", "winmm", "pthread"
        )
        target:add(
            "defines",
            "_WIN32_WINNT=0x0601",
            "WIN32_LEAN_AND_MEAN"
        )

        if is_client and is_mode("release") then
            target:add("ldflags", "-mwindows")
        end
    else
        target:add("syslinks", "m")

        if is_plat("linux") then
            target:add("syslinks", "pthread", "dl", "rt", "atomic")
        elseif is_plat("android") then
            target:add("syslinks", "dl", "android", "log")
        elseif is_plat("macosx") then
            target:add("syslinks", "pthread")
            target:add("frameworks", "CoreFoundation")
        elseif is_plat("bsd") then
            target:add("syslinks", "pthread")
        elseif is_plat("haiku") then
            target:add("defines", "_BSD_SOURCE")
            target:add("syslinks", "network")
        elseif not is_plat("wasm") then
            target:add("syslinks", "pthread", "dl")
        end
    end

    -- Build-mode rules own optimization and debug-symbol settings.
    if warnings_enabled() then
        target:set("warnings", "allextra")
    end

    if not is_plat("windows") then
        target:add("cxflags", "-pipe")

        if is_mode("debug", "semidebug") and is_plat("linux", "bsd", "macosx") then
            target:add("defines", "_GLIBCXX_ASSERTIONS")
        end
    end

    -- Configuration header variables.
    local version_extra = get_config("version_extra") or ""
    local mode = get_config("mode") or "release"
    local build_type = MODE_NAMES[mode] or mode
    local run_in_place = has_config("run_in_place")
    local sharedir = run_in_place and "." or "/usr/local/share/luanti"

    local configvars = {
        PROJECT_NAME = "luanti",
        PROJECT_NAME_CAPITALIZED = "Luanti",
        VERSION_MAJOR = VERSION_MAJOR,
        VERSION_MINOR = VERSION_MINOR,
        VERSION_PATCH = VERSION_PATCH,
        VERSION_EXTRA = version_extra,
        VERSION_STRING = version_string(),
        CMAKE_BUILD_TYPE = build_type,
        SHAREDIR = sharedir,
        ICONDIR = sharedir .. "/icons",
        BINDIR = run_in_place and "bin" or "/usr/local/bin",
        DOCDIR = run_in_place and "doc" or "/usr/local/share/doc/luanti",
        EXAMPLE_CONF_DIR = run_in_place and "." or "/usr/local/share/doc/luanti",
        LOCALEDIR = run_in_place and "locale" or "/usr/local/share/locale"
    }

    for name, value in pairs(configvars) do
        target:set("configvar", name, value)
    end

    set_bool_config(target, "DEVELOPMENT_BUILD", has_config("dev_build"))
    set_bool_config(target, "ENABLE_UPDATE_CHECKER", not has_config("dev_build"))
    set_bool_config(target, "RUN_IN_PLACE", run_in_place)
    set_bool_config(target, "BUILD_UNITTESTS", has_config("unittests"))
    set_bool_config(target, "BUILD_BENCHMARKS", has_config("benchmarks"))
end

local CURSES_HEADERS = {
    CURSES_HAVE_CURSES_H = "curses.h",
    CURSES_HAVE_NCURSES_H = "ncurses.h",
    CURSES_HAVE_NCURSES_NCURSES_H = "ncurses/ncurses.h",
    CURSES_HAVE_NCURSES_CURSES_H = "ncurses/curses.h",
    CURSES_HAVE_NCURSESW_NCURSES_H = "ncursesw/ncurses.h",
    CURSES_HAVE_NCURSESW_CURSES_H = "ncursesw/curses.h"
}

rule("luanti.configure")
    on_load(function (target)
        local configdir = path.absolute(
            path.join(target:autogendir(), "config"),
            os.projectdir()
        )

        target:set("configdir", configdir)
        target:add("includedirs", configdir)

        configure_target(target, target:name() == "luanti")
        add_cmake_configfile(
            target,
            "src/cmake_config.h.in",
            "cmake_config.h",
            {
                io = io,
                os = os,
                path = path,
                raise = raise
            }
        )
    end)

    on_config(function (target)
        -- Capability probes link a test program when the target has link
        -- flags. Drop them temporarily so probes don't require the bundled
        -- static libraries to exist yet.
        local links = target:get("links")
        local syslinks = target:get("syslinks")
        target:set("links", {})
        target:set("syslinks", {})

        local use_curses = has_config("curses") and has_package("ncurses")
        for variable, header in pairs(CURSES_HEADERS) do
            set_bool_config(
                target,
                variable,
                use_curses and target:has_cxxincludes(header)
            )
        end

        set_bool_config(
            target,
            "HAVE_ENDIAN_H",
            target:has_cxxincludes("endian.h")
        )
        set_bool_config(
            target,
            "HAVE_STRLCPY",
            target:has_cxxfuncs("strlcpy", {includes = "string.h"})
        )
        set_bool_config(
            target,
            "HAVE_MALLOC_TRIM",
            is_plat("linux") and target:has_cxxfuncs(
                "malloc_trim",
                {includes = "malloc.h"}
            )
        )
        set_bool_config(
            target,
            "USE_GETTEXT",
            has_config("gettext") and (
                has_package("libintl")
                or target:has_cxxfuncs("ngettext", {includes = "libintl.h"})
            )
        )

        target:set("links", links or {})
        target:set("syslinks", syslinks or {})

        -- Extra warnings from the CMake build.
        if warnings_enabled() and not is_plat("windows") then
            target:add("cxflags", "-Wno-unused-parameter", "-Werror=vla")

            if target:has_cxxflags("-Werror=mismatched-tags") then
                target:add("cxflags", "-Werror=mismatched-tags")
            end

            if target:has_cxxflags("-Wnull-dereference") then
                target:add("cxflags", "-Wnull-dereference")
            end
        end
    end)
rule_end()

-- ============================================================================
-- Sources
-- ============================================================================

-- Compiled into the client only.
local CLIENT_SCRIPT_SOURCES = {
    "src/script/scripting_client.cpp",
    "src/script/scripting_mainmenu.cpp",
    "src/script/scripting_pause_menu.cpp",
    "src/script/scripting_sscsm.cpp",
    "src/script/cpp_api/s_client.cpp",
    "src/script/cpp_api/s_client_common.cpp",
    "src/script/cpp_api/s_mainmenu.cpp",
    "src/script/cpp_api/s_pause_menu.cpp",
    "src/script/cpp_api/s_sscsm.cpp",
    "src/script/lua_api/l_camera.cpp",
    "src/script/lua_api/l_client.cpp",
    "src/script/lua_api/l_client_common.cpp",
    "src/script/lua_api/l_client_sound.cpp",
    "src/script/lua_api/l_localplayer.cpp",
    "src/script/lua_api/l_mainmenu.cpp",
    "src/script/lua_api/l_mainmenu_sound.cpp",
    "src/script/lua_api/l_menu_common.cpp",
    "src/script/lua_api/l_minimap.cpp",
    "src/script/lua_api/l_particles_local.cpp",
    "src/script/lua_api/l_pause_menu.cpp",
    "src/script/lua_api/l_sscsm.cpp",
    "src/script/sscsm/*.cpp"
}

local CLIENT_UNITTEST_SOURCES = {
    "src/unittest/mesh_compare.cpp",
    "src/unittest/test_clientactiveobjectmgr.cpp",
    "src/unittest/test_content_mapblock.cpp",
    "src/unittest/test_eventmanager.cpp",
    "src/unittest/test_gameui.cpp",
    "src/unittest/test_keycode.cpp",
    "src/unittest/test_mesh_compare.cpp"
}

local CLIENT_NETWORK_SOURCES = {
    "src/network/clientopcodes.cpp",
    "src/network/clientpackethandler.cpp"
}

-- Sources shared by the client and the dedicated server. The executables
-- compile these separately because MT_BUILDTARGET differs.
local function add_common_sources(is_client)
    add_files("src/*.cpp")
    remove_files("src/settings_translation_file.cpp")

    if not (has_config("unittests") or has_config("benchmarks")) then
        remove_files("src/catch.cpp")
    end
    if not is_plat("android") then
        remove_files("src/porting_android.cpp")
    end

    add_files(
        "src/content/*.cpp",
        "src/database/*.cpp",
        "src/mapgen/*.cpp",
        "src/server/*.cpp",
        "src/threading/*.cpp",
        "src/util/*.cpp"
    )

    add_files("src/network/**.cpp")
    add_files("src/script/**.cpp")

    -- Client-only sources are only excluded for the server target.
    if not is_client then
        remove_files(CLIENT_NETWORK_SOURCES)
        remove_files(CLIENT_SCRIPT_SOURCES)
    end

    if has_config("unittests") then
        add_files("src/test/*.cpp", "src/unittest/*.cpp")

        if not is_client then
            remove_files(CLIENT_UNITTEST_SOURCES)
        end
    end

    if has_config("benchmarks") then
        add_files("src/benchmark/*.cpp")
    end
end

-- ============================================================================
-- Client target
-- ============================================================================
if has_config("client") then
    target("luanti")
        add_rules("luanti.configure")

        if is_plat("android") then
            set_kind("shared")
        else
            set_kind("binary")
        end

        if has_config("run_in_place") then
            set_rundir("$(projectdir)")

            -- Keep cross-compiled artifacts in Xmake's build directory.
            if not is_cross() then
                set_targetdir("$(projectdir)/bin")
            end
        end

        add_defines("MT_BUILDTARGET=1")
        add_common_sources(true)

        add_files(
            "$(builddir)/generated/builtin_files.cpp",
            {always_added = true}
        )
        add_files(
            "src/client/*.cpp",
            "src/client/meshgen/*.cpp",
            "src/client/render/*.cpp",
            "src/client/shadows/*.cpp",
            "src/gui/*.cpp",
            "src/irrlicht_changes/*.cpp"
        )

        if has_config("unittests") then
            add_files("src/test/client/*.cpp")
        end

        if is_plat("windows", "mingw") then
            add_files("misc/winresource.rc")
        end
    target_end()
end

-- ============================================================================
-- Server target
-- ============================================================================
if has_config("server") or not has_config("client") then
    target("luantiserver")
        add_rules("luanti.configure")
        set_kind("binary")

        if not is_cross() then
            set_targetdir("$(projectdir)/bin")
        end

        if has_config("run_in_place") then
            set_rundir("$(projectdir)")
        end

        add_defines("MT_BUILDTARGET=2")
        add_common_sources(false)

        add_files(
            "$(builddir)/generated/builtin_files.cpp",
            {always_added = true}
        )

        if is_plat("windows", "mingw") then
            add_files("misc/winresource.rc")
        end
    target_end()
end
