load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlProvider",

     "PpxAdjunctsProvider",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "OcamlArchiveProvider",
     "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker",
     "OcamlNsResolverProvider",
     # "OcamlPathsMarker",
     "OcamlSDK",
     "OcamlSignatureProvider",

     "PpxArchiveMarker",
     "PpxModuleMarker")

load("//ocaml/_rules/utils:rename.bzl",
     "get_module_name",
     "rename_srcfile")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_transitions:transitions.bzl", "ocaml_signature_deps_out_transition")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_sdkpath",
)
load("//ocaml/_functions:module_naming.bzl", "normalize_module_label")

load(":options.bzl",
     "options",
     "options_ns_opts",
     "options_ppx")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_ccdeps.bzl", "handle_ccdeps", "link_ccdeps", "dump_ccdep")

load(":impl_common.bzl",
     "dsorder",
     "opam_lib_prefix",
     "tmpdir")

scope = tmpdir

########## RULE:  OCAML_SIGNATURE  ################
def _ocaml_signature_impl(ctx):

    debug = False
    # if ctx.label.name in ["_Impl.cmi"]:
    #     debug = True

    print("+SIGNATURE ================ {}".format(ctx.label))

    if debug:
        print("")
        if ctx.attr._rule == "ocaml_signature":
            print("Start: OCAMLSIG %s" % ctx.label)
        else:
            fail("Unexpected rule for 'ocaml_signature_impl': %s" % ctx.attr._rule)

        print("  ns_prefixes: %s" % ctx.attr._ns_prefixes[BuildSettingInfo].value)
        print("  ns_submodules: %s" % ctx.attr._ns_submodules[BuildSettingInfo].value)

    ns_prefixes     = ctx.attr._ns_prefixes[BuildSettingInfo].value
    ns_submodules = ctx.attr._ns_submodules[BuildSettingInfo].value
    print("  _NS_PREFIXES: %s" % ns_prefixes)
    print("  _NS_SUBMODULES: %s" % ns_submodules)
    print("  _NS_RESOLVER: %s" % ctx.attr._ns_resolver)

    env = {"PATH": get_sdkpath(ctx)}

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    if mode == "native":
        exe = tc.ocamlopt.basename
    else:
        exe = tc.ocamlc.basename

    ################
    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    indirect_cc_deps  = {}

    ################
    includes   = []

    print("SIG SRC: %s" % ctx.file.src)
    # get_module_name handles ns prefix:
    (from_name, module_name) = get_module_name(ctx, ctx.file.src)
    print("SIG MNAME: {src} => {dst}".format(src=from_name, dst=module_name))

    if ctx.attr.ppx:
        mlifile = impl_ppx_transform("ocaml_signature", ctx,
                                     ctx.file.src,
                                     module_name + ".mli")
    # elif module_name != from_name:
    #     sigfile = rename_srcfile(ctx, ctx.file.src, module_name + ".mli")
    else:
        # print("NO PPX %s" % ctx.file.src)
        tmp = capitalize_initial_char(ctx.file.src.basename)
        if (tmp != module_name + ".mli"):
            # print("RENAMING {src} to {dst}".format(
            #     src=tmp, dst=module_name
            # ))
            mlifile = rename_srcfile(ctx, ctx.file.src, module_name + ".mli")
        else:
            # print("NOT RENAMING")
            mlifile = ctx.file.src
    # mlifile = ctx.file.src
    # normalize_module_name(sigMarker.mli.basename) + ".mli")
    # print("RENAMED SIG SRC: %s" % mlifile)

    out_cmi = ctx.actions.declare_file(scope + module_name + ".cmi")
    # out_cmi = ctx.actions.declare_file(scope + mlifile.basename)

    #########################
    args = ctx.actions.args()

    _options = get_options(rule, ctx)
    args.add_all(_options)

    # if "-for-pack" in _options:
    #     for_pack = True
    #     _options.remove("-for-pack")
    # else:
    #     for_pack = False

    # if ctx.attr.pack:
    #     args.add("-for-pack", ctx.attr.pack)

    # if ctx.attr.pack:
    #     args.add("-linkpkg")


    includes.append(out_cmi.dirname)

    args.add_all(includes, before_each="-I", uniquify = True)

    paths_direct   = []
    paths_indirect = []
    all_deps_list = []
    direct_deps_list = []
    archive_deps_list = []
    archive_inputs_list = [] # not for command line!

    input_deps_list = []

    #### INDIRECT DEPS first ####
    # these direct deps are "indirect" from the perspective of the consumer
    indirect_inputs_depsets = []
    indirect_linkargs_depsets = []
    indirect_paths_depsets = []

    ccInfo_list = []

    the_deps = ctx.attr.deps # + [ctx.attr._ns_resolver]
    for dep in the_deps:

        if CcInfo in dep:
            dump_ccdep(ctx, dep)
            ## we do not need to do anything with ccdeps here,
            ## just pass them on in a provider
            ccInfo_list.append(dep[CcInfo])
            # handle_ccinfo_dep(ctx, dep, ccdeps_list,)

        # ignore DefaultInfo, its just for printing, not propagation
        # print("DDEP %s" % dep)
        indirect_inputs_depsets.append(dep[OcamlProvider].inputs)
        indirect_linkargs_depsets.append(dep[OcamlProvider].linkargs)
        indirect_paths_depsets.append(dep[OcamlProvider].paths)

        input_deps_list.append(dep[OcamlProvider].files)

        # print("SDEP: %s" % dep)
        ################ OCamlMarker ################
        if OcamlProvider in dep:
            # print("SDEP.files: %s" % dep[OcamlProvider].files)
            all_deps_list.append(dep[OcamlProvider].files)
            paths_indirect.append(dep[OcamlProvider].paths)
            if dep[OcamlProvider].archives:
                archive_deps_list.append(dep[OcamlProvider].archives)
            if dep[OcamlProvider].archive_deps:
                archive_inputs_list.append(dep[OcamlProvider].archive_deps)
            paths_indirect.append(dep[OcamlProvider].paths)

        ################ OCamlArchiveProvider ################
        ## only produced by ocaml_*_archive, _import
        if OcamlArchiveProvider in dep:
            archive_deps_list.append(dep[OcamlArchiveProvider].files)
        ## the rest should be cmx modules only
        ## BUT: if ocaml_ns_archive is direct dep it delivers cmxa in default
        direct_deps_list.append(dep[DefaultInfo].files)

    # print("SIGARCHDL: %s" % archive_deps_list)
    ################ PPX Adjunct Deps ################
    ## add adjunct_deps from ppx provider
    ## adjunct deps in the dep graph are NOT compile deps of this module.
    ## only the adjunct deps of the ppx are.
    adjunct_deps = []
    if ctx.attr.ppx:
        provider = ctx.attr.ppx[PpxAdjunctsProvider]

        for ppx_adjunct in provider.ppx_adjuncts.to_list():
            adjunct_deps.append(ppx_adjunct)
            # if OcamlImportArchivesMarker in ppx_adjunct:
            #     adjuncts = ppx_adjunct[OcamlImportArchivesMarker].archives
            #     for f in adjuncts.to_list():
            if ppx_adjunct.extension in ["cmxa", "a"]:
                if (ppx_adjunct.path.startswith(opam_lib_prefix)):
                    dir = paths.relativize(ppx_adjunct.dirname, opam_lib_prefix)
                    includes.append( "+../" + dir )
                else:
                    includes.append(ppx_adjunct.dirname)
                args.add(ppx_adjunct.path)

    paths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = indirect_paths_depsets
        # transitive = paths_indirect
    )

    args.add_all(paths_depset.to_list(), before_each="-I")

    all_deps = depset(
        order = dsorder,
        ## submods depend on resolver, so keep this order:
        # transitive = [ctx.attr._ns_resolver.files] + all_deps_list
        transitive = all_deps_list
    )
    # print("SIGALLDEPS: %s" % all_deps)

    # if archive_deps_list:
    #     archives_depset = depset(transitive = archive_deps_list)
    #     args.add("-ccopt", "-DSTART_ARCHIVE_DEPS")
    #     for d in archives_depset.to_list():
    #         if d.extension not in ["a"]:
    #             args.add(d.path)
    #     args.add("-ccopt", "-DEND_ARCHIVE_DEPS")
    # else:
    #     archives_depset = False
    archives_depset = False

    archive_inputs_depset = depset(transitive = archive_inputs_list)

    # if direct_deps_list:
    #     direct_deps = depset(transitive=direct_deps_list)
    #     # print("DIRECT_DEPS: %s" % direct_deps)
    #     args.add("-ccopt", "-DSTART_DIRECT_DEPS")
    #     for dep in direct_deps.to_list():
    #         ## DefaultInfo contains some stuff we do not want in cmd:
    #         ## cmxa (direct ocaml_ns_archive dep)
    #         ## cmi (direct ocaml_signature dep)
    #         if dep.extension not in ["cmxa", "a", "cmi", "mli"]:
    #             args.add(dep)
    #     args.add("-ccopt", "-DEND_DIRECT_DEPS")

    link_args = []
    for f in all_deps.to_list():
        if f.extension not in [
            "cmi", "mli",
            "ml", # from _ns_resolver
            # "cmxa",
            "a", "o"
        ]:
            link_args.append(f.path) # paths already in paths depset?

    # args.add_all(link_args)

    ## FIXME: do we need the resolver for sigfiles?
    for f in ctx.files._ns_resolver:
        if f.extension == "cmx":
            args.add("-I", f.dirname) ## REQUIRED, even if cmx has full path
            args.add(f.path)

    if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "resolver"):
        ## this will only be the case if this is a submodule of an nslib
        args.add("-no-alias-deps")
        args.add("-open", ctx.attr._ns_resolver[OcamlNsResolverProvider].resolver)

    args.add("-c")
    args.add("-o", out_cmi)

    #     ## cp source file to workdir (__obazl)
    #     ## this is necessary for .mli/.cmi resolution to work
    #     # sigfile = rename_srcfile(ctx, ctx.file.src, module_name + ".mli")

    args.add("-intf", mlifile)

    inputs_depset = depset(
        order = dsorder,
        direct = [mlifile] #sigfile],
        + ctx.files._ns_resolver,
        transitive = indirect_inputs_depsets

        # transitive = input_deps_list
        # transitive = [all_deps]
    )
    # print("SIG {m} INPUTS_DEPSET: {ds}".format(
    #     m=ctx.label.name, ds=inputs_depset))

    # print("OUT_CMI: %s" % out_cmi);

    ################
    ################
    ctx.actions.run(
        env = env,
        executable = exe,  ## tc.ocamlfind,
        arguments = [args],
        inputs = inputs_depset,
        outputs = [out_cmi],
        tools = [tc.ocamlopt],
        mnemonic = "CompileOcamlSignature",
        progress_message = "{mode} compiling ocaml_signature: {ws}//{pkg}:{tgt}".format(
            mode = mode,
            ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name
        )
    )
    ################
    ################
    default_depset = depset(
        order = dsorder,
            direct = [out_cmi],
    )

    defaultInfo = DefaultInfo(
        files = default_depset
    )

    sigProvider = OcamlSignatureProvider(
        mli = mlifile, # sigfile,
        cmi = out_cmi,
    )

    ## FIXME: catch incompatible key dups
    cclibs = {}
    if len(indirect_cc_deps) > 0:
        cclibs.update(indirect_cc_deps)
    ccProvider = CcDepsProvider(
        ## WARNING: cc deps must be passed as a dictionary, not a file depset!!!
        ccdeps_map = cclibs

    )
    # print("OUTPUT CCPROVIDER: %s" % ccProvider)
    new_inputs_depset = depset(
        direct = [out_cmi],
        transitive = indirect_inputs_depsets
    )
    linkargs_depset = depset(
        # cmi file does not go in linkargs
        transitive = indirect_linkargs_depsets
    )
    # paths_depset = depset(
    #     direct = direct_paths_list,
    #     transitive = indirect_paths_depsets
    # )

    ocamlProvider = OcamlProvider(
        inputs   = new_inputs_depset,
        linkargs = linkargs_depset,
        paths    = paths_depset,

        files = depset(
            order  = dsorder,
            direct = [out_cmi], # mli?
            transitive = input_deps_list
            # transitive = [all_deps]
        ),
        archives = archives_depset if archives_depset else False,
        archive_deps = archive_inputs_depset if archive_inputs_depset else False,
    )
    # print("SIG exporting OCamlProvider: %s" % ocamlProvider)
    archiveProvider = OcamlArchiveProvider(
        files = depset() ## FIXME
    )

    providers = [
        defaultInfo,
        ocamlProvider,
        sigProvider,
        ccProvider
    ]

    if ccInfo_list:
        providers.append(
            cc_common.merge_cc_infos(cc_infos = ccInfo_list)
        )

    return providers


################################################################
################################################################

################################
rule_options = options("ocaml")
rule_options.update(options_ns_opts("ocaml"))
rule_options.update(options_ppx)

#######################
ocaml_signature = rule(
    implementation = _ocaml_signature_impl,
    doc = """Generates OCaml .cmi (inteface) file. [User Guide](../ug/ocaml_signature.md). Provides `OcamlSignatureProvider`.

**CONFIGURABLE DEFAULTS** for rule `ocaml_executable`

In addition to the [OCaml configurable defaults](#configdefs) that apply to all
`ocaml_*` rules, the following apply to this rule:

| Label | Default | `opts` attrib |
| ----- | ------- | ------- |
| @ocaml//interface:linkall | True | `-linkall`, `-no-linkall`|
| @ocaml//interface:threads | False | true: `-I +threads`|
| @ocaml//interface:warnings | `@1..3@5..28@30..39@43@46..47@49..57@61..62-40`| `-w` plus option value |

**NOTE** These do not support `:enable`, `:disable` syntax.

 See [Configurable Defaults](../ug/configdefs_doc.md) for more information.
    """,
    attrs = dict(
        rule_options,
        ## RULE DEFAULTS
        _linkall     = attr.label(default = "@ocaml//signature/linkall"), # FIXME: call it alwayslink?
        _threads     = attr.label(default = "@ocaml//signature/threads"),
        _warnings  = attr.label(default = "@ocaml//signature:warnings"),
        #### end options ####

        src = attr.label(
            doc = "A single .mli source file label",
            allow_single_file = [".mli", ".cmi"]
        ),
        pack = attr.string(
            doc = "Experimental",
        ),
        deps = attr.label_list(
            doc = "List of OCaml dependencies. See [Dependencies](#deps) for details.",
            providers = [
                # [OcamlSignatureProvider],
                # [OcamlProvider],
                # [CcDepsProvider]
                [OcamlArchiveProvider],
                [OcamlImportMarker],
                [OcamlLibraryMarker],
                [OcamlModuleMarker],
                [OcamlNsMarker],
                [PpxArchiveMarker],
                [PpxModuleMarker],
            ],
            # cfg = ocaml_signature_deps_out_transition
        ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
        ################################################################
        ## do we need resolver for sigfiles?
        _ns_resolver = attr.label(
            doc = "Experimental",
            providers = [OcamlNsResolverProvider],
            default = "@ocaml//ns",
            # cfg = ocaml_signature_deps_out_transition
        ),

        _ns_submodules = attr.label( # _list(
            doc = "Experimental.  May be set by ocaml_ns_library containing this module as a submodule.",
            default = "@ocaml//ns:submodules", ## NB: ppx modules use ocaml_signature
        ),
        # _ns_strategy = attr.label(
        #     doc = "Experimental",
        #     default = "@ocaml//ns:strategy"
        # ),
        _mode       = attr.label(
            default = "@ocaml//mode",
        ),
        _rule = attr.string( default = "ocaml_signature" ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
    ),
    incompatible_use_toolchain_transition = True,
    provides = [OcamlSignatureProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
