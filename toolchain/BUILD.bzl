load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "C_COMPILE_ACTION_NAME")

load("//ocaml:providers.bzl",
     "OcamlArchiveMarker",
     "OcamlExecutableMarker",
     "OcamlImportMarker")

load("//ocaml/_debug:colors.bzl", "CCRED", "CCMAG", "CCRESET")

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

def _linker(ctx, cctc):
    print(CCRED + "link experiment")
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
        print("{c}{item}".format(c=CCRED, item=item))
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
    print("**** host platform frags: %s" % ctx.host_fragments.platform)
    ds = dir(ctx.host_fragments.platform)
    for d in ds:
        print("\t{d}:\n\t{dval}".format(
            d = d, dval = getattr(ctx.host_fragments.platform, d)))
        _platform = ctx.host_fragments.platform.platform

    print("**** target platform frags: %s" % ctx.fragments.platform)
    ds = dir(ctx.fragments.platform)
    for d in ds:
        print("\t{d}:\n\t{dval}".format(
            d = d, dval = getattr(ctx.host_fragments.platform, d)))
    _platform = ctx.host_fragments.platform.platform

    if ctx.host_fragments.apple:
        _cc_opts = ["-Wl,-no_compact_unwind"]
        print("**** host apple frags: %s" % ctx.host_fragments.apple)
        ds = dir(ctx.host_fragments.apple)
        for d in ds:
            print("\t{d}:\n\t{dval}".format(
                d = d, dval = getattr(ctx.host_fragments.apple, d)))
    else:
        _cc_opts = []

    print("**** host cpp frags: %s" % ctx.host_fragments.cpp)
    ds = dir(ctx.fragments.cpp)
    for d in ds:
        print("\t{d}:\n\t{dval}".format(
            d = d,
            dval = getattr(ctx.fragments.cpp, d) if d != "custom_malloc" else ""))

    print("**** target cpp frags: %s" % ctx.fragments.cpp)
    ds = dir(ctx.fragments.cpp)
    for d in ds:
        print("\t{d}:\n\t{dval}".format(
            d = d,
            dval = getattr(ctx.fragments.cpp, d) if d != "custom_malloc" else ""))

## obtaining CC toolchain:  https://github.com/bazelbuild/bazel/issues/7260

## two tc adapters, one for targeting vm, one for sys

################################################################
def _ocaml_toolchain_adapter_impl(ctx):
    # print("\n\t_ocaml_toolchain_impl")

    debug_cctc  = False
    debug_frags = False

    if debug_cctc:
        print("_cc_toolchain: %s" % ctx.attr._cc_toolchain)
        for d in dir(ctx.attr._cc_toolchain):
            print(CCRED + "d %s" % d)
            print("  %s" % getattr(ctx.attr._cc_toolchain, d))

    ## On Linux, this yields a ToolchainInfo provider.
    ## But on MacOS, it yields "dummy cc toolchain".
    # cctc = ctx.toolchains["@bazel_tools//tools/cpp:toolchain_type"]
    # if debug_cctc: print("CC TOOLCHAIN: %s" % cctc)

    # if debug_frags:
    #     _dump_tc_frags(ctx)

    ## This returns a CcToolchainInfo provider on both platforms:
    # cctc = find_cpp_toolchain(ctx)

    # if debug_cctc:
    #     _dump_cc_toolchain(ctx)

    # cctc_config = cc_common.CcToolchainInfo
    # if debug_cctc: print("cctc_config: %s" % cctc_config)

    # print("in {}, the enabled features are {}".format(ctx.label.name, ctx.features))
    ## ctx.features == []

    # feature_configuration = cc_common.configure_features(
    #     ctx = ctx,
    #     cc_toolchain = cctc,
    #     requested_features = ctx.features,
    #     unsupported_features = ctx.disabled_features,
    # )
    # if debug_cctc:
    #     print("feature_configuration t: %s" % type(feature_configuration))
    #     print("feature_configuration: %s" % feature_configuration)
    #     # print(" lto_backend: %s" % feature_configuration.lto_backend)

    # x = cctc.static_runtime_lib(feature_configuration=feature_configuration)
    # print("STATIC_RUNTIME_LIB: %s" % x)

    # _c_exe = cc_common.get_tool_for_action(
    #     feature_configuration = feature_configuration,
    #     action_name = C_COMPILE_ACTION_NAME,
    # )
    # if debug_cctc: print("c_exe: %s" % _c_exe)

    # if not ctx.attr.linkmode in ["static", "dynamic"]:
    #     fail("Bad value '{actual}' for attrib 'link'. Allowed values: 'static', 'dynamic' (in rule: ocaml_toolchain(name=\"{n}\"), build file: \"{bf}\", workspace: \"{ws}\"".format(
    #         ws = ctx.workspace_name,
    #         bf = ctx.build_file_path,
    #         n = ctx.label.name,
    #         actual = ctx.attr.linkmode
    #     )
    #          )

    version = ctx.attr.version[BuildSettingInfo].value
    segs = version.split(".")
    v = struct(version = version,
               major = int(segs[0]))

    return [platform_common.ToolchainInfo(
        # Public fields
        name                   = ctx.label.name,
        ## fixme: rename build_host, target_host
        host                   = ctx.attr.host,
        target                 = ctx.attr.target,
        compiler               = ctx.file.compiler,
        version                = v, # ctx.attr.version,
        vmruntime              = ctx.file.vmruntime,
        vmruntime_debug        = ctx.file.vmruntime_debug,
        vmruntime_instrumented = ctx.file.vmruntime_instrumented,
        vmlibs                 = ctx.files.vmlibs,

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

        "repl": attr.label(
            doc = "A/k/a 'toplevel': 'ocaml' command.",
            allow_single_file = True,
            executable = True,
            cfg = "exec",
        ),

        "vmruntime": attr.label(
            doc = "ocamlrun, usually",
            allow_single_file = True, executable = True, cfg = "exec"
        ),
        "vmruntime_debug": attr.label(
            doc = "ocamlrund",
            allow_single_file = True, executable = True, cfg = "exec"
        ),
        "vmruntime_instrumented": attr.label(
            doc = "Usually the standard 'ocamlrun' interpreter.",
            allow_single_file = True, executable = True, cfg = "exec"
        ),



        "vmlibs": attr.label(
            doc = "Dynamically-loadable libs needed by the ocamlrun vm. Standard location: lib/stublibs. The libs are usually named 'dll<name>_stubs.so', e.g. 'dllcore_unix_stubs.so'.",
            allow_files = True,
        ),

        "compiler": attr.label(
            executable = True,
            ## providers constraints seem to be ignored
            # providers = [["OcamlArchiveMarker"]],
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

        ## https://bazel.build/docs/integrating-with-rules-cc
        ## hidden attr required to make find_cpp_toolchain work:
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")
        ),
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

    ## ocaml toolchain adapter depends on cc toolchain?
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"]
)
