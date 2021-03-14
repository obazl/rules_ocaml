load("//ocaml:providers.bzl",
     "AdjunctDepsProvider",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlLibraryProvider",
     "PpxLibraryProvider",
     "OpamDepsProvider")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath"
)

load(":impl_common.bzl",
     "merge_deps")

#############################
def impl_library(ctx):

    debug = False
    # if (ctx.label.name == "zexe_backend_common"):
    #     debug = True

    if debug:
        print("LIBRARY TARGET: %s" % ctx.label.name)

    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    build_deps = []  # for the command line
    includes   = []
    dep_graph  = []  # for the run action inputs

    ################
    direct_file_deps = []
    indirect_file_depsets  = []

    indirect_opam_depsets  = []

    indirect_adjunct_depsets = []
    indirect_adjunct_path_depsets = []
    indirect_adjunct_opam_depsets  = []

    indirect_path_depsets  = []

    direct_resolver = None

    direct_cc_deps  = {}
    indirect_cc_deps  = {}
    ################

    merge_deps(ctx.attr.modules,
               indirect_file_depsets,
               indirect_path_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    ## Library targets do not produce anything, they just pass on their deps.
    #######################
    ctx.actions.do_nothing(
        mnemonic = "OcamlLibrary" if ctx.attr._rule == "ocaml_library" else "PpxLibrary",
        inputs = depset(transitive=indirect_file_depsets)
    )
    #######################

    defaultInfo = DefaultInfo(
        files = depset(
            order = "postorder",
            transitive = indirect_file_depsets
        )
    )

    defaultMemo = DefaultMemo(
        paths  = depset(transitive=indirect_path_depsets),
    )

    if ctx.attr._rule == "ocaml_library":
        libraryProvider = OcamlLibraryProvider(
        )
    elif ctx.attr._rule == "ppx_library":
        libraryProvider = PpxLibraryProvider(
        )
    else:
        fail("Unexpected rule type: %s" % ctx.attr._rule)

    adjunctsProvider = AdjunctDepsProvider(
        opam        = depset(transitive = indirect_adjunct_opam_depsets),
        nopam       = depset(transitive = indirect_adjunct_depsets),
        nopam_paths = depset(transitive = indirect_adjunct_path_depsets)
    )

    opam_depset = depset(transitive = indirect_opam_depsets)
    opamProvider = OpamDepsProvider(
        pkgs = opam_depset
    )

    cclibs = {}
    # cclibs.update(ctx.attr.cc_deps)
    if len(indirect_cc_deps) > 0:
        if debug:
            print("cc deps for %s" % ctx.label)
            print(indirect_cc_deps)
        cclibs.update(indirect_cc_deps)
    ccProvider = CcDepsProvider(
        ## WARNING: cc deps must be passed as a dictionary, not a file depset!!!
        libs = cclibs

    )

    return [
        defaultInfo,
        defaultMemo,
        libraryProvider,
        opamProvider,
        adjunctsProvider,
        ccProvider
    ]

