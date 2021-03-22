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

    ################
    merged_module_links_depsets = []
    merged_archive_links_depsets = []

    merged_paths_depsets = []
    merged_depgraph_depsets = []
    merged_archived_modules_depsets = []

    indirect_opam_depsets  = []

    indirect_adjunct_depsets = []
    indirect_adjunct_path_depsets = []
    indirect_adjunct_opam_depsets  = []

    direct_cc_deps  = {}
    indirect_cc_deps  = {}
    ################

    merge_deps(ctx.attr.modules,
               merged_module_links_depsets,
               merged_archive_links_depsets,
               merged_paths_depsets,
               merged_depgraph_depsets,
               merged_archived_modules_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    ## Library targets do not produce anything, they just pass on their deps.
    #######################
    ctx.actions.do_nothing(
        mnemonic = "OcamlLibrary" if ctx.attr._rule == "ocaml_library" else "PpxLibrary",
        inputs = depset(transitive=merged_depgraph_depsets)
    )
    #######################

    defaultInfo = DefaultInfo(
        files = depset(
            order = "postorder",
            transitive = merged_module_links_depsets
        )
    )

    if ctx.attr._rule == "ocaml_library":
        libraryProvider = OcamlLibraryProvider(
            module_links     = depset(
                order = "postorder",
                transitive = merged_module_links_depsets
            ),
            archive_links = depset(
                order = "postorder",
                transitive = merged_archive_links_depsets
            ),
            paths    = depset(
                transitive = merged_paths_depsets
            ),
            depgraph = depset(
                order = "postorder",
                transitive = merged_depgraph_depsets
            ),
            archived_modules = depset(
                order = "postorder",
                transitive = merged_archived_modules_depsets
            ),
        )
    elif ctx.attr._rule == "ppx_library":
        libraryProvider = PpxLibraryProvider(
            module_links     = depset(
                order = "postorder",
                transitive = merged_module_links_depsets
            ),
            archive_links = depset(
                order = "postorder",
                transitive = merged_archive_links_depsets
            ),
            paths    = depset(
                transitive = merged_paths_depsets
            ),
            depgraph = depset(
                order = "postorder",
                transitive = merged_depgraph_depsets
            ),
            archived_modules = depset(
                order = "postorder",
                transitive = merged_archived_modules_depsets
            ),
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
        libraryProvider,
        opamProvider,
        adjunctsProvider,
        ccProvider
    ]

