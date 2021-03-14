load("//ocaml:providers.bzl",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlNsLibraryProvider",
     "OpamDepsProvider",
     "PpxNsLibraryProvider")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
)

load(":impl_common.bzl", "merge_deps")

#################
def impl_ns_library(ctx):

    debug = False
    # if ctx.label.name in ["logproc_lib"]:
    #     debug = True

    if debug:
        print("")
        print("Start: IMPL_NS_LIBRARY: %s" % ctx.label)

    # name must be legal OCaml module name with '#' prefix
    if not ctx.label.name.startswith("#"):
        fail("NS Library names must start with at least one '#' followed by a legal OCaml module name: %s" % ctx.label.name)

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    aliases = []

    ################
    direct_file_deps = []
    indirect_file_depsets  = []

    indirect_opam_depsets  = []

    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    indirect_adjunct_opam_depsets = []

    indirect_path_depsets  = []

    direct_resolver = None

    direct_cc_deps  = {}
    indirect_cc_deps  = {}
    ################

    resolver_files = None

    submodules = []
    includes   = []

    mydeps = ctx.attr.submodules + ctx.attr._ns_resolver #  + ctx.attr.sublibs
    merge_deps(mydeps,
               indirect_file_depsets,
               indirect_path_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    resolver_dep = ctx.files._ns_resolver

    inputs_depset = depset(
        order = "postorder",
        direct = resolver_dep,
        transitive = indirect_file_depsets
    )

    if debug:
        print("INPUTS_DEPSET: %s" % inputs_depset)

    ## NS Lib targets do not directly produce anything, they just pass
    ## on their deps. The real work is done in the transition
    ## functions, which set the ConfigState that controls build
    ## actions of deps.

    #######################
    ctx.actions.do_nothing(
        mnemonic = "NS_LIB",
        inputs = inputs_depset
    )
    #######################


    defaultInfo = DefaultInfo(
        files = depset(
            order = "postorder",
            transitive = [inputs_depset] + indirect_file_depsets
        )
    )

    defaultMemo = DefaultMemo(
        paths  = depset(transitive=indirect_path_depsets),
    )

    if ctx.attr._rule == "ocaml_ns_library":
        nslibProvider = OcamlNsLibraryProvider(
        )
    else:
        nslibProvider = PpxNsLibraryProvider(
        )

    opam_depset = depset(transitive = indirect_opam_depsets)
    opamProvider = OpamDepsProvider(
        pkgs = opam_depset
    )

    cclibs = {}
    if len(indirect_cc_deps) > 0:
        cclibs.update(indirect_cc_deps)
    ccProvider = CcDepsProvider(
        ## WARNING: cc deps must be passed as a dictionary, not a file depset!!!
        libs = cclibs
    )

    return [
        defaultInfo,
        defaultMemo,
        nslibProvider,
        opamProvider,
        ccProvider
    ]

