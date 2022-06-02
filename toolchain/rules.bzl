load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "C_COMPILE_ACTION_NAME")


load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
     "OcamlArchiveMarker",
     "OcamlExecutableMarker",
     "OcamlImportMarker")

## obtaining CC toolchain:  https://github.com/bazelbuild/bazel/issues/7260
################################################################
_ocaml_tools_attrs = {

    "linkmode": attr.string(
        doc = "Default link mode: 'static' or 'dynamic'"
        # default = "static"
    ),

    ## hidden attr required to make find_cpp_toolchain work:
    "_cc_toolchain": attr.label(
        default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")
    ),
    # "_cc_opts": attr.string_list(
    #     default = ["-Wl,-no_compact_unwind"]
    # ),

    "ocamlrun": attr.label(
        # default = Label("//runtime:ocamlrun"),
        executable = True,
        allow_single_file = True,
        cfg = "exec",
    ),

    "ocamlc": attr.label(
        executable = True,
        ## providers constraints seem to be ignored
        # providers = [["OcamlArchiveMarker"]],
        allow_single_file = True,
        cfg = "exec",
    ),

    "ocamlc_opt": attr.label(
        # default = Label("@rules_ocaml//cfg/bin:ocamlc.opt"),
        executable = True,
        allow_single_file = True,
        cfg = "exec",
    ),
    "ocamlopt": attr.label(
        # default = Label("@rules_ocaml//cfg/bin:ocamlopt"),
        executable = True,
        allow_single_file = True,
        cfg = "exec",
    ),
    "ocamlopt_opt": attr.label(
        # default = Label("@rules_ocaml//cfg/bin:ocamlopt.opt"),
        executable = True,
        allow_single_file = True,
        cfg = "exec",
    ),
    "ocamllex": attr.label(
        # default = Label("@rules_ocaml//cfg/bin:ocamllex"),
        executable = True,
        allow_single_file = True,
        cfg = "exec",
    ),
    "ocamlyacc": attr.label(
        # default = Label("@rules_ocaml//cfg/bin:ocamlyacc"),
        executable = True,
        allow_single_file = True,
        cfg = "exec",
    ),

    ## stdlib?

    "_dllpath": attr.label(
        ## FIXME default = Label("@opam//pkg:stublibs"),
    )

    # "_coqc": attr.label(
    #     default = Label("//tools:coqc"),
    #     executable = True,
    #     allow_single_file = True,
    #     cfg = "exec",
    # ),
}

def _ocaml_toolchain_impl(ctx):
    # print("\n\t_ocaml_toolchain_impl")

    # print("platform frag: %s" % ctx.host_fragments.platform)
    # ds = dir(ctx.host_fragments.platform)
    # for d in ds:
    #     print("\n\t{d}: {dval}".format(
    #         d = d, dval = getattr(ctx.host_fragments.platform, d)))
    # _platform = ctx.host_fragments.platform.platform

    if ctx.host_fragments.apple:
        _cc_opts = ["-Wl,-no_compact_unwind"]
    else:
        _cc_opts = []

    # print("apple frag: %s" % ctx.host_fragments.apple)
    # ds = dir(ctx.host_fragments.apple)
    # for d in ds:
    #     print("\n\t{d}: {dval}".format(
    #         d = d, dval = getattr(ctx.host_fragments.apple, d)))

    # print("cpp frag: %s" % ctx.fragments.cpp)
    # ds = dir(ctx.fragments.cpp)
    # for d in ds:
    #     print("\n\t{d}: {dval}".format(
    #         d = d,
    #         dval = getattr(ctx.fragments.cpp, d) if d != "custom_malloc" else ""))

    the_cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = the_cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    _c_exe = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = C_COMPILE_ACTION_NAME,
    )
    # print("c_exe: %s" % _c_exe)
    if not ctx.attr.linkmode in ["static", "dynamic"]:
        fail("Bad value '{actual}' for attrib 'link'. Allowed values: 'static', 'dynamic' (in rule: ocaml_toolchain(name=\"{n}\"), build file: \"{bf}\", workspace: \"{ws}\"".format(
            ws = ctx.workspace_name,
            bf = ctx.build_file_path,
            n = ctx.label.name,
            actual = ctx.attr.linkmode
        )
             )
    # if not ctx.attr.mode in ["native", "bytecode"]:
    #     fail("Bad value '{actual}' for attrib 'mode'. Allowed values: 'native', 'bytecode' (in rule: ocaml_toolchain(name=\"{n}\"), build file: \"{bf}\", workspace: \"{ws}\"".format(
    #         ws = ctx.workspace_name,
    #         bf = ctx.build_file_path,
    #         n = ctx.label.name,
    #         actual = ctx.attr.mode
    #     )
    #          )
    # mode = ctx.attr.mode[CompilationModeSettingProvider].value

    return [platform_common.ToolchainInfo(
        # Public fields
        name = ctx.label.name,
        linkmode       = ctx.attr.linkmode,
        ocamlc     = ctx.file.ocamlc,
        ocamlc_opt = ctx.file.ocamlc_opt,
        ocamlopt   = ctx.file.ocamlopt,
        ocamlopt_opt = ctx.file.ocamlopt_opt,
        ocamllex   = ctx.file.ocamllex,
        ocamlyacc  = ctx.file.ocamlyacc,

        # stdlib?
        # dllpath    = ctx.path(Label("@opam//pkg:stublibs"))

        # cc_toolchain = ctx.attr.cc_toolchain,
        ## rules add [cc_toolchain.all_files] to action inputs
        ## at least, rules linking to cc libs must do this;
        ## pure ocaml code need not?
        cc_toolchain = the_cc_toolchain,
        cc_exe = _c_exe, ## to be passed via `-cc` (will be a sh script on mac)

        cc_opts = _cc_opts,

        ## config frag.cpp fld `linkopts` contains whatever was passed
        ## by CLI using `--linkopt`
        linkopts  = None,

        # ocamlbuild = ctx.attr._ocamlbuild.files.to_list()[0],
        # ocamlfind  = ctx.attr._ocamlfind.files.to_list()[0],
        # ocamldep   = ctx.attr._ocamldep.files.to_list()[0],
        # objext     = ".cmx" if mode == "native" else ".cmo",
        # archext    = ".cmxa" if mode == "native" else ".cma",
    )]

ocaml_toolchain = rule(
    _ocaml_toolchain_impl,
    attrs = _ocaml_tools_attrs,
    doc = "Defines a Ocaml toolchain.",
    provides = [platform_common.ToolchainInfo],

    ## NB: config frags evidently expose CLI opts like `--cxxopt`;
    ## see https://docs.bazel.build/versions/main/skylark/lib/cpp.html
    fragments = ["cpp", "apple", "platform"],
    host_fragments = ["apple", "platform"],
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"]
)