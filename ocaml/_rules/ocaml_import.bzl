load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
     "OcamlProvider",
     "OcamlImportMarker")

load("//ppx:providers.bzl",
     "PpxCodepsProvider",
     "PpxExecutableMarker",
)

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

    # tc = ctx.toolchains["@rules_ocaml//toolchain:type"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    if mode == "native":
        struct_extensions = ["cmxa", "cmx"]
    else:
        struct_extensions = ["cma", "cmo"]

    # if mode == "native":
    #     tool = tc.ocamlopt # .basename
    # else:
    #     tool = tc.ocamlc  #.basename

    # tool_args = []

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
    direct_ppx_codep_ldeps_list = []
    direct_ppx_codep_linkargs_list = []
    direct_ppx_codep_paths_list = []
    ## targets with PpxCodepsProvider:
    direct_ppx_codep_depsets      = []
    direct_ppx_codep_path_depsets = []


    #### INDIRECT DEPS first ####
    indirect_ldeps_list = [] # files from ctx.attr.all
    indirect_ldeps_depsets = [] # depsets from ctx.attr.deps
    indirect_linkargs_depsets = []
    indirect_paths_depsets = []

    for dep in ctx.attr.deps:
        # print("import dep: %s" % dep[OcamlProvider])
        indirect_ldeps_depsets.append(dep[OcamlProvider].ldeps)

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

        if PpxCodepsProvider in dep:
            codep = dep[PpxCodepsProvider]
            if hasattr(codep, "ppx_codeps"):
                if codep.ppx_codeps:
                    has_ppx_codeps = True
                    indirect_ppx_codep_depsets.append(codep.ppx_codeps)
            if hasattr(codep, "paths"):
                if codep.paths:
                    indirect_ppx_codep_path_depsets.append(codep.paths)

    direct_paths_list   = []

    if ctx.attr.all:
        indirect_ldeps_list.extend(ctx.files.all)
        for f in ctx.files.all:
            direct_paths_list.append( f.dirname )

    #### DIRECT DEPS: archives, plugins, sigs ####
    direct_default_files = []
    direct_ldeps_list = []
    direct_linkargs_list = []

    outputGroupDepsets = {}
    direct_archive = []
    if ctx.attr.archive:  # a label_list of file targets
        direct_ldeps_list.extend(ctx.files.archive)
        direct_linkargs_list.extend(ctx.files.archive)
        for dep in ctx.files.archive:
            direct_paths_list.append(dep.dirname)

        direct_archive.extend(ctx.files.archive)
        for f in ctx.files.archive:
            # if mode == "native":
            #     if f.extension == "cmxa":
            #         direct_default_files.append(f)
            # if mode == "bytecode":
            #     if f.extension == "cma":
            #         direct_default_files.append(f)
            if f.extension in struct_extensions:
                direct_default_files.append(f)

            # if (f.path.startswith(opam_lib_prefix)):
            #     dir = paths.relativize(f.dirname, opam_lib_prefix)
            #     direct_paths_list.append( "+../" + dir )
            # else:
            direct_paths_list.append( f.dirname )

    #### DIRECT PLUGINS DEPS ####
    if ctx.attr.plugin:
        direct_default_files.extend(ctx.files.plugin)
        direct_ldeps_list.extend(ctx.files.plugin)
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
        direct_ldeps_list.extend(ctx.files.signature)
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
    if ctx.attr.ppx:  ## ppx executable
        direct_default_files.append(ctx.file.ppx)

    ################################
    ## direct ppx_codeps on imports will be depsets, not files
    for dep in ctx.attr.ppx_codeps:
        has_ppx_codeps = True
        if OcamlProvider in dep:
            # print("{t}: OcamlProvider in ppx_codep: {d}".format(
            #     t = ctx.label.name, d = dep))
            opdep = dep[OcamlProvider]
            direct_ppx_codep_ldeps_list.append(opdep.ldeps)
            direct_ppx_codep_linkargs_list.append(opdep.linkargs)
            direct_ppx_codep_paths_list.append(opdep.paths)
            # if hasattr(opdep, "ppx_codeps"):
            #     if opdep.ppx_codeps:
            #         ppx_codep_deps_list.append(opdep.ppx_codeps)
            # if hasattr(opdep, "paths"):
            #     if opdep.ppx_codep_paths:
            #         ppx_codep_paths_list.append(opdep.paths)

        if PpxCodepsProvider in dep:
            # print("{t}: PpxCodepsProvider in ppx_codep: {d}".format(
            #     t = ctx.label.name, d = dep))
            codep = dep[PpxCodepsProvider]
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

    if ctx.attr.ppx:
        defaultInfo = DefaultInfo(
            executable = ctx.file.ppx
        )
    else:
        defaultInfo = DefaultInfo(
            files = direct_default_depset,
        )
    providers.append(defaultInfo)

    ################
    if has_ppx_codeps:
        ppx_codeps_depset  = depset(
            order = dsorder,
            transitive = direct_ppx_codep_ldeps_list +
            indirect_ppx_codep_depsets + direct_ppx_codep_depsets
        )

        ppx_codep_paths_depset = depset(
            transitive = direct_ppx_codep_paths_list +
            direct_ppx_codep_path_depsets + indirect_ppx_codep_path_depsets
        )
        ppxAdjunctsProvider = PpxCodepsProvider(
            paths      = ppx_codep_paths_depset,
            ppx_codeps = ppx_codeps_depset,
        )
        providers.append(ppxAdjunctsProvider)

        # if ctx.label.name == "ppx_sexp_conv":
        outputGroupDepsets["ppx_codeps"] = ppx_codeps_depset

    ################
    new_ldeps_depset = depset(
        direct = direct_ldeps_list,
        transitive = indirect_ldeps_depsets + [depset(indirect_ldeps_list)]
    )

    ctx.actions.do_nothing(
        mnemonic = "ocaml_import",
        inputs =new_ldeps_depset
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
        ldeps   = new_ldeps_depset,
        cdeps   = new_ldeps_depset,
        linkargs = linkargs_depset,
        paths    = paths_depset,

        # ppx_codeps = _ppx_codeps,
    )
    # if ctx.label.name == "ppx_sexp_conv":
    #     print("OcamlProvider.ppx_codeps from target %s" % ctx.label)
    #     print(_ocamlProvider.ppx_codeps)

    providers.append(_ocamlProvider)

    # if ctx.attr.ppx:
    #     providers.append(PpxExecutableMarker())

    providers.append(OcamlImportMarker(marker = "OcamlImport"))

    # if executable:
    #     providers.append(OcamlExecutableMarker(marker = "OcamlExecutable"))
    if ctx.attr.ppx:  ## ppx executable
        providers.append(PpxExecutableMarker(marker = "PpxExecutable"))

    ## FIXME: --output_groups only prints generated stuff? it won't
    ## print fixed files that just pass through
    # outputGroupInfo = OutputGroupInfo(
    #     # ppx_codeps = outputGroupDepsets["ppx_codeps"] if outputGroupDepsets["ppx_codeps"] else depset(),
    #     files = direct_default_depset,

    #     ldeps   = new_ldeps_depset,
    #     linkargs = linkargs_depset,

    #     # all = depset(
    #     #     order = dsorder,
    #     #     transitive=[
    #     #         ppx_codeps_depset,
    #     #     ]
    #     # )
    # )

    # providers.append(outputGroupInfo)

    # if ctx.label.name == "irmin-pack":
    #     print("IRMIN PROVIDERS")

    # print(providers)

    return providers

################################################################
ocaml_import = rule(
    implementation = _ocaml_import_impl,
    doc = """Imports pre-compiled OCaml files. [User Guide](../ug/ocaml_import.md).

    """,
    attrs = dict(
        _mode       = attr.label(
            default = "@rules_ocaml//build/mode",
        ),
        archive = attr.label_list(allow_files = True),
        cmi  = attr.label_list(allow_files = True),
        cmti = attr.label_list(allow_files = True),
        cmo  = attr.label_list(allow_files = True),
        cmx  = attr.label_list(allow_files = True),
        cmxa = attr.label_list(allow_files = True),
        cma  = attr.label_list(allow_files = True),
        cmxs = attr.label_list(allow_files = True),
        srcs = attr.label_list(allow_files = True),

        all = attr.label_list(
            doc = "Glob all cm* files except for 'archive' or 'plugin' so theey can be added to action ldeps (rather than cmd line). I.e. the (transitive) deps of an archive, which must be accessible to the compiler (via search path, not command line), and so must be added to the action ldeps.",
            allow_files = True
        ),

        modules = attr.label_list(
            allow_files = True
        ),
        signature = attr.label_list(
            allow_files = True
        ),
        ppx = attr.label(
            doc = "precompiled ppx executable",
            allow_single_file = True,
            executable = True,
            cfg        = "exec"
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
    toolchains = ["@rules_ocaml//toolchain:type"],
)
