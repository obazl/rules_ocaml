load("//ocaml:providers.bzl",
     "AdjunctDepsProvider",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlArchiveProvider",
     "OcamlImportProvider",
     "OcamlSignatureProvider",
     "OcamlLibraryProvider",
     "PpxLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsArchiveProvider",
     "OcamlNsLibraryProvider",
     "OcamlSDK",
     "OpamDepsProvider")

load("//ocaml:providers.bzl", "PpxArchiveProvider")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath"
)

load(":impl_common.bzl",
     "merge_deps")
     # "tmpdir")


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
    includes = []
    dep_graph = []  # for the run action inputs

    ################
    direct_file_deps = []
    indirect_file_depsets  = []

    indirect_opam_depsets  = []

    indirect_adjunct_depsets = []
    indirect_adjunct_path_depsets = []
    indirect_adjunct_opam_depsets  = []

    indirect_path_depsets  = []

    direct_resolver = None
    indirect_resolver_depsets = []

    direct_cc_deps  = []
    indirect_cc_deps  = []
    ################

    merge_deps(ctx.attr.modules,
               indirect_file_depsets,
               indirect_path_depsets,
               indirect_resolver_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    # ctx.actions.do_nothing(
    #     mnemonic = "OcamlLibrary",
    #     inputs = depset(transitive=indirect_file_depsets)
    # )

    defaultInfo = DefaultInfo(
        files = depset(
            order = "postorder",
            # direct = outputs, # directs,
            transitive = indirect_file_depsets
            # transitive = [mydeps.nopam] # , mydeps.opam]
            # depset(order="postorder", direct = indirects)]
        )
    )

    # search_paths = sets.to_list(sets.make(includes))
    # search_paths.append(obj_cm_.dirname)

    defaultMemo = DefaultMemo(
        paths  = depset(transitive=indirect_path_depsets),
        resolvers = depset(transitive=indirect_resolver_depsets)
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

    return [
        defaultInfo,
        defaultMemo,
        libraryProvider,
        opamProvider,
        adjunctsProvider,
    ]

