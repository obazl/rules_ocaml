load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//build:providers.bzl",
     "OCamlArchiveProvider",
     "OCamlImportProvider",
     "OCamlLibraryProvider",
     "OCamlModuleProvider",
     "OcamlNsMarker",
     "OCamlNsResolverProvider",
     "OCamlDepsProvider",
     "OCamlSignatureProvider")

load("//build/_lib:module_naming.bzl",
     "derive_module_name_from_file_name",
     "normalize_module_name")
load("//build/_lib:apis.bzl", "options", "options_ppx")
load("//build/_lib:options.bzl", "get_sig_options")
load("//build/_lib:utils.bzl", "dsorder", "tmpdir")

load("//build/_transitions:in_transitions.bzl",
     "module_in_transition",
     # "toolchain_in_transition"
     )

load("@rules_ocaml//lib:merge.bzl",
     "merge_deps",
     "aggregate_codeps",
     "DepsAggregator",
     "COMPILE", "LINK", "COMPILE_LINK")

load("//build:actions.bzl", "ppx_transformation")

workdir = tmpdir

########################################
def _resolve_modname(ctx, nsr_provider):
    debug = False
    if ctx.attr.module_name:
        ## Force module name
        if debug: print("Setting module name to %s" % ctx.attr.module_name)
        basename = ctx.attr.module_name
        if ctx.attr._normalize_modname[BuildSettingInfo].value == True:
            modname = basename[:1].capitalize() + basename[1:]
        else:
            modname = basename
        #FIXME: add ns prefix if needed
    else:
        ## Derive module name from src file name
        (mname, extension) = paths.split_extension(
            ctx.file.src.basename)
        (from_name,
         modname) = derive_module_name_from_file_name(
             ctx, mname, nsr_provider
         )

    return modname

########################################
def _resolve_fname(ctx, nsr_provider):
    debug = False
    if ctx.attr.module_name:
        ## Force module name
        if debug: print("Setting module name to %s" % ctx.attr.module_name)
        basename = ctx.attr.module_name
        if ctx.attr._normalize_modname[BuildSettingInfo].value == True:
            modname = basename[:1].capitalize() + basename[1:]
        else:
            modname = basename
        #FIXME: add ns prefix if needed
        (mname, extension) = paths.split_extension(
            basename)
            # ctx.file.src.basename)
        prefix = ""
    else:
        if ctx.attr.ns         :
            if debug: print("BOTTOMUP ns")
            bottomup = True
            ns_resolver = ctx.attr.ns
            if hasattr(ns_resolver[OCamlNsResolverProvider],
                       "fs_prefix"):
                prefix = ns_resolver[OCamlNsResolverProvider].fs_prefix
            else:
                (prefix, extension) = paths.split_extension(
                    ctx.file.ns.basename)
            ## Derive module name from src file name
            (mname, extension) = paths.split_extension(
                ctx.file.src.basename)
            (from_name,
             modname) = derive_module_name_from_file_name(
                 ctx, mname, nsr_provider
             )
        elif nsr_provider.fs_prefix == None:
            prefix = ""
            (mname, extension) = paths.split_extension(
                ctx.file.src.basename)
        else:
            if debug: print("TOPDOWN ns")
            # (mname, extension) = paths.split_extension(
            #     ctx.file.src.basename)
            # (from_name,
            #  mname) = derive_module_name_from_file_name(
            #      ctx, mname, nsr_provider
            #  )
            prefix = nsr_provider.fs_prefix

            ## Derive module name from src file name
            (mname, extension) = paths.split_extension(
                ctx.file.src.basename)
            (from_name,
             modname) = derive_module_name_from_file_name(
                 ctx, mname, nsr_provider
             )
    fname = prefix + mname[:1].capitalize() + mname[1:]
    # fail(fname)
    return fname

##########################
##  _handle_ns_stuff(ctx)
##  case a) no ns - return immediately
##  case b) bottomup ns
##  case c) topdown ns
##  in both cases renaming is called for:
##    get the ns name from the dependency
def _handle_ns_stuff(ctx):

    debug_ns = False

    if not hasattr(ctx.attr, "ns"):
        ## this is a plain ocaml_module w/o namespacing
        return  (False, # ns_enabled
                 None,  # nsr_provider = NsResolverProvider
                 None)  # ns_resolver module

    ns_enabled = False
    nsr_provider = None  ## NsResolverProvider
    nsr_target = None  ## resolver module

    ## bottom-up namespacing
    if ctx.attr.ns:
        ns_enabled = True
        nsr_target = ctx.attr.ns
        nsr_provider = ctx.attr.ns[OCamlNsResolverProvider]
        if hasattr(nsr_provider, "modname"):
            # e.g. Foo__, not Foo (ns name)
            ns_enabled = True

    ## top-down namespacing
    elif ctx.attr._ns_resolver:
        nsr_provider = ctx.attr._ns_resolver[OCamlNsResolverProvider]
        if debug_ns:
            print("_ns_resolver: %s" % ctx.attr._ns_resolver)
            print("nsr_provider: %s" % nsr_provider)
        if not nsr_provider.tag == "NULL":
            ns_enabled = True
            nsr_target = ctx.attr._ns_resolver ## [0] # index by int?
    else:
        if debug_ns: print("m: no resolver for %s" % ctx.label)
        nsr_target = None
        # ns_resolver_files = []

    return  (ns_enabled,
             nsr_provider,
             nsr_target)

########## RULE:  OCAML_SIGNATURE  ################
def _ocaml_signature_impl(ctx):

    debug      = False
    debug_deps = False
    debug_ns   = False
    debug_ppx  = False
    debug_sig  = False
    debug_tc   = False
    debug_xmo  = False

    if debug:
        print("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$")
        print("SIG %s" % ctx.label)

    # 1. handle namespacing
    # 2. handle ppx
    # 3. merge deps
    # 4. construct inputs
    # 5. construct cmd line
    # 6. execute compile action
    # 7. construct providers

    tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]
    tc_profile = ctx.toolchains["@rules_ocaml//toolchain/type:profile"]

    # if debug_tc:
    #     print("BUILD TGT: %s" % ctx.label)
    #     print("  TC.NAME: %s" % tc.name)
    #     print("  TC.HOST: %s" % tc.host)
    #     print("  TC.TARGET: %s" % tc.target)
    #     print("  TC.COMPILER: %s" % tc.compiler.basename)

    ns_enabled = False
    (ns_enabled,
     nsr_provider, nsr_target) = _handle_ns_stuff(ctx)

    manifest = [] # ??

    ##########################
    depsets = DepsAggregator()

    for dep in ctx.attr.deps:
        depsets = merge_deps(ctx, dep, depsets, manifest)

    for dep in ctx.attr.open: # opened modules are deps
        depsets = merge_deps(ctx, dep, depsets, manifest)

    if ns_enabled:
        depsets = merge_deps(ctx, nsr_target, depsets, manifest)

    if ctx.attr.ppx:
        depsets = merge_deps(ctx, ctx.attr.ppx, depsets, manifest)

    ################################################
    ## _resolve_modname
    modname = _resolve_modname(ctx, nsr_provider)
    fname = _resolve_fname(ctx, nsr_provider)
    # fail(fname)

    if ctx.attr.ppx:
        if debug_ppx: print("ppxing sig")
        ## work_mli output is generated output of ppx processing
        ppx_src_mli, work_mli = ppx_transformation("ocaml_signature", ctx,
                                      ctx.file.src, ## sig_src,
                                      modname + ".mli")
    else:
        ## for now, symlink everything to workdir
        ## later we can optimize, avoiding symlinks if src in pkg dir
        ## and no renaming
        if debug: print("no ppx")
        # work_mli = ctx.actions.declare_file(
        #     workdir + fname + ".mli")
        # ctx.actions.symlink(output = work_mli,
        #                     target_file = ctx.file.src)
        work_mli = ctx.file.src

    ################################
    args = ctx.actions.args()
    action_outputs = []

    _options = get_sig_options(rule, ctx)

    if "-opaque" in _options:
        xmo = False
    else:
        xmo = True

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

    out_cmi = ctx.actions.declare_file(workdir + fname + ".cmi")
    action_outputs.append(out_cmi)
    if debug: print("out_cmi %s" % out_cmi)

    if "-bin-annot" in _options:
        f = modname + ".cmti"
        out_cmti = ctx.actions.declare_file(f, sibling = out_cmi)
        action_outputs.append(out_cmti)
    else:
        out_cmti = None

    paths_depset = depset(
        order=dsorder,
        direct = [out_cmi.dirname],
        transitive = depsets.deps.paths
    )

    codep_paths_depset = depset(
        order = dsorder,
        transitive = depsets.codeps.paths
    )
    args.add_all(codep_paths_depset.to_list(), before_each="-I")

    args.add_all(paths_depset.to_list(), before_each="-I")

    if ns_enabled:
        args.add("-no-alias-deps")
        args.add("-open", nsr_provider.modname)

    if ctx.attr.open:
        for dep in ctx.files.open:
            args.add("-open", normalize_module_name(dep.basename))

    args.add("-c")
    args.add("-o", out_cmi)

    args.add("-intf", work_mli)

    action_inputs_depset = depset(
        order = dsorder,
        direct = [work_mli],
        transitive = depsets.deps.sigs
        + depsets.codeps.sigs
        + depsets.codeps.cli_link_deps
        + depsets.codeps.link_archives_deps
        + depsets.codeps.structs
        + depsets.codeps.ofiles
        + depsets.codeps.astructs
        + depsets.codeps.archives ## FIXME: redundant (cli_link_deps)
        + depsets.codeps.afiles
    )

    ################
    ctx.actions.run(
        executable = tc.sigcompiler,
        arguments = [args],
        inputs = action_inputs_depset,
        outputs = action_outputs,
        tools = [tc.sigcompiler],
        mnemonic = "CompileOcamlSignature",
        progress_message = "{mode} compiling ocaml_signature: {ws}//{pkg}:{tgt}".format(
            mode = tc.host + ">" + tc.target,
            ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name
        )
    )

    ################
    default_depset = depset(
        order = dsorder,
        direct = [out_cmi]
    )

    if len(depsets.deps.cmtis) == 0:
        if out_cmti:
            cmti_depset = depset(
                order = dsorder,
                direct = [out_cmti])
        else:
            cmti_depset = []
    else:
        cmti_depset = depset(
            order = dsorder,
            direct = [out_cmti] if out_cmti else [],
            transitive = depsets.deps.cmtis)

    defaultInfo = DefaultInfo(
        files = default_depset
    )

    sigs_depset = depset(
        order = dsorder,
        direct = [out_cmi],
        transitive = depsets.deps.sigs
    )
    structs_depset = depset(
        order = dsorder,
        transitive = depsets.deps.structs
    )
    ofiles_depset   = depset(
        order=dsorder,
        transitive=depsets.deps.ofiles
    )
    archives_depset = depset(
        order = dsorder,
        transitive = depsets.deps.archives
    )
    afiles_depset   = depset(
        order = dsorder,
        transitive = depsets.deps.afiles
    )
    astructs_depset = depset(
        order=dsorder,
        transitive = depsets.deps.astructs
    )
    srcs_depset = depset(
        order=dsorder,
        direct = [ctx.file.src],
        transitive = depsets.deps.srcs
    )

    ocamlDepsProvider  = OCamlDepsProvider(
        sigs       = sigs_depset,
        #FIXME: cmtis      = cmtis_depset,
        cli_link_deps = depset(
            order = dsorder,
            transitive = depsets.deps.cli_link_deps
        ),
        link_archives_deps = depset(
            order = dsorder,
            transitive = depsets.deps.link_archives_deps
        ),
        structs    = structs_depset,
        ofiles     = ofiles_depset,
        archives   = archives_depset,
        afiles     = afiles_depset,
        astructs   = astructs_depset,
        srcs       = srcs_depset,
        cmxs       = depset(),
        cmts       = depset(),
        cmtis       = depset(),
        # cclibs   = cclibs_depset,
        paths      = paths_depset,
    )

    sigProvider = OCamlSignatureProvider(
        cmi = out_cmi,
        cmti = out_cmti if out_cmti else None,
        mli = work_mli,
        xmo = xmo,
    )

    ## FIXME:  cc deps
    # ccInfo = ...

    providers = [
        defaultInfo,
        ocamlDepsProvider,
        sigProvider,
    ]

    ## ppx codeps? signatures may contribute to construction of a
    ## ppx_executable, but they will not inject codeps, since they are
    ## just interfaces, not running code.

    ## FIXME: handle depsets.ccinfos
    # BUT: sigs never depend on ccinfos?
    # if ccInfo_list:
    #     providers.append(
    #         cc_common.merge_cc_infos(cc_infos = ccInfo_list)
    #     )

    outputGroupInfo = OutputGroupInfo(
        cmi  = default_depset,
        cmti = cmti_depset,
        cmts = cmti_depset,
        sigs = sigs_depset,
        #TODO: cmtis = cmtis_depset,
        all  = depset(order = dsorder,
                      direct = [out_cmi] + ([out_cmti] if out_cmti else []))
    )

    providers.append(outputGroupInfo)

    return providers


################################
rule_options = options("rules_ocaml")
rule_options.update(options_ppx)

#######################
ocaml_signature = rule(
    implementation = _ocaml_signature_impl,
    doc = """Generates OCaml .cmi (inteface) file. (link:../user-guide/signatures[signatures]). Provides `OCamlSignatureProvider`.

**CONFIGURABLE DEFAULTS** for rule `ocaml_signature`

In addition to the <<Configurable defaults>> that
apply to all `ocaml_*` rules, the following apply to this rule. (Note
the difference between '/' and ':' in such labels):

[.rule_attrs]
[cols="1,1,1"]
|===
| Label | Default | `opts` attrib

| @rules_ocaml//cfg/signature/linkall | True | `-linkall`, `-no-linkall`

| @rules_ocaml//cfg/signature:warnings | `@1..3@5..28@30..39@43@46..47@49..57@61..62-40`| `-w` plus option value

|===

// | @rules_ocaml//cfg/signature/threads | False | true: `-I +threads`


    """,
    attrs = dict (
        rule_options,
        ## RULE DEFAULTS
        # _linkall     = attr.label(default = "@rules_ocaml//cfg/signature/linkall"), # FIXME: call it alwayslink?
        # _threads     = attr.label(default = "@rules_ocaml//cfg/signature/threads"),
        _warnings  = attr.label(default = "@rules_ocaml//cfg/signature:warnings"),
        #### end options ####

        deps = attr.label_list(
            doc = "List of OCaml dependencies. Use this for compiling a .mli source file with deps. See [Dependencies](#deps) for details.",
            providers = [
                [OCamlSignatureProvider],
                [OCamlDepsProvider],
                [OCamlArchiveProvider],
                [OCamlImportProvider],
                [OCamlLibraryProvider],
                [OCamlModuleProvider],
                [OcamlNsMarker],
            ],
            # cfg = ocaml_signature_deps_out_transition
        ),
        src = attr.label(
            doc = "A single .mli source file label",
            allow_single_file = [".mli", ".ml"] #, ".cmi"]
        ),
        _cmt             = attr.label(
            default = "@rules_ocaml//cfg:cmt",
        ),

        pack = attr.string(
            doc = "Experimental",
        ),

        open = attr.label_list(
            doc = "List of OCaml dependencies to be passed with -open.",
            providers = [
                [OCamlSignatureProvider],
                [OCamlDepsProvider],
                [OCamlArchiveProvider],
                [OCamlImportProvider],
                [OCamlLibraryProvider],
                [OCamlModuleProvider],
                [OcamlNsMarker],
            ],
            # cfg = ocaml_signature_deps_out_transition
        ),

        # data = attr.label_list(
        #     allow_files = True
        # ),

        ns = attr.label(
            doc = "Bottom-up namespacing",
            allow_single_file = True,
            mandatory = False
        ),

        _ns_resolver = attr.label(
            doc = "Experimental",
            providers = [OCamlNsResolverProvider],
            default = "@rules_ocaml//cfg/ns:resolver",
            # default = "@rules_ocaml//cfg/ns:bootstrap",
            # default = "@rules_ocaml//cfg/bootstrap/ns:resolver",
        ),

        module_name = attr.string(
            doc = "Set module (sig) name to this string"
        ),

        _normalize_modname = attr.label(
            default = "@rules_ocaml//cfg/module:normalize"
        ),

        xmo = attr.bool(
            doc = "Cross-module optimization. If false, compile with -opaque",
            default = True
        ),

        _rule = attr.string( default = "ocaml_signature" ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
    ),
    # cfg = toolchain_in_transition, # ok for bottomup ns
    cfg = module_in_transition,
    provides = [OCamlSignatureProvider, OCamlDepsProvider],
    executable = False,
    toolchains = ["@rules_ocaml//toolchain/type:std",
                  "@rules_ocaml//toolchain/type:profile",
                  "@bazel_tools//tools/cpp:toolchain_type"]
)

