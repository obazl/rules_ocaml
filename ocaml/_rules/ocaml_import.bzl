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

        # DefaultInfo.files == directly generated files, for display only

            # OcamlArchiveMarker.archive is a File list (ctx.files.archive)
            # but an archive dep here is a subdep

    #### DIRECT DEPS: archives, plugins, sigs ####
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

        # outputDepsets["ppx_adjuncts"] = ppx_adjuncts_depset
        # p = OcamlImportPpxAdjunctsMarker(ppx_adjuncts = ppx_adjuncts_depset)
        # providers.append(p)

        # providers.append(p)

    ################################################################
    ##  PROVIDERS ##
    ################################################################
    direct_default_depset = depset(

    providers.append(OcamlImportMarker(marker = "OcamlImportMarker"))

    if archives_depset:
        )
    )
    print("Sig OcamlProvider: %s" % _ocamlProvider)
    providers.append(_ocamlProvider)



    # print("EXPORTING IMPORT PROVIDERS for %s:" % ctx.label.name)
    # for p in providers:
    #     print(" P: %s" % p)

    return providers

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
