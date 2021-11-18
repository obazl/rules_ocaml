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
    # ppx_codep_deps_list = []
    # ppx_codep_archives_list = []
    # ppx_codep_paths_list = []

    has_ppx_codeps = False
    # indirect_ppx_codep_deps_list = []
    indirect_ppx_codep_depsets      = []
    indirect_ppx_codep_path_depsets = []

    # for deps listed in ctx.attr.ppx_codeps
    ## files with OcamlProvider:
    direct_ppx_codep_inputs_list = []
    direct_ppx_codep_linkargs_list = []
    direct_ppx_codep_paths_list = []
    ## targets with PpxCodepsProvider:
    direct_ppx_codep_depsets      = []
    direct_ppx_codep_path_depsets = []


    #### INDIRECT DEPS first ####
    indirect_inputs_list = [] # files from ctx.attr.all
    indirect_inputs_depsets = [] # depsets from ctx.attr.deps
    indirect_linkargs_depsets = []
    indirect_paths_depsets = []

    for dep in ctx.attr.deps:
        # print("import dep: %s" % dep[OcamlProvider])
        indirect_inputs_depsets.append(dep[OcamlProvider].inputs)

        indirect_linkargs_depsets.append(dep[OcamlProvider].linkargs)
        indirect_linkargs_depsets.append(dep[DefaultInfo].files)

        indirect_paths_depsets.append(dep[OcamlProvider].paths)

        # if OcamlProvider in dep:  ## isn't this always true?
        #     opdep = dep[OcamlProvider]
        #     # all_deps_list.append(opdep.files)
        #     if hasattr(opdep, "ppx_codeps"):
        #         if opdep.ppx_codeps:
        #             indirect_ppx_codep_deps_list.append(opdep.ppx_codeps)
        #     if hasattr(opdep, "ppx_codep_paths"):
        #         if opdep.ppx_codep_paths:
        #             ppx_codep_paths_list.append(opdep.ppx_codep_paths)

        if PpxAdjunctsProvider in dep:
            codep = dep[PpxAdjunctsProvider]
            if hasattr(codep, "ppx_codeps"):
                if codep.ppx_codeps:
                    has_ppx_codeps = True
                    indirect_ppx_codep_depsets.append(codep.ppx_codeps)
            if hasattr(codep, "paths"):
                if codep.paths:
                    indirect_ppx_codep_path_depsets.append(codep.paths)

    direct_paths_list   = []

    if ctx.attr.all:
        indirect_inputs_list.extend(ctx.files.all)
        for f in ctx.files.all:
            direct_paths_list.append( f.dirname )

    #### DIRECT DEPS: archives, plugins, sigs ####
    direct_default_files = []
    direct_inputs_list = []
    direct_linkargs_list = []

    outputGroupDepsets = {}
    direct_archive = []
    if ctx.attr.archive:  # a label_list of file targets
        direct_inputs_list.extend(ctx.files.archive)
        direct_linkargs_list.extend(ctx.files.archive)
        for dep in ctx.files.archive:
            direct_paths_list.append(dep.dirname)

        direct_archive.extend(ctx.files.archive)
        for f in ctx.files.archive:
            if f.extension == "cmxa":
                direct_default_files.append(f)
            # if (f.path.startswith(opam_lib_prefix)):
            #     dir = paths.relativize(f.dirname, opam_lib_prefix)
            #     direct_paths_list.append( "+../" + dir )
            # else:
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
        outputGroupDepsets["plugins"] = plugins_depset
    else:
        plugins_depset = depset(
            order = dsorder,
        )
        outputGroupDepsets["plugins"] = plugins_depset

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
    ## direct ppx_codeps on imports will be depsets, not files
    for dep in ctx.attr.ppx_codeps:
        has_ppx_codeps = True
        if OcamlProvider in dep:
            # print("{t}: OcamlProvider in ppx_codep: {d}".format(
            #     t = ctx.label.name, d = dep))
            opdep = dep[OcamlProvider]
            direct_ppx_codep_inputs_list.append(opdep.inputs)
            direct_ppx_codep_linkargs_list.append(opdep.linkargs)
            direct_ppx_codep_paths_list.append(opdep.paths)
            # if hasattr(opdep, "ppx_codeps"):
            #     if opdep.ppx_codeps:
            #         ppx_codep_deps_list.append(opdep.ppx_codeps)
            # if hasattr(opdep, "paths"):
            #     if opdep.ppx_codep_paths:
            #         ppx_codep_paths_list.append(opdep.paths)

        if PpxAdjunctsProvider in dep:
            # print("{t}: PpxCodepsProvider in ppx_codep: {d}".format(
            #     t = ctx.label.name, d = dep))
            codep = dep[PpxAdjunctsProvider]
            if hasattr(codep, "ppx_codeps"):
                has_ppx_codeps = True
                if codep.ppx_codeps:
                    direct_ppx_codep_depsets.append(codep.ppx_codeps)
            if hasattr(codep, "paths"):
                if codep.paths:
                    direct_ppx_codep_path_depsets.append(codep.paths)

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

    ################
    if has_ppx_codeps:
        ppx_codeps_depset  = depset(
            order = dsorder,
            transitive = direct_ppx_codep_inputs_list +
            indirect_ppx_codep_depsets + direct_ppx_codep_depsets
        )

        ppx_codep_paths_depset = depset(
            transitive = direct_ppx_codep_paths_list +
            direct_ppx_codep_path_depsets + indirect_ppx_codep_path_depsets
        )
        ppxAdjunctsProvider = PpxAdjunctsProvider(
            paths      = ppx_codep_paths_depset,
            ppx_codeps = ppx_codeps_depset,
        )
        providers.append(ppxAdjunctsProvider)

        # if ctx.label.name == "ppx_sexp_conv":
        outputGroupDepsets["ppx_codeps"] = ppx_codeps_depset

    ################
    new_inputs_depset = depset(
        direct = direct_inputs_list,
        transitive = indirect_inputs_depsets + [depset(indirect_inputs_list)]
    )

    ctx.actions.do_nothing(
        mnemonic = "ocaml_import",
        inputs =new_inputs_depset
    )

    linkargs_depset = depset(
        direct = direct_default_files,
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

        # ppx_codeps = _ppx_codeps,
    )
    # if ctx.label.name == "ppx_sexp_conv":
    #     print("OcamlProvider.ppx_codeps from target %s" % ctx.label)
    #     print(_ocamlProvider.ppx_codeps)

    providers.append(_ocamlProvider)

    providers.append(OcamlImportMarker(marker = "OcamlImport"))

    outputGroupInfo = OutputGroupInfo(
        # ppx_codeps = outputGroupDepsets["ppx_codeps"] if outputGroupDepsets["ppx_codeps"] else depset(),
        files = direct_default_depset,

        inputs   = new_inputs_depset,
        linkargs = linkargs_depset,

        # all = depset(
        #     order = dsorder,
        #     transitive=[
        #         ppx_codeps_depset,
        #     ]
        # )
    )

    providers.append(outputGroupInfo)

    # if ctx.label.name == "irmin-pack":
    #     print("IRMIN PROVIDERS")
    #     print(providers)

    return providers

################################################################
ocaml_import = rule(
    implementation = _ocaml_import_impl,
    doc = """Imports pre-compiled OCaml files. [User Guide](../ug/ocaml_import.md).

    """,
    attrs = dict(
        archive = attr.label_list(
            default = [],
            allow_files = True
        ),
        all = attr.label_list(
            doc = "Glob all cm* files except for 'archive' or 'plugin' so theey can be added to action inputs (rather than cmd line). I.e. the (transitive) deps of an archive, which must be accessible to the compiler (via search path, not command line), and so must be added to the action inputs.",
            allow_files = True
        ),
        srcs = attr.label_list(
            allow_files = True
        ),
        modules = attr.label_list(
            allow_files = True
        ),
        signature = attr.label_list(
            allow_files = True
        ),
        plugin = attr.label_list(
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
        version = attr.string(),
        doc = attr.string(),
        _rule = attr.string( default = "ocaml_import" ),
    ),
    provides = [OcamlImportMarker],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
