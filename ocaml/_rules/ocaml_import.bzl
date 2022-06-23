load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "OcamlImportMarker")

load("//ppx:providers.bzl",
     "PpxCodepsProvider",
     "PpxExecutableMarker",
)

load(":impl_common.bzl", "dsorder", "opam_lib_prefix")

################################################################
def _handle_deps_new(ctx, tc):
    print("_handle_deps_new, mode: %s" % tc.emitting)

    sig_list     = [] # .cmi
    struct_list  = [] # .cma or .cmx, .o
    archive_list = [] # .cma or .cmxa, .a
    xmo_list     = [] # cmxa files usually accompanied by cmx files
    cmt_list     = [] # .cmt and .cmti

    sig_list.extend(ctx.files.cmi)

    if tc.emitting == "native":
        struct_list.extend(ctx.files.cmx)   # includes .o
        archive_list.extend(ctx.files.cmxa) # includes .a
    else:
        struct_list.extend(ctx.files.cmo)
        archive_list.extend(ctx.files.cma)

    cmt_list.extend(ctx.files.cmti)
    cmt_list.extend(ctx.files.cmt)

    return (sig_list, struct_list, archive_list, xmo_list, cmt_list)

## cases: any of the attrs (corresponding to META "variables") may
## occur alone. in particular 'deps', e.g. pkg camlzip. in some cases
## there are no attrs, the pkg is just a placeholder

##################################################
######## RULE DECL:  OCAML_IMPORT  #########
##################################################
def _ocaml_import_impl(ctx):

    """Import OCaml resources."""

    debug = True
    if debug: print("import rule: %s" % ctx.label)

    tc = ctx.toolchains["@rules_ocaml//toolchain:type"]

    if tc.emitting == "native":
        struct_extensions = ["cmxa", "cmx"]
    else:
        struct_extensions = ["cma", "cmo"]

    (sig_list,
     struct_list,
     archive_list,
     xmo_list,
     cmt_list) = _handle_deps_new(ctx, tc)

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


    #### INDIRECT DEPS first, from ctx.attr.deps ####
    allglob_list = [] # files from ctx.attr.all
    indirect_ldeps_depsets = [] # depsets from ctx.attr.deps
    indirect_linkargs_depsets = []
    indirect_paths_depsets = []

    # direct file deps of this target
    sigs_direct             = []
    structs_direct          = []
    archives_direct         = []
    xmos_direct             = []

    # depsets from 'deps' attribute:
    sigs_indirect           = []
    structs_indirect        = []
    archives_indirect       = []
    xmos_indirect           = []

    ## for ppx_codeps. these must be carried separately until
    ## they are used (injected) by a ppx_executable.
    codep_sigs_direct       = []
    codep_structs_direct    = []
    codep_archives_direct   = []
    codep_xmos_direct       = []

    codep_sigs_indirect     = []
    codep_structs_indirect  = []
    codep_archives_indirect = []
    codep_xmos_indirect     = []

    for dep in ctx.attr.deps:
        if OcamlProvider in dep:
            odep = dep[OcamlProvider]
            sigs_indirect.append(odep.sigs)
            structs_indirect.append(odep.structs)
            archives_indirect.append(odep.archives)
            xmos_indirect.append(odep.xmos)

            ## legacy:

            # print("import dep: %s" % odep)
            # indirect_ldeps_depsets.append(odep.ldeps)
            indirect_linkargs_depsets.append(odep.linkargs)
            indirect_linkargs_depsets.append(dep[DefaultInfo].files)
            indirect_paths_depsets.append(odep.paths)

        ## a direct dep could be sth that depends on a ppx_codep

        if PpxCodepsProvider in dep:
            codep = dep[PpxCodepsProvider]

            codep_sigs_indirect.append(codep.sigs)
            codep_structs_indirect.append(codep.structs)
            codep_archives_indirect.append(codep.archives)
            codep_xmos_indirect.append(codep.xmos)

            if hasattr(codep, "ppx_codeps"):
                if codep.ppx_codeps:
                    has_ppx_codeps = True
                    indirect_ppx_codep_depsets.append(codep.ppx_codeps)
            if hasattr(codep, "paths"):
                if codep.paths:
                    indirect_ppx_codep_path_depsets.append(codep.paths)

    direct_paths_list   = []

    if ctx.attr.all:
        allglob_list.extend(ctx.files.all)
        for f in ctx.files.all:
            direct_paths_list.append( f.dirname )

    #### DIRECT DEPS: archives, plugins, sigs ####
    direct_default_files = []
    direct_ldeps_list = []
    direct_linkargs_list = []
    direct_archive = []

    # if ctx.attr.archive:  # a label_list of file targets
    #     direct_ldeps_list.extend(ctx.files.archive)
    #     direct_linkargs_list.extend(ctx.files.archive)
    #     for dep in ctx.files.archive:
    #         direct_paths_list.append(dep.dirname)

    #     direct_archive.extend(ctx.files.archive)
    #     for f in ctx.files.archive:
    #         # if mode == "native":
    #         #     if f.extension == "cmxa":
    #         #         direct_default_files.append(f)
    #         # if mode == "bytecode":
    #         #     if f.extension == "cma":
    #         #         direct_default_files.append(f)
    #         if f.extension in struct_extensions:
    #             direct_default_files.append(f)

    #         # if (f.path.startswith(opam_lib_prefix)):
    #         #     dir = paths.relativize(f.dirname, opam_lib_prefix)
    #         #     direct_paths_list.append( "+../" + dir )
    #         # else:
    #         direct_paths_list.append( f.dirname )

    # #### DIRECT PLUGINS DEPS ####
    # if ctx.attr.plugin:
    #     direct_default_files.extend(ctx.files.plugin)
    #     direct_ldeps_list.extend(ctx.files.plugin)
    #     direct_linkargs_list.extend(ctx.files.plugin)
    #     for dep in ctx.files.plugin:
    #         direct_paths_list.append(dep.dirname)

    #     # direct_files.extend(ctx.files.plugin)
    #     for f in ctx.files.plugin:
    #         if (f.path.startswith(opam_lib_prefix)):
    #             dir = paths.relativize(f.dirname, opam_lib_prefix)
    #             direct_paths_list.append( "+../" + dir )
    #         else:
    #             direct_paths_list.append( f.dirname )
    #     plugins_depset = depset(
    #         order = dsorder,
    #         direct = ctx.files.plugin,
    #     )
    #     # outputGroupDepsets["plugins"] = plugins_depset
    # else:
    #     plugins_depset = depset(
    #         order = dsorder,
    #     )
    #     # outputGroupDepsets["plugins"] = plugins_depset

    # ################################
    # if ctx.attr.signature:
    #     direct_default_files.extend(ctx.files.signature)
    #     direct_ldeps_list.extend(ctx.files.signature)
    #     direct_linkargs_list.extend(ctx.files.signature)
    #     for dep in ctx.files.plugin:
    #         direct_paths_list.append(dep.dirname)

    #     # direct_files.extend(ctx.files.signature)
    #     for f in ctx.files.signature:
    #         if (f.path.startswith(opam_lib_prefix)):
    #             dir = paths.relativize(f.dirname, opam_lib_prefix)
    #             direct_paths_list.append( "+../" + dir )
    #         else:
    #             direct_paths_list.append( f.dirname )

    ################################
    # if ctx.attr.modules:
    #     direct_files.extend(ctx.files.modules)

    ################################
    if ctx.attr.ppx:  ## ppx executable - should not happen for imports?
        direct_default_files.append(ctx.file.ppx)

    ################################
    # only ppx modules and execs can have ppx_codeps, which will be
    # injected when the ppx xform runs.

    ## direct ppx_codeps on imports will be labels, so depsets not files
    for dep in ctx.attr.ppx_codeps:
        has_ppx_codeps = True

        # An "ordinary" module, as a direct ppx_codep, delivers
        # just OcamlProvider.
        # Any ppx module may depend on a module that carries ppx_codeps.
        # PPX modules that inject a dependency will provide a
        # PpxCodepsProvider.
        if PpxCodepsProvider in dep:
            # print("{t}: PpxCodepsProvider in ppx_codep: {d}".format(
            #     t = ctx.label.name, d = dep))
            codep = dep[PpxCodepsProvider]
            codep_sigs_direct.extend(codep.sigs)
            codep_structs_direct.extend(codep.structs)
            codep_archives_direct.extend(codep.archives)
            codep_xmos_direct.extend(codep.xmos)

            if hasattr(codep, "ppx_codeps"):
                has_ppx_codeps = True
                if codep.ppx_codeps:
                    direct_ppx_codep_depsets.append(codep.ppx_codeps)
            if hasattr(codep, "paths"):
                if codep.paths:
                    direct_ppx_codep_path_depsets.append(codep.paths)

        ## but a ppx_codep maybe also be a "normal" module:
        if OcamlProvider in dep:
            codep = dep[OcamlProvider]

            codep_sigs_direct.extend(codep.sigs)
            codep_structs_direct.extend(codep.structs)
            codep_archives_direct.extend(codep.archives)
            codep_xmos_direct.extend(codep.xmos)


            # print("{t}: OcamlProvider in ppx_codep: {d}".format(
            #     t = ctx.label.name, d = dep))
            direct_ppx_codep_ldeps_list.append(codep.ldeps)
            direct_ppx_codep_linkargs_list.append(codep.linkargs)
            direct_ppx_codep_paths_list.append(codep.paths)
            # if hasattr(opdep, "ppx_codeps"):
            #     if opdep.ppx_codeps:
            #         ppx_codep_deps_list.append(opdep.ppx_codeps)
            # if hasattr(opdep, "paths"):
            #     if opdep.ppx_codep_paths:
            #         ppx_codep_paths_list.append(opdep.paths)

    ################################################################
    ##  PROVIDERS ##
    ################################################################
    ## we don't produce anything by action, so empty:
    # direct_default_depset = depset()
    #     direct = direct_default_files
    # )

    # if ctx.attr.ppx:
    #     defaultInfo = DefaultInfo(
    #         executable = ctx.file.ppx
    #     )
    # else:
    #     defaultInfo = DefaultInfo(
    #         files = direct_default_depset,
    #     )
    providers.append(DefaultInfo())

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
        ppxCodepsProvider = PpxCodepsProvider(
            paths      = ppx_codep_paths_depset,
            ppx_codeps = ppx_codeps_depset,
            sigs       = depset(order=dsorder,
                                direct = codep_sigs_direct,
                                transitive = codep_sigs_indirect),
            structs    = depset(order=dsorder,
                                direct = codep_structs_direct,
                                transitive = codep_structs_indirect),
            archives   = depset(order=dsorder,
                                direct = codep_archives_direct,
                                transitive = codep_archives_indirect),
            xmos       = depset(order=dsorder,
                                   direct = codep_xmos_direct,
                                   transitive = codep_xmos_indirect)
        )
        providers.append(ppxCodepsProvider)

        # if ctx.label.name == "ppx_sexp_conv":
        # outputGroupDepsets["ppx_codeps"] = ppx_codeps_depset

    ################
    # new_ldeps_depset = depset(
    #     direct = direct_ldeps_list,
    #     transitive = indirect_ldeps_depsets + [depset(allglob_list)]
    # )

    # ctx.actions.do_nothing(
    #     mnemonic = "ocaml_import",
    #     inputs =new_ldeps_depset
    # )

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
        sigs    = depset(order="postorder",
                         direct=sig_list, transitive=sigs_indirect),
        structs = depset(order="postorder",
                         direct=struct_list, transitive=structs_indirect),
        archives = depset(order="postorder",
                         direct=archive_list, transitive=archives_indirect),
        xmos = depset(order="postorder",
                         direct=xmo_list, transitive=xmos_indirect),
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

    ## --output_groups only prints generated stuff, so there's no
    ## --point in providing OutputGroupInfo for ocaml_import

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
        # _mode       = attr.label(
        #     default = "@rules_ocaml//build/mode",
        # ),
        archive = attr.label_list(allow_files = True),
        cmi  = attr.label_list(allow_files = True),
        cmti = attr.label_list(allow_files = True),
        cmt  = attr.label_list(allow_files = True),
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
