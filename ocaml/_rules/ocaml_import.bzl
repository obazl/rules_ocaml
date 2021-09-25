load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "PpxAdjunctsProvider",
     "OcamlImportMarker")

load(":impl_common.bzl", "dsorder", "opam_lib_prefix")

## cases: any of the attrs (corresponding to META "variables") may
## occur alone. in particular 'deps', e.g. pkg camlzip. in some cases
## there are no attrs, the pkg is just a placeholder

##################################################
######## RULE DECL:  OCAML_IMPORT  #########
##################################################
def _ocaml_import_impl(ctx):

    """Import OCaml resources."""

    debug = False
    direct_files = []

    dep_depsets = []

    providers = []

    ## direct ppx adjuncts
    ppx_codep_deps_list = []
    ppx_codep_archives_list = []
    ppx_codep_paths_list = []

    ## indirect ppx adjuncts
    indirect_ppx_codep_deps_list = []

    #### INDIRECT DEPS first ####
    indirect_inputs_depsets = []
    indirect_linkargs_depsets = []
    indirect_paths_depsets = []

    for dep in ctx.attr.deps:
        indirect_inputs_depsets.append(dep[OcamlProvider].inputs)
        indirect_linkargs_depsets.append(dep[OcamlProvider].linkargs)
        indirect_paths_depsets.append(dep[OcamlProvider].paths)

        ################ OCamlMarker ################
        if OcamlProvider in dep:
            opdep = dep[OcamlProvider]
            # all_deps_list.append(opdep.files)
            if hasattr(opdep, "ppx_codeps"):
                if opdep.ppx_codeps:
                    indirect_ppx_codep_deps_list.append(opdep.ppx_codeps)
            if hasattr(opdep, "ppx_codep_paths"):
                if opdep.ppx_codep_paths:
                    ppx_codep_paths_list.append(opdep.ppx_codep_paths)

    #### DIRECT DEPS: archives, plugins, sigs ####
    direct_default_files = []
    direct_inputs_list = []
    direct_linkargs_list = []
    direct_paths_list   = []

    outputDepsets = {}
    direct_archive = []
    if ctx.attr.archive:  # a label_list of file targets
        direct_default_files.extend(ctx.files.archive)
        direct_inputs_list.extend(ctx.files.archive)
        direct_linkargs_list.extend(ctx.files.archive)
        for dep in ctx.files.archive:
            direct_paths_list.append(dep.dirname)

        direct_archive.extend(ctx.files.archive)
        for f in ctx.files.archive:
            if (f.path.startswith(opam_lib_prefix)):
                dir = paths.relativize(f.dirname, opam_lib_prefix)
                direct_paths_list.append( "+../" + dir )
            else:
                direct_paths_list.append( f.dirname )

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
        )
        outputDepsets["plugins"] = plugins_depset
    else:
        plugins_depset = depset(
            order = dsorder,
        )
        outputDepsets["plugins"] = plugins_depset

    ################################
    if ctx.attr.signature:
        direct_default_files.extend(ctx.files.signature)
        direct_inputs_list.extend(ctx.files.signature)
        direct_linkargs_list.extend(ctx.files.signature)
        for dep in ctx.files.plugin:
            direct_paths_list.append(dep.dirname)

        direct_files.extend(ctx.files.signature)
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
    for dep in ctx.attr.ppx_codeps:
        if OcamlProvider in dep:
            opdep = dep[OcamlProvider]
            ppx_codep_deps_list.append(opdep.inputs)
            ppx_codep_archives_list.append(opdep.linkargs)
            if hasattr(opdep, "ppx_codeps"):
                if opdep.ppx_codeps:
                    ppx_codep_deps_list.append(opdep.ppx_codeps)
            if hasattr(opdep, "ppx_codep_paths"):
                if opdep.ppx_codep_paths:
                    ppx_codep_paths_list.append(dep[OcamlProvider].ppx_codep_paths)

    ppx_codeps_depset  = depset(
        order = dsorder,
        transitive = ppx_codep_deps_list + indirect_ppx_codep_deps_list
    )

    outputDepsets["ppx_codeps"] = ppx_codeps_depset

    ################################################################
    ##  PROVIDERS ##
    ################################################################
    direct_default_depset = depset(
        direct = direct_default_files
    )

    defaultInfo = DefaultInfo(
        files = direct_default_depset,
    )
    providers.append(defaultInfo)

    if ppx_codeps_depset:
        ppxAdjunctsProvider = PpxAdjunctsProvider(
            paths = depset(ppx_codep_paths_list),
            ppx_codeps = ppx_codeps_depset,
        )
        providers.append(ppxAdjunctsProvider)
        _ppx_codeps = ppx_codeps_depset
    else:
        _ppx_codeps = depset()

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

        ppx_codeps = _ppx_codeps,
    )
    providers.append(_ocamlProvider)

    providers.append(OcamlImportMarker(marker = "OcamlImport"))

    outputGroupInfo = OutputGroupInfo(
        ppx_codeps = _ppx_codeps,
        all = depset(
            order = dsorder,
            transitive=[
                ppx_codeps_depset,
            ]
        )
    )

    providers.append(outputGroupInfo)

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
            providers = [OcamlImportMarker],
        ),
        ppx_codeps = attr.label_list(
            allow_files = True,
            providers = [[OcamlImportMarker]]
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
