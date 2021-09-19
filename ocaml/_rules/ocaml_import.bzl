load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "OcamlArchiveMarker",
     "OcamlModuleMarker",
     # "OcamlPathsMarker",
     "OcamlImportMarker", # marker

     # "OcamlImportArchivesMarker",
     # "OcamlImportPluginsMarker",
     # "OcamlImportSignaturesMarker",
     # "OcamlImportPathsMarker",
     # "OcamlImportPpxAdjunctsMarker"
     )

load(":impl_common.bzl", "dsorder", "opam_lib_prefix")

## cases: any of the attrs may occur alone.
## in particular 'deps', e.g. pkg camlzip
## in some cases there are no attrs, the pkg is just a placeholder

##################################################
######## RULE DECL:  OCAML_IMPORT  #########
##################################################
def _ocaml_import_impl(ctx):

    """Import OCaml resources."""

    debug = True
    print("**************** IMPORT {} ****************".format(ctx.label))

    # print("ocaml_import: %s" % ctx.label)

    # make all deps direct for client of this rule
    direct_files = []

    dep_depsets = []

    providers = []

    all_deps_list = []
    paths_direct   = []
    paths_indirect = []
    ## OcamlImportMarker is a marker, always empty

    archive_files     = []
    archive_depsets   = []
    archive_component_depsets   = []
    archive_subdep_depsets   = []
    plugin_depsets    = []
    sig_depsets = []
    module_depsets   = []
    ppx_adjunct_depsets = []

    # ocaml_archivedeps_archive_files = []
    # ocaml_archivedeps_component_depsets = []
    # ocaml_archivedeps_subdep_depsets = []

    ocaml_sigs_depset_list = []
    ocaml_module_depsets = []
    ocaml_module_subdepsets = []

    for dep in ctx.attr.deps:
        # print("IDEP: {host} => {d}".format(host=ctx.label, d = dep.label))
        ################ OCamlMarker ################
        if OcamlProvider in dep:
            all_deps_list.append(dep[OcamlProvider].files)
            paths_indirect.append(dep[OcamlProvider].paths)

        # if OcamlArchiveMarker in dep:
        #     all_deps_list.append(dep[OcamlArchiveMarker].files)
            # an archive dep will be a dep of a module, subdep of an archive

            # OcamlArchiveMarker.archive is a File list (ctx.files.archive)
            # but an archive dep here is a subdep

            # ocaml_archivedeps_archive_files.append(dep[OcamlArchiveMarker].archive)
            # archive_depsets.append(dep[OcamlArchiveMarker].files)
            # archive_component_depsets.append(dep[OcamlArchiveMarker].components)
            # archive_subdep_depsets.append(dep[OcamlArchiveMarker].subdeps)

        # if OcamlModuleMarker in dep:
        #     all_deps_list.append(dep[OcamlModuleMarker].files)
            # ocaml_sigs_depset_list.append(dep[OcamlModuleMarker].sigs)
            # ocaml_module_depsets.append(dep[OcamlModuleMarker].deps)
            # ocaml_module_subdepsets.append(dep[OcamlModuleMarker].subdeps)

        # if OcamlPathsMarker in dep:
        #     paths_indirect.append(dep[OcamlPathsMarker].paths)

        ################################################################
        # if OcamlImportArchivesMarker in dep:
        #     archive_files.append(
        #         dep[OcamlImportArchivesMarker].archives
        #     )

        # if OcamlImportPluginsMarker in dep:
        #     plugin_depsets.append(
        #         dep[OcamlImportPluginsMarker].plugins
        #     )

        # if OcamlImportSignaturesMarker in dep:
        #     module_depsets.append(
        #         dep[OcamlImportSignaturesMarker].signatures
        #     )

        # if OcamlImportPpxAdjunctsMarker in dep:
        #     ppx_adjunct_depsets.append(
        #         dep[OcamlImportPpxAdjunctsMarker].ppx_adjuncts
        #     )

        # if OcamlImportPathsMarker in dep:
        #     paths_indirect.append(dep[OcamlImportPathsMarker].paths)

    ## then directs
    outputDepsets = {}
    if ctx.attr.archive:
        direct_files.extend(ctx.files.archive)
        for f in ctx.files.archive:
            if (f.path.startswith(opam_lib_prefix)):
                dir = paths.relativize(f.dirname, opam_lib_prefix)
                paths_direct.append( "+../" + dir )
            else:
                paths_direct.append( f.dirname )
        # archives_depset = depset(
        #     order = dsorder,
        #     direct     = ctx.files.archive,
        #     transitive = archive_depsets
        # )
        # outputDepsets["archives"] = archives_depset
        # p = OcamlImportArchivesMarker(archives = archives_depset)
        # providers.append(p)
    # else:
    #     # even if we have no archive attr, we need to pass on any
    #     # archives found in the deps attr:
    #     archives_depset = depset(
    #         order = dsorder,
    #         transitive = archive_depsets
    #     )
    #     outputDepsets["archives"] = archives_depset
        # p = OcamlImportArchivesMarker(archives = archives_depset)
        # providers.append(p)

    if ctx.attr.plugin:
        direct_files.extend(ctx.files.plugin)
        for f in ctx.files.plugin:
            if (f.path.startswith(opam_lib_prefix)):
                dir = paths.relativize(f.dirname, opam_lib_prefix)
                paths_direct.append( "+../" + dir )
            else:
                paths_direct.append( f.dirname )
        plugins_depset = depset(
            order = dsorder,
            direct = ctx.files.plugin,
            transitive = plugin_depsets
        )
        outputDepsets["plugins"] = plugins_depset
        # p = OcamlImportPluginsMarker(plugins = plugins_depset)
        # providers.append(p)
    else:
        plugins_depset = depset(
            order = dsorder,
            transitive = plugin_depsets
        )
        outputDepsets["plugins"] = plugins_depset
        # p = OcamlImportPluginsMarker(plugins = plugins_depset)
        # providers.append(p)

    if ctx.attr.signature:
        direct_files.extend(ctx.files.signature)
        # direct_files.extend(ctx.files.signature)
        # print("IMPORTING SIGFILES: %s" % ctx.files.signature)
        # for a in ctx.attr.signature:
        #     for d in a.files.to_list():
        #         print("IMPORTING sigattr plain: %s" % d)
        #         print("IMPORTING sigattr path: %s" % d.path)
                # print("IMPORTING sigattr basename: %s" % d.basename)
        for f in ctx.files.signature:
            if (f.path.startswith(opam_lib_prefix)):
                dir = paths.relativize(f.dirname, opam_lib_prefix)
                paths_direct.append( "+../" + dir )
            else:
                paths_direct.append( f.dirname )
        # sigs_depset = depset(
        #     order = dsorder,
        #     direct     = ctx.files.signature,
        #     # transitive = module_depsets
        # )
        # modules_depset = depset(
        #     order = dsorder,
        #     direct     = ctx.files.signature,
        #     transitive = module_depsets
        # )
        # outputDepsets["modules"] = modules_depset
        # p = OcamlImportSignaturesMarker(signatures = modules_depset)
        # providers.append(p)
    # else:
    #     sigs_depset = depset(
    #         order = dsorder,
    #         # transitive = module_depsets
    #     )
    #     modules_depset = depset(
    #         order = dsorder,
    #         transitive = module_depsets
    #     )
    #     outputDepsets["modules"] = modules_depset
        # p = OcamlImportSignaturesMarker(signatures = modules_depset)
        # providers.append(p)

    if ctx.attr.modules:
        direct_files.extend(ctx.files.modules)
    ## now ppx (adjunct) deps. no need for paths
    if ctx.attr.deps_adjunct:
        # ppx deps may contain any of the providers
        # since they are target labels, not file labels
        # so we must iterate over their providers
        ppxdeps = []
        for dep in ctx.attr.deps_adjunct:
            # if OcamlImportArchivesMarker in dep:
            #     ppxes = dep[OcamlImportArchivesMarker].archives
            #     ppxdeps.append(ppxes)
            # if OcamlImportPluginsMarker in dep:
            #     ppxes = dep[OcamlImportPluginsMarker].plugins
            #     ppxdeps.append(ppxes)
            # if OcamlImportSignaturesMarker in dep:
            #     ppxes = dep[OcamlImportSignaturesMarker].signatures
            #     ppxdeps.append(ppxes)

            if OcamlProvider in dep:
                all_deps_list.append(dep[OcamlProvider].files)
                paths_indirect.append(dep[OcamlProvider].paths)

            # if OcamlImportPathsMarker in dep:
            #     ps = dep[OcamlImportPathsMarker].paths
            #     paths_indirect.append(ps)

            # if OcamlImportPpxAdjunctsMarker in dep:
            #     ppxes = dep[OcamlImportPpxAdjunctsMarker].ppx_adjuncts
            #     ppxdeps.append(ppxes)
        ppx_adjuncts_depset  = depset(
            order = dsorder,
            transitive = ppxdeps + ppx_adjunct_depsets
        )
        # outputDepsets["ppx_adjuncts"] = ppx_adjuncts_depset
        # p = OcamlImportPpxAdjunctsMarker(ppx_adjuncts = ppx_adjuncts_depset)
        # providers.append(p)
    else:
        ppx_adjuncts_depset  = depset(
            order = dsorder,
            transitive = ppx_adjunct_depsets
        )
        outputDepsets["ppx_adjuncts"] = ppx_adjuncts_depset
        # p = OcamlImportPpxAdjunctsMarker(ppx_adjuncts = ppx_adjuncts_depset)
        # providers.append(p)

    ################################################################
    ##  PROVIDERS ##
    ################################################################
    providers.append(DefaultInfo())

    ## WARNING: adding OutputGroupInfo has no effect. --output_groups
    ## never prints anything.

    # outputGroupInfo = OutputGroupInfo(
    #     archives = outputDepsets.get("archives") if outputDepsets.get("archives") else depset(),
    #     plugins = outputDepsets.get("plugins") if outputDepsets.get("plugins") else depset(),
    #     modules = outputDepsets.get("modules") if outputDepsets.get("modules") else depset(),
    #     ppx_adjuncts = outputDepsets.get("ppx_adjuncts") if outputDepsets.get("ppx_adjuncts") else depset(),

    #     # cclibs = cclib_files_depset,
    #     all_files = depset(transitive=[
    #         outputDepsets.get("archives") if outputDepsets.get("archives") else depset(),
    #         outputDepsets.get("plugins") if outputDepsets.get("plugins") else depset(),
    #         outputDepsets.get("modules") if outputDepsets.get("modules") else depset(),
    #         outputDepsets.get("ppx_adjuncts") if outputDepsets.get("ppx_adjuncts") else depset()
    #     ])
    # )
    # providers.append(outputGroupInfo)

    providers.append(OcamlImportMarker(marker = "OcamlImportMarker"))

    _ocamlProvider = OcamlProvider(
        # files = depset(
        #     order = dsorder,
        #     direct = ctx.files.signature if ctx.files.signature else [],
        #     transitive=ocaml_sigs_depset_list
        # ),
        files = depset(
            direct = ctx.files.archive,
            transitive = [depset(
                direct = direct_files,
                transitive = all_deps_list
            )]
        ),
        paths = depset(
            direct = paths_direct,
            transitive = paths_indirect
        )
    )
    print("Sig OcamlProvider: %s" % _ocamlProvider)
    providers.append(_ocamlProvider)

    # _ocamlModuleMarker = OcamlModuleMarker(
    #     files = depset(
    #         order = dsorder,
    #         direct = ctx.files.signature if ctx.files.signature else [],
    #         transitive=ocaml_sigs_depset_list
    #     ),
    #     sigs = depset(
    #         order = dsorder,
    #         direct = ctx.files.signature if ctx.files.signature else [],
    #         transitive=ocaml_sigs_depset_list
    #     ),
    #     deps = modules_depset,
    #     subdeps = depset(order = dsorder,
    #                      transitive=ocaml_module_subdepsets),
    # )
    # providers.append(_ocamlModuleMarker)

    ## ctx.attr.archive = list of Targets; convert to list of Files
    # _ocamlArchiveMarker = OcamlArchiveMarker(
    #     files = depset(
    #         direct = ctx.files.archive,
    #         transitive = [depset(
    #             direct = archive_files,
    #             transitive = archive_depsets
    #         )]
    #     ),
    #     archive = ctx.files.archive,
    #     # component deps should be empty for imported archives
    #     components = depset(order = dsorder,
    #                         transitive = archive_component_depsets),
    #     subdeps = depset(order = dsorder,
    #                      transitive=archive_subdep_depsets)
    # )
    # providers.append(_ocamlArchiveMarker)

    # _ocamlPathsMarker = OcamlPathsMarker(
    #     paths  = depset(
    #         order = dsorder,
    #         direct = paths_direct,
    #         transitive = paths_indirect)
    # )
    # providers.append(_ocamlPathsMarker)
    # print("PATHSPATHS: %s " % _ocamlPathsMarker)

    # print("EXPORTING IMPORT PROVIDERS for %s:" % ctx.label.name)
    # for p in providers:
    #     print(" P: %s" % p)
    # print(providers)

    # ctx.actions.do_nothing(mnemonic="IMPORT ACTION",
    #                        inputs = outputDepsets.get("archives"))

    return providers

    # return [
    #     DefaultInfo(),
    #     outputGroupInfo,
    #     OcamlImportMarker()
    # ]

################################################################
################################################################
ocaml_import = rule(
    implementation = _ocaml_import_impl,
    doc = """Imports a pre-compiled OCaml binary. [User Guide](../ug/ocaml_import.md).

**NOT YET SUPPORTED**
    """,
    attrs = dict(
        srcs = attr.label_list(
            allow_files = True
        ),
        # ocaml_import can only depend on other ocaml_imports
        deps = attr.label_list(
            allow_files = True,
            providers = [[OcamlImportMarker],
                         # [OcamlArchiveMarker],
                         # [OcamlModuleMarker]
                         ],
                         # [OcamlImportArchivesMarker],
                         # [OcamlImportPluginsMarker],
                         # [OcamlImportSignaturesMarker],
                         # [OcamlImportPathsMarker],
                         # [OcamlImportPpxAdjunctsMarker]]
        ),
        deps_adjunct = attr.label_list(
            allow_files = True,
            providers = [[OcamlImportMarker],
                         # [OcamlModuleMarker],
                         # [OcamlImportMarker],
                         # [OcamlImportArchivesMarker],
                         # [OcamlImportPluginsMarker],
                         # [OcamlImportSignaturesMarker],
                         # [OcamlImportPathsMarker],
                         # [OcamlImportPpxAdjunctsMarker]]
                         ]
        ),
        modules = attr.label_list(
            allow_files = True
        ),
        signature = attr.label_list(
            allow_files = True
        ),
        archive = attr.label_list(
            default = [],
            allow_files = True
        ),
        plugin = attr.label_list(
            allow_files = True
        ),
        version = attr.string(),
        doc = attr.string(),
        _rule = attr.string( default = "ocaml_import" ),
    ),
    provides = [OcamlImportMarker],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
