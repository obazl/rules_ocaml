load("//ocaml:providers.bzl",
     "AdjunctDepsMarker",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "OcamlLibraryMarker",
     "PpxLibraryMarker",
     # "OpamDepsMarker"
     )

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath"
)

load(":impl_common.bzl",
     "dsorder",
     "merge_deps")

#############################
def impl_library(ctx):

    debug = False
    # if (ctx.label.name == "zexe_backend_common"):
    #     debug = True

    if debug:
        print("LIBRARY TARGET: %s" % ctx.label.name)

    ## FIXME: do we need OCAMLFIND_IGNORE here?

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

    # indirect_opam_depsets  = []

    indirect_adjunct_depsets = []
    indirect_adjunct_path_depsets = []
    # indirect_adjunct_opam_depsets  = []

    indirect_cc_deps  = {}

    ################
    merge_deps(ctx.attr.modules,
               merged_module_links_depsets,
               merged_archive_links_depsets,
               merged_paths_depsets,
               merged_depgraph_depsets,
               merged_archived_modules_depsets,
               # indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               # indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    ## Library targets do not produce anything, they just pass on their deps.
    #######################
    #######################
    ctx.actions.do_nothing(
        mnemonic = "OcamlLibrary" if ctx.attr._rule == "ocaml_library" else "PpxLibrary",
        inputs = depset(transitive=merged_depgraph_depsets)
    )
    #######################
    #######################

    defaultInfo = DefaultInfo(
        files = depset(
            order = dsorder,
            transitive = merged_module_links_depsets
        )
    )

    module_links     = depset(
        order = dsorder,
        transitive = merged_module_links_depsets
    )
    archive_links = depset(
        order = dsorder,
        transitive = merged_archive_links_depsets
    )
    paths_depset = depset(
        transitive = merged_paths_depsets
    )
    depgraph = depset(
        order = dsorder,
        transitive = merged_depgraph_depsets
    )
    archived_modules = depset(
        order = dsorder,
        transitive = merged_archived_modules_depsets
    )

    if ctx.attr._rule == "ocaml_library":
        libraryMarker = OcamlLibraryMarker(
            module_links = module_links,
            archive_links = archive_links,
            paths = paths_depset,
            depgraph = depgraph,
            archived_modules = archived_modules
        )
    elif ctx.attr._rule == "ppx_library":
        libraryMarker = PpxLibraryMarker(
            module_links     = depset(
                order = dsorder,
                transitive = merged_module_links_depsets
            ),
            archive_links = depset(
                order = dsorder,
                transitive = merged_archive_links_depsets
            ),
            paths    = depset(
                transitive = merged_paths_depsets
            ),
            depgraph = depset(
                order = dsorder,
                transitive = merged_depgraph_depsets
            ),
            archived_modules = depset(
                order = dsorder,
                transitive = merged_archived_modules_depsets
            ),
        )
    else:
        fail("Unexpected rule type: %s" % ctx.attr._rule)

    ppx_adjuncts_depset = depset(transitive = indirect_adjunct_depsets)
    adjunctsMarker = AdjunctDepsMarker(
        # opam        = depset(transitive = indirect_adjunct_opam_depsets),
        nopam       = ppx_adjuncts_depset,
        nopam_paths = depset(transitive = indirect_adjunct_path_depsets)
    )

    # opam_depset = depset(transitive = indirect_opam_depsets)
    # opamMarker = OpamDepsMarker(
    #     pkgs = opam_depset
    # )

    cclibs = {}
    if len(indirect_cc_deps) > 0:
        if debug:
            print("cc deps for %s" % ctx.label)
            print(indirect_cc_deps)
        cclibs.update(indirect_cc_deps)
    ccMarker = CcDepsProvider(
        ## WARNING: cc deps must be passed as a dictionary, not a file depset!!!
        ccdeps_map = cclibs
    )
    cclib_files = []
    for tgt in cclibs.keys():
        cclib_files.extend(tgt.files.to_list())
    cclib_files_depset = depset(cclib_files)

    outputGroupInfo = OutputGroupInfo(
        module_links  = module_links,
        archive_links = archive_links,
        depgraph = depgraph,
        archived_modules = archived_modules,
        ppx_adjuncts = ppx_adjuncts_depset,
        cclibs = cclib_files_depset,
        all_files = depset(transitive=[
            module_links,
            archive_links,
            ppx_adjuncts_depset,
            cclib_files_depset
        ])
    )

    return [
        defaultInfo,
        outputGroupInfo,
        libraryMarker,
        # opamMarker,
        adjunctsMarker,
        ccMarker
    ]

