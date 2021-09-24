load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "OcamlArchiveProvider",
     "PpxAdjunctsProvider",

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
    # print("**************** IMPORT {} ****************".format(ctx.label))

    # print("ocaml_import: %s" % ctx.label)

    # make all deps direct for client of this rule
    direct_files = []

    dep_depsets = []

    providers = []

    all_deps_list = []
    ## OcamlImportMarker is a marker, always empty

    archives_list         = []
    archive_deps_list     = []
    archive_inputs_list   = []
    archive_paths_list    = []
    # archive_subdep_depsets   = []
    plugin_depsets    = []
    sig_depsets = []
    module_depsets   = []
    ## direct ppx adjuncts
    ppx_adjunct_deps_list = []
    ppx_adjunct_archives_list = []
    ppx_adjunct_paths_list = []
    ## indirect ppx adjuncts
    indirect_ppx_adjunct_deps_list = []


    # ocaml_archive_deps_archive_files = []
    # ocaml_archive_deps_component_depsets = []
    # ocaml_archive_deps_subdep_depsets = []

    ocaml_sigs_depset_list = []
    ocaml_module_depsets = []
    ocaml_module_subdepsets = []

    #### INDIRECT DEPS first ####
    # ignore DefaultInfo, its just for printing, not propagation
    indirect_inputs_depsets = []
    indirect_linkargs_depsets = []
    indirect_paths_depsets = []

    for dep in ctx.attr.deps:
        # print("IDEP: {host} => {d}".format(host=ctx.label, d = dep.label))

        # DefaultInfo.files == directly generated files, for display only
        indirect_inputs_depsets.append(dep[OcamlProvider].inputs)
        indirect_linkargs_depsets.append(dep[OcamlProvider].linkargs)
        indirect_paths_depsets.append(dep[OcamlProvider].paths)

        ################ OCamlMarker ################
        if OcamlProvider in dep:
            opdep = dep[OcamlProvider]
            all_deps_list.append(opdep.files)
            # indirect_paths_list.append(opdep.paths)

            if hasattr(opdep, "archives"):
                if opdep.archives:
                    archive_deps_list.append(opdep.archives)
            if hasattr(opdep, "archive_deps"):
                if opdep.archive_deps:
                    archive_inputs_list.append(opdep.archive_deps)
            # indirect_paths_list.append(opdep.paths)

            if hasattr(opdep, "ppx_adjuncts"):
                if opdep.ppx_adjuncts:
                    indirect_ppx_adjunct_deps_list.append(opdep.ppx_adjuncts)
            if hasattr(opdep, "ppx_adjunct_paths"):
                if opdep.ppx_adjunct_paths:
                    ppx_adjunct_paths_list.append(opdep.ppx_adjunct_paths)

        if OcamlArchiveProvider in dep:
            archives_list.append(dep[DefaultInfo].files)
            archive_deps_list.append(dep[OcamlArchiveProvider].files)
            archive_paths_list.append(dep[OcamlArchiveProvider].paths)

            # OcamlArchiveProvider.archive is a File list (ctx.files.archive)
            # but an archive dep here is a subdep

    #### DIRECT DEPS: archives, plugins, sigs ####
    ## deliver direct deps in DefaultInfo, just for display
    direct_default_files = []
    direct_inputs_list = []
    direct_linkargs_list = []
    direct_paths_list   = []

    outputDepsets = {}
    direct_archive = []
    if ctx.attr.archive:  # a label_list of file targets
        # print("IMPORTARCH: %s" % ctx.attr.archive)
        direct_default_files.extend(ctx.files.archive)
        direct_inputs_list.extend(ctx.files.archive)
        direct_linkargs_list.extend(ctx.files.archive)
        for dep in ctx.files.archive:
            # for f in dep.to_list():
            direct_paths_list.append(dep.dirname)

        # direct_files.extend(ctx.files.archive)
        direct_archive.extend(ctx.files.archive)
        for f in ctx.files.archive:
            if (f.path.startswith(opam_lib_prefix)):
                dir = paths.relativize(f.dirname, opam_lib_prefix)
                direct_paths_list.append( "+../" + dir )
            else:
                direct_paths_list.append( f.dirname )

    # print("archive_deps_list %s" % archive_deps_list)
    if direct_archive or archive_deps_list:
        archives_depset = depset(
            order = dsorder,
            direct = direct_archive,
            transitive = archive_deps_list
        )
    else:
        archives_depset = False

    # print("archive_inputs_list %s" % archive_inputs_list)
    archive_inputs_depset = depset(
        order = dsorder,
        transitive = archive_inputs_list
    )

    #### DIRECT PLUGINS DEPS ####
    if ctx.attr.plugin:
        direct_default_files.extend(ctx.files.plugin)
        direct_inputs_list.extend(ctx.files.plugin)
        direct_linkargs_list.extend(ctx.files.plugin)
        for dep in ctx.files.plugin:
            direct_paths_list.append(dep.dirname)

        direct_files.extend(ctx.files.plugin)
        for f in ctx.files.plugin:
            if (f.path.startswith(opam_lib_prefix)):
                dir = paths.relativize(f.dirname, opam_lib_prefix)
                direct_paths_list.append( "+../" + dir )
            else:
                direct_paths_list.append( f.dirname )
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

    ################################
    if ctx.attr.signature:
        direct_default_files.extend(ctx.files.signature)
        direct_inputs_list.extend(ctx.files.signature)
        direct_linkargs_list.extend(ctx.files.signature)
        for dep in ctx.files.plugin:
            direct_paths_list.append(dep.dirname)

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
                direct_paths_list.append( "+../" + dir )
            else:
                direct_paths_list.append( f.dirname )

    ################################
    if ctx.attr.modules:
        direct_files.extend(ctx.files.modules)

    ################################
    for dep in ctx.attr.deps_adjunct:
        # print("FOUND PPX ADJUNCT")
        # Recall ocaml_import gens nothing, but puts principal deps in
        # DefaultInfo.files

        if OcamlProvider in dep:
            opdep = dep[OcamlProvider]
            # print("OPDEP: %s" % opdep)
            ppx_adjunct_deps_list.append(opdep.archives)
            # instead look in archives
            ppx_adjunct_archives_list.append(opdep.files)
            # ppx_adjunct_archives_list.append(opdep.archives)
            if hasattr(opdep, "ppx_adjuncts"):
                if opdep.ppx_adjuncts:
                    # print("OPDEP.ppx_adjuncts: %s" % opdep.ppx_adjuncts)
                    ppx_adjunct_deps_list.append(opdep.ppx_adjuncts)
            if hasattr(opdep, "ppx_adjunct_paths"):
                if opdep.ppx_adjunct_paths:
                    ppx_adjunct_paths_list.append(dep[OcamlProvider].ppx_adjunct_paths)

    # print("ppx_adjunct_deps_list: %s" % ppx_adjunct_deps_list)
    # print("indirect_ppx_adjunct_deps_list: %s" % indirect_ppx_adjunct_deps_list)
    ppx_adjuncts_depset  = depset(
        order = dsorder,
        # direct = ppx_adjunct_deps_list,
        transitive = ppx_adjunct_deps_list + indirect_ppx_adjunct_deps_list
    )
    # print("PPX_ADJUNCTS_DEPSET: %s" % ppx_adjuncts_depset)

        # outputDepsets["ppx_adjuncts"] = ppx_adjuncts_depset
        # p = OcamlImportPpxAdjunctsMarker(ppx_adjuncts = ppx_adjuncts_depset)
        # providers.append(p)

    outputDepsets["ppx_adjuncts"] = ppx_adjuncts_depset
    # p = OcamlImportPpxAdjunctsMarker(ppx_adjuncts = ppx_adjuncts_depset)
        # providers.append(p)

    ################################################################
    ##  PROVIDERS ##
    ################################################################
    direct_default_depset = depset(
        direct = direct_default_files
    )
    # print(" direct_default_depset: %s" % direct_default_depset)
    defaultInfo = DefaultInfo(
        files = direct_default_depset,
    )
    providers.append(defaultInfo)

    providers.append(OcamlImportMarker(marker = "OcamlImportMarker"))

    if archives_depset:
        _archives = archives_depset
    else:
        _archives = []

    if archive_inputs_list:
        _archive_deps = archive_inputs_depset
    else:
        _archive_deps = []

    if ppx_adjuncts_depset:
        ppxAdjunctsProvider = PpxAdjunctsProvider(
            paths = depset(ppx_adjunct_paths_list),
            ppx_adjuncts = ppx_adjuncts_depset,
        )
        providers.append(ppxAdjunctsProvider)
        _ppx_adjuncts = ppx_adjuncts_depset
    else:
        _ppx_adjuncts = depset()

    ocamlProvider_files_depset = depset(
        direct = direct_files,
        transitive = all_deps_list
    )
    ################
    new_inputs_depset = depset(
        direct = direct_inputs_list,
        transitive = indirect_inputs_depsets
    )
    linkargs_depset = depset(
        direct = direct_linkargs_list,
        transitive = indirect_linkargs_depsets
    )
    paths_depset = depset(
        direct = direct_paths_list,
        transitive = indirect_paths_depsets
    )
    ################
    _ocamlProvider = OcamlProvider(
        inputs   = new_inputs_depset,
        linkargs = linkargs_depset,
        paths    = paths_depset,

        files = ocamlProvider_files_depset,
        archives = _archives,
        archive_deps = _archive_deps,
        ppx_adjuncts = _ppx_adjuncts,
        # paths = depset(
        #     direct = direct_paths_list,
        #     transitive = indirect_paths_list
        # )
    )
    providers.append(_ocamlProvider)


    ## WARNING: --output_groups produces no output, since we have no
    ## "generated" files to provide; everything imported is a "source
    ## file". So we might as well dispense with this?
    outputGroupInfo = OutputGroupInfo(
        archives = archives_depset if archives_depset else depset(),
        archive_deps = archive_inputs_depset if archive_inputs_depset else depset(),
        ppx_adjuncts = _ppx_adjuncts,
        # cc = action_inputs_ccdep_filelist,
        # inputs = inputs_depset,
        all = depset(
            order = dsorder,
            transitive=[
                # default_depset,
                ocamlProvider_files_depset,
                archives_depset if archives_depset else depset(),
                archive_inputs_depset if archive_inputs_depset else depset(),
                ppx_adjuncts_depset,
                # cclib_files_depset,
                # depset(ccDepsProvider.ccdeps_map.keys()),
                # depset(action_inputs_ccdep_filelist)
            ]
        )
    )

    providers.append(outputGroupInfo)

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
                         # [OcamlArchiveProvider],
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
