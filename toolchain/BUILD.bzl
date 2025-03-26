load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("@rules_cc//cc:find_cc_toolchain.bzl",
     "CC_TOOLCHAIN_ATTRS", # for bazel 6.x, 7.x compatibility
     "find_cpp_toolchain", "use_cc_toolchain")
load("@rules_cc//cc:action_names.bzl",
     "ACTION_NAMES",
     "C_COMPILE_ACTION_NAME",
     "CPP_LINK_EXECUTABLE_ACTION_NAME")

# load("@bazel_tools//tools/cpp:toolchain_utils.bzl",
#      "find_cpp_toolchain")

# load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "C_COMPILE_ACTION_NAME")

# load("//build:providers.bzl",
#      "OCamlArchiveProvider",
#      "OcamlExecutableMarker",
#      "OCamlImportProvider")

# load("//lib:colors.bzl", "CCRED", "CCMAG", "CCRESET")

def toolchain_selector(name, toolchain,
                       toolchain_type = "@rules_ocaml//toolchain/type:std",
                       build_host_constraints=None,
                       target_host_constraints=None,
                       toolchain_constraints=None,
                       visibility = ["//visibility:public"]):
    native.toolchain(
        name                   = name,
        toolchain              = toolchain,
        toolchain_type         = toolchain_type,
        exec_compatible_with   = build_host_constraints,
        target_settings        = toolchain_constraints,
        target_compatible_with = target_host_constraints,
        visibility             = visibility
    )

def _dump_linker(ctx, cctc):
    print("link experiment")
    static_libs   = []
    dynamic_libs  = []

    linker_inputs = []
    linking_ctx = cc_common.create_linking_context(
        linker_inputs = depset(linker_inputs, order = "topological"),
    )
    print("linking_context: %s" % linking_ctx)
    linker_inputs = linking_ctx.linker_inputs.to_list()
    for linput in linker_inputs:
        libs = linput.libraries
        if len(libs) > 0:
            for lib in libs:
                if lib.pic_static_library:
                    static_libs.append(lib.pic_static_library)
                    # action_inputs_list.append(lib.pic_static_library)
                    # args.add(lib.pic_static_library.path)
                if lib.static_library:
                    static_libs.append(lib.pic_static_library)
                    # action_inputs_list.append(lib.static_library)
                    # args.add(lib.static_library.path)
                if lib.dynamic_library:
                    dynamic_libs.append(lib.dynamic_library)
                    # action_inputs_list.append(lib.dynamic_library)
                    # args.add("-ccopt", "-L" + lib.dynamic_library.dirname)
                    # args.add("-cclib", lib.dynamic_library.path)

    print("static_libs: %s" % static_libs)
    print("dynamic_libs: %s" % dynamic_libs)

    # linking_outputs = cc_common.link(
    #     actions = ctx.actions,
    #     feature_configuration = feature_configuration,
    #     cc_toolchain = cctc,
    #     linking_contexts = [linking_context],
    #     # user_link_flags = user_link_flags,
    #     # additional_inputs = ctx.files.additional_linker_inputs,
    #     name = ctx.label.name,
    #     output_type = "dynamic_library",
    # )
    # print("linking_outputs: %s" % linking_outputs)

################
def _dump_cc_toolchain(ctx):
    print("**** CcToolchainInfo ****")

    cctc = find_cpp_toolchain(ctx)
    print("cctc type: %s" % type(cctc))
    items = dir(cctc)
    for item in items:
        # print("{c}{item}".format(c=CCRED, item=item))
        val = getattr(cctc, item)
        print("  t: %s" % type(val))
        # if item == "dynamic_runtime_lib":
        #     print(":: %s" % cctc.dynamic_runtime_lib(
        #         feature_configuration = cc_common.configure_features(
        #             ctx = ctx,
        #             cc_toolchain = cctc,
        #             requested_features = ctx.features,
        #             unsupported_features = ctx.disabled_features,
        #         )
        #     ))
        # if item == "linker_files":
        #     print(":: %s" % cctc.linker_files)

################
def _dump_tc_frags(ctx):

    print("**** platform frags: %s" % ctx.fragments.platform)
    ds = dir(ctx.fragments.platform)
    for d in ds:
        print("\t{d}:\n\t{dval}".format(
            d = d, dval = getattr(ctx.fragments.platform, d)))
    _platform = ctx.fragments.platform.platform

    if ctx.fragments.apple:
        _cc_opts = ["-Wl,-no_compact_unwind"]
        print("**** host apple frags: %s" % ctx.fragments.apple)
        ds = dir(ctx.fragments.apple)
        for d in ds:
            print("\t{d}:\n\t{dval}".format(
                d = d, dval = getattr(ctx.fragments.apple, d)))
    else:
        _cc_opts = []

    print("**** cpp frags: %s" % ctx.fragments.cpp)
    ds = dir(ctx.fragments.cpp)
    for d in ds:
        print("\t{d}:\n\t{dval}".format(
            d = d,
            dval = getattr(ctx.fragments.cpp, d) if d != "custom_malloc" else ""))

#########################################
def _link_config(ctx, tc, feature_config):

    # adict = apple_common.apple_host_system_env(xcode_config)

    config_map = {}

    c_link_variables = cc_common.create_link_variables(
        feature_configuration = feature_config,
        cc_toolchain = tc,
        # source_file = source_file.path,
        # output_file = output_file.path,
        # preprocessor_defines = depset(defines)
    )

    cmd_line = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_config,
        action_name = ACTION_NAMES.cpp_link_executable,
        variables = c_link_variables,
    )
    # print("LINKOPTS %s" % cmd_line)
    ## NB: this should obtain --mmacos_version_min,
    ## which we pass to ocaml, eliminating warnings
    ## about "object file ... was built for newer version..."
    compile_opts = [
        # options for both sig and struct compiles
        "-keep-locs",
        "-short-paths",
        "-strict-formats",
        "-strict-sequence",
    ]
    module_compile_opts = [ ]
    link_opts = []
    for opt in cmd_line:
        # print("LOPT %s" % opt)
        if opt not in ["-lc++", "-fobjc-link-runtime",
                       "-headerpad_max_install_names",
                       "-lm"  ## why always?
                       ]:
            link_opts.append(opt)

    # NB: man ld on macos says:
    # -O0     Disables certain optimizations and layout algorithms to optimize build time. This option should be used with debug builds
    # to speed up incremental development. The exact implementation might change to match the intent.
    if cc_common.is_enabled(feature_name = "opt",
        feature_configuration = feature_config):
        # print("\nOPT ****************")
        link_opts.append("-Ofast")
        compile_opts.append("-noassert")
        # compile_opts.append("-no-g")
        if ctx.attr.target == "sys":
            module_compile_opts.append("-O3")
    elif cc_common.is_enabled(
        feature_name = "dbg",
        feature_configuration = feature_config):
        # print("\nDBG ****************")
        link_opts.append("-O0")
        compile_opts.append("-opaque")
        compile_opts.append("-g")
        compile_opts.append("-bin-annot")
    else:  ## fastbuild
        # print("\nFASTBUILD ****************")
        link_opts.append("-O0")
        # compile_opts.append("-no-g")
        compile_opts.append("-opaque")
        compile_opts.append("-bin-annot")
        if ctx.attr.target == "sys":
            module_compile_opts.append("-linscan")

    config_map["compile_opts"] = compile_opts
    config_map["module_compile_opts"] = module_compile_opts
    config_map["link_opts"] = link_opts

    link_env = cc_common.get_environment_variables(
        feature_configuration = feature_config,
        action_name = ACTION_NAMES.cpp_link_executable,
        variables = c_link_variables,
    )
    # print("link env: %s"% link_env)
    config_map |= link_env
    # print("config_map: %s" % config_map)

    return config_map

################################################################
def _ocaml_toolchain_adapter_impl(ctx):
    # print("\n\t_ocaml_toolchain_impl")

    debug_cctc  = True
    debug_frags = False

    ## ENHANCEMENT: obtain the link flags from the cc tc.
    ## on macos, they should contain the -mmacos-version-min
    ## flag we need to avoid the link mismatch warning,
    ##   <lib> was built for newer 'macOS' version (14.5)
    ##   than being linked (14.0)

    # if debug_frags:
    #     _dump_tc_frags(ctx)

    ## This returns a CcToolchainInfo provider on both platforms:
    cctc = find_cpp_toolchain(ctx)
    # if debug_cctc:
    #     _dump_cc_toolchain(ctx)

    # cctc_config = cc_common.CcToolchainInfo
    # if debug_cctc: print("cctc_config: %s" % cctc_config)

    # _dump_linker(ctx, cctc)
    # _dump_tc_frags(ctx)

    # print("in {}, the enabled features are {}".format(ctx.label.name, ctx.features))
    ## ctx.features == []

    feature_config = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cctc,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    # print("FC %s" % feature_config)
    # print("FC %s" % feature_config.default_compile_flags)
    # print("F default_compile_flags %s" % cc_common.is_enabled(
    #     feature_configuration = feature_config,
    #     feature_name = "default_compile_flags"))
    # print("F default_link_flags %s" % cc_common.is_enabled(
    #     feature_configuration = feature_config,
    #     feature_name = "default_link_flags"))
    # print("F opt %s" % cc_common.is_enabled(
    #     feature_configuration = feature_config,
    #     feature_name = "opt"))
    # print("F fb %s" % cc_common.is_enabled(
    #     feature_configuration = feature_config,
    #     feature_name = "fastbuild"))
    # print("F dbg %s" % cc_common.is_enabled(
    #     feature_configuration = feature_config,
    #     feature_name = "dbg"))
    # print("F static %s" % cc_common.is_enabled(
    #     feature_configuration = feature_config,
    #     feature_name = "static_linking_mode"))
    # print("F dyn %s" % cc_common.is_enabled(
    #     feature_configuration = feature_config,
    #     feature_name = "dynamic_linking_mode"))

    # if debug_cctc:
    #     print("feature_configuration t: %s" % type(feature_configuration))
    #     print("feature_configuration: %s" % feature_configuration)
    #     # print(" lto_backend: %s" % feature_configuration.lto_backend)

    # x = cctc.static_runtime_lib(feature_configuration=feature_configuration)
    # print("STATIC_RUNTIME_LIB: %s" % x)

    # _c_link = cc_common.get_tool_for_action(
    #     feature_configuration = feature_config,
    #     # action_name = C_COMPILE_ACTION_NAME,
    #     action_name = CPP_LINK_EXECUTABLE_ACTION_NAME
    # )
    # if debug_cctc: print("c_link: %s" % _c_link)

    link_map = _link_config(ctx, cctc, feature_config)

    version = ctx.attr.version[BuildSettingInfo].value
    segs = version.split(".")
    v = struct(version = version,
               major = int(segs[0]))

    ## FIXME: this defines the public API of the tc model
    ## move it to @ocaml_toolchains?
    return [platform_common.ToolchainInfo(
        # Public fields
        name                 = ctx.label.name,
        ## fixme: rename build_host, target_host
        host                 = ctx.attr.host,
        target               = ctx.attr.target,
        compiler             = ctx.file.compiler,
        sigcompiler          = ctx.file.sigcompiler,
        version              = v, # ctx.attr.version,

        # ocaml compile opts, based on compilation mode
        compile_opts         = link_map["compile_opts"],
        module_compile_opts  = link_map["module_compile_opts"],
        cc_link_env_vars     = None,
        cc_link_opts         = link_map["link_opts"],

        default_runtime      = ctx.file.default_runtime,
        std_runtime          = ctx.file.std_runtime,
        dbg_runtime          = ctx.file.dbg_runtime,
        instrumented_runtime = ctx.file.instrumented_runtime,
        pic_runtime          = ctx.file.pic_runtime,
        shared_runtime       = ctx.file.shared_runtime,

        # vmruntime_debug        = ctx.file.vmruntime_debug,
        # vmruntime_instrumented = ctx.file.vmruntime_instrumented,
        dllibs                 = ctx.files.dllibs,
        dllibs_path            = ctx.attr.dllibs_path[BuildSettingInfo].value,

        ocamllex               = ctx.file.ocamllex,
        ocamlyacc              = ctx.file.ocamlyacc,

        ## deprecated:
        ocamlc                 = ctx.file.ocamlc,
        ocamlc_opt             = ctx.file.ocamlc_opt,
        ocamlopt               = ctx.file.ocamlopt,
        ocamlopt_opt           = ctx.file.ocamlopt_opt,
        linkmode               = ctx.attr.linkmode,


        # cc_toolchain = ctx.attr.cc_toolchain,
        ## rules add [cc_toolchain.all_files] to action inputs
        ## at least, rules linking to cc libs must do this;
        ## pure ocaml code need not?
        # cc_toolchain = cctc,
        # cc_exe = _c_exe, ## to be passed via `-cc` (will be a sh script on mac)

        # cc_opts = _cc_opts,

        ## config frag.cpp fld `linkopts` contains whatever was passed
        ## by CLI using `--linkopt`
        linkopts  = None,
    )]

## toolchain adapters bind tc interface to tc implementation
## implementation details are passed via attributes
# or: ocaml_toolchain_binding(
# ocaml_toolchain = rule(
ocaml_toolchain_adapter = rule(
    _ocaml_toolchain_adapter_impl,
    attrs = {
        "host": attr.string(
            doc     = "OCaml host platform: vm (bytecode) or an arch.",
            default = "local"
        ),
        "target": attr.string(
            doc     = "OCaml target platform: vm (bytecode) or an arch.",
            default = "local"
        ),
        "default_runtime": attr.label(
            doc = """
Runtime emitted in linked executables. OCaml linkers are hardcoded to look for one of libasmrun.a, libasmrund.a, libcamlrun.a, etc. at runtime, which makes them runtime deps, so for Bazel we must list a runtime as an explicit dependency.
            """,
            allow_single_file = True,
            executable = False,
        ),
        ## we include all runtimes, so that rules can override
        ## the default, which is controlled
        ## by --@ocaml//toolchain flags
        "std_runtime": attr.label(allow_single_file = True),
        "dbg_runtime": attr.label(allow_single_file = True),
        "instrumented_runtime": attr.label(allow_single_file = True),
        "pic_runtime": attr.label(allow_single_file = True),
        "shared_runtime": attr.label(allow_single_file = True),

        "repl": attr.label(
            doc = "A/k/a 'toplevel': 'ocaml' command.",
            allow_single_file = True,
            executable = True,
            cfg = "exec",
        ),

        #FIXME: rename "interpreter"
        "vmruntime": attr.label(
            doc = "ocamlrun, usually",
            allow_single_file = True,
            executable = True,
            cfg = "exec"
        ),
        "vmruntime_debug": attr.label(
            doc = "ocamlrund",
            allow_single_file = True, executable = True, cfg = "exec"
        ),
        "vmruntime_instrumented": attr.label(
            doc = "Usually the standard 'ocamlrun' interpreter.",
            allow_single_file = True, executable = True, cfg = "exec"
        ),



        "dllibs": attr.label(
            doc = "Dynamically-loadable libs needed by the ocamlrun vm. Standard location: lib/stublibs. The libs are usually named 'dll<name>_stubs.so', e.g. 'dllcore_unix_stubs.so'.",
            allow_files = True,
        ),
        "dllibs_path": attr.label(
            doc = "Label of string_setting target providing absolute path to stublibs dir"
        ),

        "compiler": attr.label(
            executable = True,
            ## providers constraints seem to be ignored
            # providers = [["OcamlArchiveMarker"]],
            allow_single_file = True,
            cfg = "exec",
        ),

        "compile_opts": attr.string_list(
            doc = """
OCaml compile options options derived from cc toolchain and compilation mode."
            """
        ),
        "module_compile_opts": attr.string_list(
            doc = """
OCaml module-only compile options options derived from cc toolchain and compilation mode."
            """
        ),


        "sigcompiler": attr.label(
            doc = "Alway compile sigfiles with this",
            executable = True,
            # providers = [["OCamlArchiveProvider"]],
            allow_single_file = True,
            cfg = "exec",
        ),

        "version": attr.label(
            doc = "Version string of compiler",
            # default = "@ocaml//version"
        ),

        "profiling_compiler": attr.label(
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),

        "cc_link_env_vars": attr.string_dict(),
        "cc_link_opts": attr.string_list(
            doc = "Link options derived from cc toolchain and compilation mode."
        ),

        "ocamllex": attr.label(
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),

        "ocamlyacc": attr.label(
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),

        ## DEPRECATED: with platforms and toolchains the 'compiler'
        ## attribute is sufficient - no need to list all compilers here.
        "ocamlc": attr.label(
            executable = True,
            ## providers constraints seem to be ignored
            # providers = [["OcamlArchiveMarker"]],
            allow_single_file = True,
            cfg = "exec",
        ),

        "ocamlc_opt": attr.label(
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),

        "ocamlopt": attr.label(
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),

        "ocamlopt_opt": attr.label(
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),

        # "_coqc": attr.label(
        #     default = Label("//tools:coqc"),
        #     executable = True,
        #     allow_single_file = True,
        #     cfg = "exec",
        # ),

        "linkmode": attr.string(
            doc = "Default link mode: 'static' or 'dynamic'"
            # default = "static"
        ),

        # "compilation_mode": attr.label(
        #     default = "//command_line_option:compilation_mode"
        # )

        ## https://bazel.build/docs/integrating-with-rules-cc
        ## hidden attr required to make find_cpp_toolchain work:
        # "_cc_toolchain": attr.label(
        #     default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")
        # ),
        # "_cc_opts": attr.string_list(
        #     default = ["-Wl,-no_compact_unwind"]
        # ),
    },

    doc = "Defines a Ocaml toolchain.",
    provides = [platform_common.ToolchainInfo],

    ## NB: config frags evidently expose CLI opts like `--cxxopt`;
    ## see https://docs.bazel.build/versions/main/skylark/lib/cpp.html
    fragments = ["cpp", "apple", "platform"],
    host_fragments = ["cpp", "apple", "platform"],

    ## ocaml toolchain adapter depends on cc toolchain
    # toolchains = ["@bazel_tools//tools/cpp:toolchain_type"]
    toolchains = use_cc_toolchain()
)
