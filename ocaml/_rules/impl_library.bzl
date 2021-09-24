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

    ## Library targets do not produce anything, they just pass on their deps.

    ################

    indirect_adjunct_depsets = []
    indirect_adjunct_path_depsets = []

    indirect_cc_deps  = {}

    ################
    paths_direct   = []

    #######################
    ctx.actions.do_nothing(
        mnemonic = "OcamlLibrary" if ctx.attr._rule == "ocaml_library" else "PpxLibrary",
        inputs = depset(transitive=merged_depgraph_depsets)
    )
    #######################

    defaultInfo = DefaultInfo(
        # files = defaultDepset
    )

    ################ ppx adjunct deps ################
    )
    ppxAdjunctsProvider = PpxAdjunctsProvider(
    )

    )

    )
    archived_modules = depset(
        order = dsorder,
        direct = paths_direct,
    )

    ocamlProvider = OcamlProvider(
    )

    # print("ARCHIVE_DEPS_LIST: %s" % archive_deps_list)

    archiveProvider = OcamlArchiveProvider(
    )
    # print("LIB EXPORTING OcamlProvider files: %s" % ocamlProvider)

    outputGroupInfo = OutputGroupInfo(
        ppx_adjuncts = ppx_adjuncts_depset,
        cc = depset(action_inputs_ccdep_filelist),
    )

    return [
        defaultInfo,
        libraryMarker,
        ocamlProvider,
    ]

