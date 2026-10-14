set_project("luanti")
set_version("5.18.0")
set_xmakever("2.8.0")

set_languages("c99", "gnuxx17")
-- Android's shared client includes objects from bundled static libraries.
if is_plat("android") then
    add_cxflags("-fPIC")
end
-- Generated files from dependencies must exist before consumers compile.
set_policy("build.fence", true)

-- Build Modes
add_rules("mode.debug", "mode.release", "mode.releasedbg", "mode.minsizerel")
rule("mode.semidebug")
    on_config(function(target)
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
-- Configuration Options
-- ============================================================================
option("client",            {default = true,  showmenu = true, description = "Build client"})
option("server",            {default = false, showmenu = true, description = "Build server"})
option("unittests",         {default = true,  showmenu = true, description = "Build unittests"})
option("benchmarks",        {default = false, showmenu = true, description = "Build benchmarks"})
option("run_in_place",      {default = is_plat("windows", "mingw"), showmenu = true, description = "Run directly in source directory structure"})
option("dev_build",         {default = true,  showmenu = true, description = "Development build"})
option("version_extra",     {default = "",    showmenu = true, description = "Stuff to append to version string"})
option("lto",               {default = false, showmenu = true, description = "Enable Link Time Optimization"})
option("warn_all",          {default = true,  showmenu = true, description = "Enable -Wall for Release build"})

-- Feature & Dependency Options
option("system_gmp",        {default = true,  showmenu = true, description = "Use GMP from system"})
option("system_jsoncpp",    {default = true,  showmenu = true, description = "Use JsonCpp from system"})
option("luajit",            {default = true,  showmenu = true, description = "Enable LuaJIT support"})
option("curl",              {default = true,  showmenu = true, description = "Enable cURL support"})
option("gettext",           {default = true,  showmenu = true, description = "Use GetText for internationalization"})
option("sound",             {default = true,  showmenu = true, description = "Enable sound"})
option("curses",            {default = false, showmenu = true, description = "Enable ncurses console"})
option("postgresql",        {default = true,  showmenu = true, description = "Enable PostgreSQL backend"})
option("leveldb",           {default = true,  showmenu = true, description = "Enable LevelDB backend"})
option("redis",             {default = true,  showmenu = true, description = "Enable Redis backend"})
option("prometheus",        {default = false, showmenu = true, description = "Enable prometheus client support"})
option("spatial",           {default = true,  showmenu = true, description = "Enable SpatialIndex AreaStore backend"})
option("openssl",           {default = true,  showmenu = true, description = "Use OpenSSL libcrypto for faster SHA"})
option("tracy",             {default = false, showmenu = true, description = "Build with Tracy profiler client"})

-- Irrlicht / Graphics Options
option("sdl3",              {default = false, showmenu = true, description = "Use SDL3 backend instead of SDL2"})
option("opengl",            {default = not is_plat("android", "wasm"), showmenu = true, description = "Enable legacy OpenGL"})
option("opengl3",           {default = not is_plat("android"), showmenu = true, description = "Enable OpenGL 3+"})
option("gles2",             {default = is_plat("android", "wasm"), showmenu = true, description = "Enable OpenGL ES 2+"})

-- ============================================================================
-- External Package Requirements
-- ============================================================================
add_requires("zlib", "zstd", "sqlite3")

if has_config("system_gmp") then
    add_requires("gmp", {optional = true, system = true})
end
if has_config("system_jsoncpp") then
    add_requires("jsoncpp", {optional = true, system = true})
end
if has_config("luajit") then
    add_requires("luajit", {optional = true})
end
if has_config("curl") then
    add_requires("libcurl >=7.28.0", {optional = true})
end
if has_config("gettext") then
    add_requires("libintl", {optional = true})
end
if has_config("curses") then
    add_requires("ncurses", {optional = true})
end
if has_config("postgresql") then
    add_requires("postgresql", {optional = true})
end
if has_config("leveldb") then
    add_requires("leveldb", {optional = true})
end
if has_config("redis") then
    add_requires("hiredis", {optional = true})
end
if has_config("prometheus") then
    add_requires("prometheus-cpp", {optional = true})
end
if has_config("spatial") then
    add_requires("spatialindex", {optional = true})
end
if has_config("openssl") then
    add_requires("openssl3", {optional = true})
end
if has_config("tracy") then
    add_requires("tracy")
end

if has_config("client") then
    add_requires("libjpeg", "libpng", "freetype", "libzip >=1.7.2")
    if has_config("sdl3") then
        add_requires("libsdl3")
    else
        add_requires("libsdl2")
    end
    if has_config("opengl") then
        add_requires("opengl")
    end
    if has_config("sound") then
        add_requires("openal-soft", "libvorbis", "libogg")
    end
end

-- Global LTO setting
if has_config("lto") then
    set_policy("build.optimization.lto", true)
end

-- Adapt CMake's boolean directives without changing source templates.
-- Callback-only APIs are supplied explicitly.
local function add_cmake01_configfile(target, input, options, runtime)
    local builddir = runtime.path.absolute(
        runtime.get_config("builddir") or "build",
        runtime.os.projectdir()
    )
    local intermediate = runtime.path.join(
        builddir,
        "xmake-templates",
        input
    )
    local source = runtime.path.join(runtime.os.projectdir(), input)
    local content = runtime.io.readfile(source)

    if not content then
        runtime.raise("Cannot read configuration template: %s", source)
    end

    content = content:gsub(
        "#cmakedefine01[ \t]+([%w_]+)",
        function(name)
            return "#define " .. name .. " @" .. name .. "@"
        end
    )

    content = content:gsub(
        "#cmakedefine[ \t]+([%w_]+)([^\r\n]*)",
        function(name, suffix)
            return table.concat({
                "#if @" .. name .. "@",
                "#define " .. name .. suffix,
                "#endif"
            }, "\n")
        end
    )

    runtime.os.mkdir(runtime.path.directory(intermediate))

    if not runtime.os.isfile(intermediate)
        or runtime.io.readfile(intermediate) ~= content then
        runtime.io.writefile(intermediate, content)
    end

    target:add("configfiles", intermediate, options)
end

-- ============================================================================
-- Bundled Libraries (Fallbacks & Internal)
-- ============================================================================

-- 1. Bundled mini-gmp (used if system GMP is disabled or not found)
target("gmp_bundled")
    set_kind("static")
    set_default(false)
    add_files("lib/gmp/mini-gmp.c")
    add_includedirs("lib/gmp", {public = true})

-- 2. Bundled JsonCpp (used if system JsonCpp is disabled or not found)
target("jsoncpp_bundled")
    set_kind("static")
    set_default(false)
    add_files("lib/jsoncpp/jsoncpp.cpp")
    add_includedirs("lib/jsoncpp", {public = true})

-- 3. Bundled Lua 5.1.4 (used if LuaJIT is disabled or not found)
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

-- 4. BitOp (used when not using LuaJIT)
target("bitop")
    set_kind("static")
    set_default(false)
    add_files("lib/bitop/bit.cpp")
    add_includedirs("lib/bitop", {public = true})
    on_load(function (target)
        if has_config("luajit") and has_package("luajit") then
            target:add("packages", "luajit")
        else
            target:add("deps", "lua_bundled")
        end
    end)

-- 5. lstrpack
target("lstrpack")
    set_kind("static")
    set_default(false)
    set_languages("c11")

    -- Compile as C so setup_lstrpack retains C linkage.
    -- The source uses static_assert without including C's <assert.h>.
    add_files("lib/lstrpack/lstrpack.c")
    add_defines("static_assert=_Static_assert")

    add_includedirs("lib/lstrpack", {public = true})

    on_load(function(target)
        if has_config("luajit") and has_package("luajit") then
            target:add("packages", "luajit")
        else
            target:add("deps", "lua_bundled")
        end
    end)

-- 6. sha256
target("sha256")
    set_kind("static")
    set_default(false)
    add_files("lib/sha256/sha256.c")
    add_includedirs("lib/sha256", {public = true})

    if is_plat("linux") then
        add_defines("_DEFAULT_SOURCE")
    end

    on_load(function(target)
	    local configdir = path.absolute(
	        path.join(target:autogendir(), "config"),
	        os.projectdir()
	    )

        target:set("configdir", configdir)
        target:add("includedirs", configdir)

        add_cmake01_configfile(
            target,
            "lib/sha256/cmake_config.h.in",
            {
                filename = "cmake_config.h",
                pattern = "@(.-)@"
            },
            {
                io = io,
                os = os,
                path = path,
                raise = raise,
                get_config = get_config
            }
        )
    end)

    on_config(function(target)
        local available = target:has_cincludes("endian.h")

        target:set(
            "configvar",
            "HAVE_ENDIAN_H",
            available and 1 or 0
        )
    end)

-- 7. Catch2 (Unittests & Benchmarks)
if has_config("unittests") or has_config("benchmarks") then
    target("catch2")
        set_kind("static")
        set_default(false)
        add_files("lib/catch2/catch_amalgamated.cpp")
        add_defines("CATCH_CONFIG_NOSTDOUT", "CATCH_AMALGAMATED_CUSTOM_MAIN")
        add_includedirs("lib/catch2", {public = true})
end

-- 8. tiniergltf
target("tiniergltf")
    set_kind("headeronly")
    set_default(false)
    add_includedirs("lib/tiniergltf", "src", {public = true})
    on_load(function (target)
        if has_config("system_jsoncpp") and has_package("jsoncpp") then
            target:add("packages", "jsoncpp", {public = true})
        else
            target:add("deps", "jsoncpp_bundled", {public = true})
        end
    end)

-- ============================================================================
-- IrrlichtMt Target
-- ============================================================================
target("IrrlichtHeaders")
    set_kind("headeronly")
    set_default(false)
    add_includedirs("irr/include", {public = true})

    if is_mode("debug") then
        add_defines("_DEBUG", {public = true})
    end

target("IrrlichtMt")
    if has_config("client") then
        set_kind("static")
        set_default(false)

        add_deps("IrrlichtHeaders")
        add_deps("tiniergltf")
        add_packages("zlib", "libjpeg", "libpng")

        if has_config("tracy") then
            add_packages("tracy")
        end

        add_includedirs("irr/src", {private = true})

        -- Platform Defines
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

        -- SDL2 / SDL3
        if has_config("sdl3") then
            add_packages("libsdl3")
            add_defines("_IRR_USE_SDL3_", "IRR_PREFER_SDL_GL_HEADER")
        else
            add_packages("libsdl2")
            add_defines("IRR_PREFER_SDL_GL_HEADER")
        end

        -- Core Irrlicht Sources
        add_files(
            -- Scene / Core
            "irr/src/CBillboardSceneNode.cpp",
            "irr/src/CCameraSceneNode.cpp",
            "irr/src/CDummyTransformationSceneNode.cpp",
            "irr/src/CEmptySceneNode.cpp",
            "irr/src/CMeshManipulator.cpp",
            "irr/src/CSceneCollisionManager.cpp",
            "irr/src/CSceneManager.cpp",
            "irr/src/CMeshCache.cpp",
            -- Mesh Loaders
            "irr/src/WeightBuffer.cpp",
            "irr/src/SkinnedMesh.cpp",
            "irr/src/CMeshSceneNode.cpp",
            "irr/src/AnimatedMeshSceneNode.cpp",
            "irr/src/AnimSpec.cpp",
            "irr/src/CB3DMeshFileLoader.cpp",
            "irr/src/CGLTFMeshFileLoader.cpp",
            "irr/src/COBJMeshFileLoader.cpp",
            "irr/src/CXMeshFileLoader.cpp",
            -- Video / Driver Core
            "irr/src/CNullDriver.cpp",
            "irr/src/CEGLManager.cpp",
            "irr/src/CSDLManager.cpp",
            "irr/src/mt_opengl_loader.cpp",
            "irr/src/HWBuffer.cpp",
            -- Image Loaders
            "irr/src/CColorConverter.cpp",
            "irr/src/CImage.cpp",
            "irr/src/CImageLoaderJPG.cpp",
            "irr/src/CImageLoaderPNG.cpp",
            "irr/src/CImageLoaderTGA.cpp",
            "irr/src/CImageWriterJPG.cpp",
            "irr/src/CImageWriterPNG.cpp",
            -- IO
            "irr/src/CFileList.cpp",
            "irr/src/CFileSystem.cpp",
            "irr/src/CLimitReadFile.cpp",
            "irr/src/CMemoryFile.cpp",
            "irr/src/CReadFile.cpp",
            "irr/src/CWriteFile.cpp",
            -- GUI
            "irr/src/CGUIButton.cpp",
            "irr/src/CGUICheckBox.cpp",
            "irr/src/CGUIComboBox.cpp",
            "irr/src/CGUIEditBox.cpp",
            "irr/src/CGUIEnvironment.cpp",
            "irr/src/CGUIFileOpenDialog.cpp",
            "irr/src/CGUIFont.cpp",
            "irr/src/CGUIImage.cpp",
            "irr/src/CGUIListBox.cpp",
            "irr/src/CGUIScrollBar.cpp",
            "irr/src/CGUISkin.cpp",
            "irr/src/CGUIStaticText.cpp",
            "irr/src/CGUITabControl.cpp",
            "irr/src/CGUISpriteBank.cpp",
            "irr/src/CGUIImageList.cpp"
        )

        -- OS / Device (Compiled as Objective-C++ on macOS)
        local irrother_srcs = {
            "irr/src/CIrrDeviceSDL.cpp",
            "irr/src/CIrrDeviceStub.cpp",
            "irr/src/CLogger.cpp",
            "irr/src/COSOperator.cpp",
            "irr/src/Irrlicht.cpp",
            "irr/src/os.cpp"
        }
        if is_plat("macosx") then
            add_files(irrother_srcs, {cxflags = "-xobjective-c++"})
        else
            add_files(irrother_srcs)
        end

        -- OpenGL Drivers
        if has_config("opengl") then
            add_defines("_IRR_COMPILE_WITH_OPENGL_")
            add_packages("opengl")
            add_files(
                "irr/src/COpenGLCacheHandler.cpp",
                "irr/src/COpenGLDriver.cpp",
                "irr/src/COpenGLSLMaterialRenderer.cpp",
                "irr/src/COpenGLExtensionHandler.cpp"
            )
        end

        if has_config("opengl3") or has_config("gles2") then
            add_files(
                "irr/src/OpenGL/Driver.cpp",
                "irr/src/OpenGL/ExtensionHandler.cpp",
                "irr/src/OpenGL/FixedPipelineRenderer.cpp",
                "irr/src/OpenGL/MaterialRenderer.cpp",
                "irr/src/OpenGL/Renderer2D.cpp",
                "irr/src/OpenGL/BufferObject.cpp"
            )
        end

        if has_config("opengl3") then
            add_defines("ENABLE_OPENGL3")
            add_files("irr/src/OpenGL3/DriverGL3.cpp")
        end

        if has_config("gles2") then
            add_defines("_IRR_COMPILE_WITH_OGLES2_")
            add_files("irr/src/OpenGLES2/DriverGLES2.cpp")
        end

        -- Compiler Flags
        if is_plat("windows") then
            add_defines("_CRT_SECURE_NO_DEPRECATE", "_CRT_SECURE_NO_WARNINGS", "_USE_MATH_DEFINES", "NOMINMAX")
            if is_arch("x86") then add_cxflags("/arch:SSE") end
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

-- ============================================================================
-- Luanti Helper Functions & Code Generation Rules
-- ============================================================================

-- Custom Rule: Generate builtin_files.cpp and cmake_config_githash.h before build
rule("luanti.codegen")
    before_build(function(target)

        local projectdir = os.projectdir()
        local builddir = path.absolute(
            get_config("builddir") or "build",
            projectdir
        )
        local generated = path.join(builddir, "generated")

        os.mkdir(generated)

        local function write_if_changed(filename, content)
            if not os.isfile(filename)
                or io.readfile(filename) ~= content then
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

        -- Generate cmake_config_githash.h.
        local version = "5.18.0"
        local extra = get_config("version_extra") or ""

        if extra ~= "" then
            version = version .. "-" .. extra
        elseif has_config("dev_build") then
            version = version .. "-dev"
        end

        if is_mode("debug") then
            version = version .. "-debug"
        end

        local githash = version

        if has_config("dev_build") then
            local revision = try {
                function()
                    return os.iorunv("git", {
                        "-C",
                        projectdir,
                        "rev-parse",
                        "--short",
                        "HEAD"
                    })
                end
            }

            if revision then
                githash = version .. "-" .. revision:trim()

                local clean = try {
                    function()
                        os.runv("git", {
                            "-C",
                            projectdir,
                            "diff-index",
                            "--quiet",
                            "HEAD",
                            "--"
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

        local git_content = read_template(
            "src/cmake_config_githash.h.in"
        )
        git_content = git_content:gsub(
            "@VERSION_GITHASH@",
            function()
                return githash
            end
        )

        write_if_changed(
            path.join(generated, "cmake_config_githash.h"),
            git_content
        )

        -- Generate builtin_files.cpp from file-content hashes.
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
            local relative = path.relative(
                filename,
                builtin_dir
            ):gsub("\\", "/")

            local digest = hash.sha256(filename, {file = true})

            table.insert(
                entries,
                string.format(
                    '{"%s"sv, "%s"sv}',
                    escape_cpp(relative),
                    digest
                )
            )
        end

        local initializer = table.concat(entries, ",\n")
        local builtin_content = read_template(
            "src/builtin_files.cpp.in"
        )

        builtin_content = builtin_content:gsub(
            "@BUILTIN_SHA256S_INITIALIZER_LIST@",
            function()
                return initializer
            end
        )

        write_if_changed(
            path.join(generated, "builtin_files.cpp"),
            builtin_content
        )
    end)
rule_end()

-- A single generator dependency shared by the client and server.
-- The build fence ensures generated sources exist before compilation.
target("luanti_codegen")
    set_kind("phony")
    set_default(false)
    add_rules("luanti.codegen")
target_end()

-- Common configuration for the client and dedicated server.
local function configure_luanti_target(target, is_client, runtime)
    local get_config = runtime.get_config
    local has_config = runtime.has_config
    local has_package = runtime.has_package
    local is_mode = runtime.is_mode
    local is_plat = runtime.is_plat

    local use_sound = is_client
        and has_config("sound")
        and has_package("openal-soft")
        and has_package("libvorbis")
        and has_package("libogg")

    target:add("deps", "luanti_codegen")
    target:add(
        "files",
        "$(builddir)/generated/builtin_files.cpp",
        {always_added = true}
    )
    target:add("defines", "USE_CMAKE_CONFIG_H")
    target:add("includedirs",
        "$(builddir)/generated",
        "src",
        "src/script"
    )

    -- Packages & Fallbacks
    target:add("packages", "zlib", "zstd", "sqlite3")
    target:add("deps", "sha256", "lstrpack", "IrrlichtHeaders")

    if is_client then
        target:add("deps", "IrrlichtMt")
    end

    if has_config("system_gmp") and has_package("gmp") then
        target:add("packages", "gmp")
    else
        target:add("deps", "gmp_bundled")
    end

    if has_config("system_jsoncpp") and has_package("jsoncpp") then
        target:add("packages", "jsoncpp")
    else
        target:add("deps", "jsoncpp_bundled")
    end

    local use_luajit = has_config("luajit") and has_package("luajit")
    if use_luajit then
        target:add("packages", "luajit")
    else
        target:add("deps", "lua_bundled", "bitop")
        if is_plat("linux", "bsd", "macosx") then
            target:add("ldflags", "-rdynamic")
        end
    end

    if has_config("curl") and has_package("libcurl") then
        target:add("packages", "libcurl")
    end
    if has_config("gettext") and has_package("libintl") then
        target:add("packages", "libintl")
    end
    if has_config("curses") and has_package("ncurses") then
        target:add("packages", "ncurses")
    end
    if has_config("postgresql") and has_package("postgresql") then
        target:add("packages", "postgresql")
    end
    if has_config("leveldb") and has_package("leveldb") then
        target:add("packages", "leveldb")
    end
    if has_config("redis") and has_package("hiredis") then
        target:add("packages", "hiredis")
    end
    if has_config("prometheus") and has_package("prometheus-cpp") then
        target:add("packages", "prometheus-cpp")
    end
    if has_config("spatial") and has_package("spatialindex") then
        target:add("packages", "spatialindex")
    end
    if has_config("openssl") and has_package("openssl3") then
        target:add("packages", "openssl3")
    end
    if has_config("tracy") and has_package("tracy") then
        target:add("packages", "tracy")
    end
    if has_config("unittests") or has_config("benchmarks") then
        target:add("deps", "catch2")
    end

    if is_client then
        target:add("packages", "freetype", "libzip")

        if use_sound then
            target:add("packages", "openal-soft", "libvorbis", "libogg")
            target:add("files", "src/client/sound/*.cpp")
        end

        local sdl_package = has_config("sdl3")
            and "libsdl3"
            or "libsdl2"

        target:add("packages", sdl_package)
    end

    -- Platform System Libraries & Flags
    if is_plat("windows") then
        target:add("syslinks", "ws2_32", "version", "shlwapi", "winmm", "dbghelp")
        target:add("defines", "_WIN32_WINNT=0x0601", "WIN32_LEAN_AND_MEAN", "_CRT_SECURE_NO_WARNINGS",
            "_CRT_SECURE_NO_DEPRECATE", "_USE_MATH_DEFINES", "NOMINMAX")
        target:add("cxflags", "/W1", "/MP")
        if is_mode("release") then
            target:add(
                "cxflags",
                "/EHa",
                "/Ox",
                "/Zi",
                "/fp:precise",
                "/fp:except-",
                "/D_HAS_ITERATOR_DEBUGGING=0"
            )

            target:add(
                "ldflags",
                "/INCREMENTAL:NO",
                "/DEBUG",
                "/OPT:REF",
                "/OPT:ICF"
            )

            if is_client then
                target:add(
                    "ldflags",
                    "/SUBSYSTEM:WINDOWS",
                    "/ENTRY:mainCRTStartup"
                )
            end
        end
    elseif is_plat("mingw") then
        target:add("syslinks", "ws2_32", "version", "shlwapi", "winmm", "pthread")
        target:add("defines", "_WIN32_WINNT=0x0601", "WIN32_LEAN_AND_MEAN")
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

    -- GCC / Clang Warning & Optimization Flags
    if not is_plat("windows") then
	    local warn_flags = {
	        "-Wall",
	        "-Wextra",
	        "-Wno-unused-parameter",
	        "-Werror=vla",
	        "-Wnull-dereference"
	    }

	    if not is_mode("release", "releasedbg") or has_config("warn_all") then
	        target:add("cxxflags", "-Werror=mismatched-tags")
	    end
        if is_mode("release", "releasedbg") then
            if has_config("warn_all") then
                target:add("cxflags", warn_flags)
            end
            target:add("cxflags", "-pipe", "-funroll-loops", "-O3", "-fomit-frame-pointer", "-fno-math-errno",
                "-fno-trapping-math", "-fno-signed-zeros")
        else
            target:add("cxflags", warn_flags)
            if is_plat("linux", "bsd", "macosx") then
                target:add("cxflags", "-Wp,-D_GLIBCXX_ASSERTIONS")
            end
        end
    end

    -- Populate cmake_config.h Variables
    local ver_str = "5.18.0"
    local version_extra = get_config("version_extra") or ""

    if version_extra ~= "" then
        ver_str = ver_str .. "-" .. version_extra
    elseif has_config("dev_build") then
        ver_str = ver_str .. "-dev"
    end
    if is_mode("debug") then
        ver_str = ver_str .. "-debug"
    end

    local run_in_place = has_config("run_in_place")
    target:set("configvar", "PROJECT_NAME", "luanti")
    target:set("configvar", "PROJECT_NAME_CAPITALIZED", "Luanti")
    target:set("configvar", "VERSION_MAJOR", 5)
    target:set("configvar", "VERSION_MINOR", 18)
    target:set("configvar", "VERSION_PATCH", 0)
    target:set("configvar", "VERSION_EXTRA", version_extra)
    target:set("configvar", "VERSION_STRING", ver_str)

    local mode_map = {
        debug = "Debug",
        release = "Release",
        releasedbg = "RelWithDebInfo",
        minsizerel = "MinSizeRel",
        semidebug = "SemiDebug"
    }

    local build_type = mode_map[get_config("mode") or "release"] or "Release"
    target:set("configvar", "CMAKE_BUILD_TYPE", build_type)
    target:set("configvar", "BUILD_INFO", string.format(
        "BUILD_TYPE=%s RUN_IN_PLACE=%d USE_CURL=%d USE_GETTEXT=%d USE_SOUND=%d",
        build_type,
        has_config("run_in_place") and 1 or 0,
        (has_config("curl") and has_package("libcurl")) and 1 or 0,
        (has_config("gettext") and has_package("libintl")) and 1 or 0,
        use_sound and 1 or 0
    ))

    target:set("configvar", "DEVELOPMENT_BUILD", has_config("dev_build") and 1 or 0)
    target:set("configvar", "ENABLE_UPDATE_CHECKER", (not has_config("dev_build")) and 1 or 0)
    target:set("configvar", "RUN_IN_PLACE", run_in_place and 1 or 0)

    local sharedir = run_in_place and "." or "/usr/local/share/luanti"

    target:set("configvar", "SHAREDIR", sharedir)
    target:set("configvar", "ICONDIR", sharedir .. "/icons")
    target:set("configvar", "BINDIR", run_in_place and "bin" or "/usr/local/bin")
    target:set("configvar", "DOCDIR", run_in_place and "doc" or "/usr/local/share/doc/luanti")
    target:set("configvar", "EXAMPLE_CONF_DIR", run_in_place and "." or "/usr/local/share/doc/luanti")
    target:set("configvar", "LOCALEDIR", run_in_place and "locale" or "/usr/local/share/locale")

    target:set("configvar", "USE_GETTEXT", (has_config("gettext") and has_package("libintl")) and 1 or 0)
    target:set("configvar", "USE_CURL", (has_config("curl") and has_package("libcurl")) and 1 or 0)
    target:set("configvar", "USE_SOUND", use_sound and 1 or 0)
    target:set("configvar", "USE_CURSES", (has_config("curses") and has_package("ncurses")) and 1 or 0)
    target:set("configvar", "USE_LEVELDB", (has_config("leveldb") and has_package("leveldb")) and 1 or 0)
    target:set("configvar", "USE_LUAJIT", use_luajit and 1 or 0)
    target:set("configvar", "USE_POSTGRESQL", (has_config("postgresql") and has_package("postgresql")) and 1 or 0)
    target:set("configvar", "USE_PROMETHEUS", (has_config("prometheus") and has_package("prometheus-cpp")) and 1 or 0)
    target:set("configvar", "USE_REDIS", (has_config("redis") and has_package("hiredis")) and 1 or 0)
    target:set("configvar", "USE_SPATIAL", (has_config("spatial") and has_package("spatialindex")) and 1 or 0)
    target:set("configvar", "USE_OPENSSL", (has_config("openssl") and has_package("openssl3")) and 1 or 0)
    target:set("configvar", "USE_SYSTEM_GMP", (has_config("system_gmp") and has_package("gmp")) and 1 or 0)
    target:set("configvar", "USE_SYSTEM_JSONCPP", (has_config("system_jsoncpp") and has_package("jsoncpp")) and 1 or 0)
    target:set("configvar", "BUILD_UNITTESTS", has_config("unittests") and 1 or 0)
    target:set("configvar", "BUILD_BENCHMARKS", has_config("benchmarks") and 1 or 0)
    target:set("configvar", "BUILD_WITH_TRACY", has_config("tracy") and 1 or 0)
end

rule("luanti.configure")

	on_load(function(target)
	    -- autogendir separates targets, platforms, architectures and modes.
	    local configdir = path.absolute(
	        path.join(target:autogendir(), "config"),
	        os.projectdir()
	    )

	    target:set("configdir", configdir)

	    -- Add this before the shared generated directory so a stale header from
	    -- the previous build layout cannot override this target's configuration.
	    target:add("includedirs", configdir)

		-- Xmake resolves source paths during configuration, before code generation.
		-- Create a placeholder only when missing; luanti_codegen writes the actual
		-- contents before either executable compiles.
		local generated = path.absolute(path.join(get_config("builddir") or "build", "generated"), os.projectdir())
		local builtin_cpp = path.join(generated, "builtin_files.cpp")

		os.mkdir(generated)

		if not os.isfile(builtin_cpp) then
			io.writefile(
				builtin_cpp,
				"// Generated by luanti_codegen before compilation.\n"
			)
		end

	    configure_luanti_target(
	        target,
	        target:name() == "luanti",
	        {
	            get_config = get_config,
	            has_config = has_config,
	            has_package = has_package,
	            is_mode = is_mode,
	            is_plat = is_plat
	        }
	    )

	    add_cmake01_configfile(
	        target,
	        "src/cmake_config.h.in",
	        {
	            filename = "cmake_config.h",
	            pattern = "@(.-)@"
	        },
	        {
	            io = io,
	            os = os,
	            path = path,
	            raise = raise,
	            get_config = get_config
	        }
	    )
	end)

    on_config(function(target)
        local function set_bool(name, value)
            target:set("configvar", name, value and 1 or 0)
        end

        local use_curses = has_config("curses")
            and has_package("ncurses")

        local curses_headers = {
            CURSES_HAVE_CURSES_H = "curses.h",
            CURSES_HAVE_NCURSES_H = "ncurses.h",
            CURSES_HAVE_NCURSES_NCURSES_H = "ncurses/ncurses.h",
            CURSES_HAVE_NCURSES_CURSES_H = "ncurses/curses.h",
            CURSES_HAVE_NCURSESW_NCURSES_H = "ncursesw/ncurses.h",
            CURSES_HAVE_NCURSESW_CURSES_H = "ncursesw/curses.h"
        }

        for variable, header in pairs(curses_headers) do
            set_bool(
                variable,
                use_curses and target:has_cxxincludes(header)
            )
        end

        import("lib.detect.has_cxxincludes")

        local have_endian_h = has_cxxincludes("endian.h", {
            target = target,
            configs = {
                languages = "gnuxx17"
            }
        })

        set_bool("HAVE_ENDIAN_H", have_endian_h)

        set_bool(
            "HAVE_STRLCPY",
            target:has_cxxfuncs("strlcpy", {
                includes = "string.h"
            })
        )

        set_bool(
            "HAVE_MALLOC_TRIM",
            is_plat("linux") and target:has_cxxfuncs("malloc_trim", {
                includes = "malloc.h"
            })
        )
    end)
rule_end()

-- Common Sources (Compiled separately for Client and Server due to MT_BUILDTARGET)
local common_srcs = {
    -- Root src/
    "src/clientdynamicinfo.cpp",
    "src/collision.cpp",
    "src/content_mapnode.cpp",
    "src/defaultsettings.cpp",
    "src/emerge.cpp",
    "src/environment.cpp",
    "src/filesys.cpp",
    "src/gettext.cpp",
    "src/inventorymanager.cpp",
    "src/itemdef.cpp",
    "src/light.cpp",
    "src/main.cpp",
    "src/map_settings_manager.cpp",
    "src/map.cpp",
    "src/mapblock.cpp",
    "src/mapnode.cpp",
    "src/mapsector.cpp",
    "src/nodedef.cpp",
    "src/pathfinder.cpp",
    "src/player.cpp",
    "src/porting.cpp",
    "src/raycast.cpp",
    "src/reflowscan.cpp",
    "src/remoteplayer.cpp",
    "src/rollback_interface.cpp",
    "src/server.cpp",
    "src/serverenvironment.cpp",
    "src/servermap.cpp",
    "src/translation.cpp",
    "src/version.cpp",
    "src/voxel.cpp",
    "src/voxelalgorithms.cpp",
    -- Mapgen
    "src/mapgen/*.cpp",
    -- Server
    "src/server/*.cpp",
    -- Server Network
    "src/network/serveropcodes.cpp",
    "src/network/serverpackethandler.cpp",
    -- Common Scripting
    "src/script/scripting_server.cpp",
    "src/script/scripting_emerge.cpp",
    "src/script/common/*.cpp",
    -- Common C++ API
    "src/script/cpp_api/s_async.cpp",
    "src/script/cpp_api/s_base.cpp",
    "src/script/cpp_api/s_entity.cpp",
    "src/script/cpp_api/s_env.cpp",
    "src/script/cpp_api/s_inventory.cpp",
    "src/script/cpp_api/s_item.cpp",
    "src/script/cpp_api/s_mapgen.cpp",
    "src/script/cpp_api/s_modchannels.cpp",
    "src/script/cpp_api/s_node.cpp",
    "src/script/cpp_api/s_nodemeta.cpp",
    "src/script/cpp_api/s_player.cpp",
    "src/script/cpp_api/s_security.cpp",
    "src/script/cpp_api/s_server.cpp",
    -- Common Lua API
    "src/script/lua_api/l_areastore.cpp",
    "src/script/lua_api/l_async.cpp",
    "src/script/lua_api/l_auth.cpp",
    "src/script/lua_api/l_base.cpp",
    "src/script/lua_api/l_craft.cpp",
    "src/script/lua_api/l_env.cpp",
    "src/script/lua_api/l_http.cpp",
    "src/script/lua_api/l_inventory.cpp",
    "src/script/lua_api/l_ipc.cpp",
    "src/script/lua_api/l_item.cpp",
    "src/script/lua_api/l_itemstackmeta.cpp",
    "src/script/lua_api/l_mapgen.cpp",
    "src/script/lua_api/l_metadata.cpp",
    "src/script/lua_api/l_modchannels.cpp",
    "src/script/lua_api/l_nodemeta.cpp",
    "src/script/lua_api/l_nodetimer.cpp",
    "src/script/lua_api/l_noise.cpp",
    "src/script/lua_api/l_object.cpp",
    "src/script/lua_api/l_particles.cpp",
    "src/script/lua_api/l_playermeta.cpp",
    "src/script/lua_api/l_rollback.cpp",
    "src/script/lua_api/l_server.cpp",
    "src/script/lua_api/l_settings.cpp",
    "src/script/lua_api/l_storage.cpp",
    "src/script/lua_api/l_util.cpp",
    "src/script/lua_api/l_vmanip.cpp"
}

if is_plat("android") then
    table.insert(common_srcs, "src/porting_android.cpp")
end

if has_config("unittests") or has_config("benchmarks") then
    table.insert(common_srcs, "src/catch.cpp")
end

if has_config("unittests") then
    table.join2(common_srcs, {
        "src/test/*.cpp",
        "src/unittest/test.cpp",
        "src/unittest/test_address.cpp",
        "src/unittest/test_authdatabase.cpp",
        "src/unittest/test_activeobject.cpp",
        "src/unittest/test_areastore.cpp",
        "src/unittest/test_ban.cpp",
        "src/unittest/test_collision.cpp",
        "src/unittest/test_compression.cpp",
        "src/unittest/test_connection.cpp",
        "src/unittest/test_craft.cpp",
        "src/unittest/test_datastructures.cpp",
        "src/unittest/test_filesys.cpp",
        "src/unittest/test_inventory.cpp",
        "src/unittest/test_irrptr.cpp",
        "src/unittest/test_logging.cpp",
        "src/unittest/test_lbmmanager.cpp",
        "src/unittest/test_lua.cpp",
        "src/unittest/test_map.cpp",
        "src/unittest/test_mapblock.cpp",
        "src/unittest/test_mapdatabase.cpp",
        "src/unittest/test_mapgen.cpp",
        "src/unittest/test_map_settings_manager.cpp",
        "src/unittest/test_mapnode.cpp",
        "src/unittest/test_modchannels.cpp",
        "src/unittest/test_modstoragedatabase.cpp",
        "src/unittest/test_moveaction.cpp",
        "src/unittest/test_noderesolver.cpp",
        "src/unittest/test_noise.cpp",
        "src/unittest/test_objdef.cpp",
        "src/unittest/test_profiler.cpp",
        "src/unittest/test_random.cpp",
        "src/unittest/test_sao.cpp",
        "src/unittest/test_schematic.cpp",
        "src/unittest/test_scriptapi.cpp",
        "src/unittest/test_serialization.cpp",
        "src/unittest/test_server_shutdown_state.cpp",
        "src/unittest/test_settings.cpp",
        "src/unittest/test_socket.cpp",
        "src/unittest/test_servermodmanager.cpp",
        "src/unittest/test_threading.cpp",
        "src/unittest/test_utilities.cpp",
        "src/unittest/test_voxelarea.cpp",
        "src/unittest/test_voxelalgorithms.cpp",
        "src/unittest/test_voxelmanipulator.cpp",
        "src/unittest/test_gettext.cpp"
    })
end

if has_config("benchmarks") then
    table.insert(common_srcs, "src/benchmark/*.cpp")
end

-- ============================================================================
-- Additional Common Sources
-- ============================================================================
-- Share the source list, not compiled objects. Each executable must compile
-- these files with its own MT_BUILDTARGET and generated configuration header.
table.join2(common_srcs, {
    "src/activeobject.cpp",
    "src/chat.cpp",
    "src/content_nodemeta.cpp",
    "src/convert_json.cpp",
    "src/craftdef.cpp",
    "src/debug.cpp",
    "src/face_position_cache.cpp",
    "src/gettext_plural_form.cpp",
    "src/httpfetch.cpp",
    "src/hud_element.cpp",
    "src/inventory.cpp",
    "src/itemstackmetadata.cpp",
    "src/log.cpp",
    "src/metadata.cpp",
    "src/modchannels.cpp",
    "src/nameidmapping.cpp",
    "src/nodemetadata.cpp",
    "src/nodetimer.cpp",
    "src/noise.cpp",
    "src/objdef.cpp",
    "src/object_properties.cpp",
    "src/particles.cpp",
    "src/profiler.cpp",
    "src/serialization.cpp",
    "src/settings.cpp",
    "src/sound_spec.cpp",
    "src/staticobject.cpp",
    "src/terminal_chat_console.cpp",
    "src/texture_override.cpp",
    "src/tileanimation.cpp",
    "src/tool.cpp",

    -- Independent subsystems
    "src/content/*.cpp",
    "src/database/*.cpp",
    "src/threading/*.cpp",
    "src/util/*.cpp",
    "src/network/address.cpp",
    "src/network/connection.cpp",
    "src/network/mtp/impl.cpp",
    "src/network/mtp/threads.cpp",
    "src/network/networkpacket.cpp",
    "src/network/networkprotocol.cpp",
    "src/network/socket.cpp"
})

-- ============================================================================
-- Client Target ("luanti")
-- ============================================================================
if has_config("client") then
    target("luanti")
    	add_rules("luanti.configure")
        if is_plat("android") then
            set_kind("shared")
        else
            set_kind("binary")
        end

        if not is_cross() then
            set_targetdir("$(projectdir)/bin")
        end

        if has_config("run_in_place") then
            set_rundir("$(projectdir)")
        end

        add_defines("MT_BUILDTARGET=1")

        -- Common + Client Sources
        add_files(common_srcs)
        add_files(
            "src/client/*.cpp",
            "src/client/meshgen/*.cpp",
            "src/client/render/*.cpp",
            "src/client/shadows/*.cpp",
            "src/gui/*.cpp",
            "src/irrlicht_changes/*.cpp",
            "src/network/clientopcodes.cpp",
            "src/network/clientpackethandler.cpp",
            -- Client Scripting
            "src/script/scripting_mainmenu.cpp",
            "src/script/scripting_client.cpp",
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
        )

        if has_config("unittests") then
            add_files(
                "src/test/client/*.cpp",
                "src/unittest/mesh_compare.cpp",
                "src/unittest/test_clientactiveobjectmgr.cpp",
                "src/unittest/test_content_mapblock.cpp",
                "src/unittest/test_eventmanager.cpp",
                "src/unittest/test_gameui.cpp",
                "src/unittest/test_keycode.cpp",
                "src/unittest/test_mesh_compare.cpp"
            )
        end

        if is_plat("windows", "mingw") then
            add_files("misc/winresource.rc")
        end
end

-- ============================================================================
-- Server Target ("luantiserver")
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

        add_files(common_srcs)

        if is_plat("windows", "mingw") then
            add_files("misc/winresource.rc")
        end
end
