load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//build:providers.bzl",
     "MergedDepsProvider",
     "OcamlArchiveMarker",
     "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker",
     "OCamlNsResolverProvider",
     "OCamlDepsProvider",
     "OCamlSignatureProvider")

load("//build/_lib:module_naming.bzl",
     "derive_module_name_from_file_name",
     "normalize_module_name")
load("//build/_lib:options.bzl", "options", "options_ppx")
load("//build/_lib:utils.bzl",
     "dsorder", "tmpdir", "get_options")

load("//build/_transitions:in_transitions.bzl",
     "toolchain_in_transition")

load("@rules_ocaml//lib:merge.bzl",
     "merge_deps",
     "aggregate_codeps",
     "DepsAggregator",
     "COMPILE", "LINK", "COMPILE_LINK")

load("//build:actions.bzl", "ppx_transformation")

workdir = tmpdir

##########################
def _handle_ns_stuff(ctx):

    debug_ns = False

    if not hasattr(ctx.attr, "ns_resolver"):
        ## this is an ocaml_ns_resolver, not a "plain" module
        return  (False, # ns_enabled
                 None,  # ns_name
                 None,  # nsrp
                 None,  # ns_resolver
                 # []    # ns_resolver_files
                 )

    ns_enabled = False
    ns_name = None
    nsrp = None
    ns_resolver = None

    ## bottom-up namespacing
    if ctx.attr.ns_resolver:
        ns_enabled = True
        ns_resolver = ctx.attr.ns_resolver ## [0] # index by int?
        # ns_resolver_files = ctx.files.ns_resolver ## [0] # index by int?
        nsrp = ctx.attr.ns_resolver[OCamlNsResolverProvider]
        if hasattr(nsrp, "ns_name"):
            ns_name = nsrp.ns_name
            ns_enabled = True

        if hasattr(nsrp, "ns_module_name"):
            ns_module_name = nsrp.ns_module_name
            ns_enabled = True

    ## top-down namespacing
    elif ctx.attr._ns_resolver:
        nsrp = ctx.attr._ns_resolver[OCamlNsResolverProvider]
        if debug_ns:
            print("_ns_resolver: %s" % ctx.attr._ns_resolver)
            print("nsrp: %s" % nsrp)
        if not nsrp.tag == "NULL": # hasattr(nsrp, "ns_name"):
            ns_enabled = True
            # fail("XXXXXXXXXXXXXXXX")
            ns_name = nsrp.ns_name
            ns_module_name = nsrp.module_name
            ns_resolver = ctx.attr._ns_resolver ## [0] # index by int?
            # ns_resolver_files = ctx.files._ns_resolver ## [0] # index by int?

    else:
        if debug_ns: print("m: no resolver for %s" % ctx.label)
        ns_resolver = None
        # ns_resolver_files = []

    ## if we have a udr (from the 'resolver' attr of ocaml_ns*),
    ## then our _ns_resolver will be contain a null resolver,
    ## but we still need to rename our submodules.
    # print("{c} _ns_resolver nsrp:{r} {s}".format(
    #     c=CCGRN, r=CCRESET, s=ctx.attr._ns_resolver[OCamlNsResolverProvider]))
    # print("{c} _ns_prefixes:{r} {s}".format(
    #     c=CCGRN, r=CCRESET, s=ctx.attr._ns_prefixes[BuildSettingInfo].value))
    # print("{c} _ns_submodules:{r} {s}".format(
    #     c=CCGRN, r=CCRESET, s=ctx.attr._ns_submodules[BuildSettingInfo].value))

    return  (ns_enabled,
             ns_name,
             nsrp,
             ns_resolver)

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
    ns_name    = None
    ## bottom-up namespacing, demo: ns/bottomup/mwe
    # if ctx.attr.ns_resolver:
    #     ns_enabled = True
    #     ns_resolver = ctx.attr.ns_resolver
    #     # ns_resolver_files = ctx.files.ns_resolver
    #     nsrp = ctx.attr.ns_resolver[OCamlNsResolverProvider]
    #     if hasattr(nsrp, "ns_name"):
    #         ns_name = nsrp.ns_name
    #         ns_enabled = True
    #     # else:
    #     #     ???

    #     if hasattr(nsrp, "ns_module_name"):
    #         ns_module_name = nsrp.ns_module_name
    #         ns_enabled = True
    #     # else:
    #     #     ???

    # ## top-down ns, demo: ns/topdown/library/mwe/hello
    # elif ctx.attr._ns_resolver:
    #     nsrp = ctx.attr._ns_resolver[OCamlNsResolverProvider]
    #     if debug_ns:
    #         print("_ns_resolver: %s" % ctx.attr._ns_resolver)
    #         print("nsrp: %s" % nsrp)
    #     if not nsrp.tag == "NULL": # hasattr(nsrp, "ns_name"):
    #         ns_enabled = True
    #         ns_name = nsrp.ns_name
    #         ns_module_name = nsrp.module_name
    #         ns_resolver = ctx.attr._ns_resolver ## [0] # index by int?
    #         # ns_resolver_files = ctx.files._ns_resolver

    # # no namespacing
    # else:
    #     if debug_ns: print("lib: no resolver for %s" % ctx.label)
    #     ns_resolver = None
    #     # ns_resolver_files = []

    (ns_enabled, ns_name, nsrp, ns_resolver) = _handle_ns_stuff(ctx)

    manifest = [] # ??
    ## FIXME: handle non-namespaced archive manifests
    # if hasattr(nsrp, "submodules"):
    #     manifest = nsrp.submodules
    #     if debug_ns:
    #         print("ns manifest: %s" % manifest)

    depsets = DepsAggregator()

    for dep in ctx.attr.deps:
        depsets = merge_deps(ctx, dep, depsets, manifest)

    for dep in ctx.attr.open: # opened modules are deps
        depsets = merge_deps(ctx, dep, depsets, manifest)

    if ns_enabled:
        depsets = merge_deps(ctx, ns_resolver, depsets, manifest)

    ## NB: sigs never have direct codeps
    ## add ppx_codeps from ppx provider
    ## only the codeps of the ppx executable deps of this sig.
    ## ppx codeps in the dep graph are NOT compile deps of this sig.
    if ctx.attr.ppx:
        depsets = merge_deps(ctx, ctx.attr.ppx, depsets, manifest)

    ################################################
    modname = None

    if ctx.attr.module:
        if debug: print("Setting module name to %s" % ctx.attr.module)
        basename = ctx.attr.module
        modname = basename[:1].capitalize() + basename[1:]
        #FIXME: add ns prefix if needed
    else:
        (mname, extension) = paths.split_extension(
            ctx.file.src.basename)
        (from_name, modname) = derive_module_name_from_file_name(ctx, mname)

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
        work_mli = ctx.actions.declare_file(
            workdir + modname + ".mli")
        ctx.actions.symlink(output = work_mli,
                            target_file = ctx.file.src)

    ################################
    args = ctx.actions.args()
    action_outputs = []

    _options = get_options(rule, ctx)
    if "-opaque" in _options:
        xmo = False
    else:
        xmo = True
    # elif "-no-opaque" in _options:
    #     xmo = True
    # else:
    #     xmo = ctx.attr._xmo

    if "-bin-annot" in _options:
        cmti = workdir + modname + ".cmti"
        out_cmti = None
        out_cmti = ctx.actions.declare_file(cmti)
        action_outputs.append(out_cmti)
    # elif "//command_line_option:output_groups" == "cmti":
    #     same
    else:
        out_cmti = None

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

    out_cmi = ctx.actions.declare_file(workdir + modname + ".cmi")

    action_outputs.append(out_cmi)
    if debug: print("out_cmi %s" % out_cmi)

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
        args.add("-open", nsrp.module_name)

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
        + depsets.codeps.structs
        + depsets.codeps.ofiles
        + depsets.codeps.astructs
        + depsets.codeps.archives ## FIXME: redundant (cli_link_deps)
        + depsets.codeps.afiles
    )

    ################
    ctx.actions.run(
        executable = tc.compiler,
        arguments = [args],
        inputs = action_inputs_depset,
        outputs = action_outputs,
        tools = [tc.compiler],
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
            direct = [out_cmi],
    )

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
    ## FIXME: what about depsets.codeps etc.?
    ## this is not used anywhere?
    # ocamlInfo = MergedDepsProvider( ## MergedDepsProvider
    # )
    #     sigs  = depset(
    #         order = dsorder,
    #         direct = [out_cmi],
    #         transitive = depsets.deps.sigs
    #     ),
    #     cli_link_deps = depset(
    #         order = dsorder,
    #         transitive = depsets.deps.cli_link_deps
    #     ),
    #     archives = depset(
    #         order = dsorder,
    #         transitive = depsets.deps.archives
    #     ),
    #     afiles   = depset(
    #         order = dsorder,
    #         transitive = depsets.deps.afiles
    #     ),
    #     astructs = depset(
    #         order = dsorder,
    #         transitive = depsets.deps.astructs
    #     ),
    #     structs = depset(
    #         order = dsorder,
    #         transitive = depsets.deps.structs
    #     ),
    #     ofiles = depset(
    #         order=dsorder,
    #         transitive=depsets.deps.ofiles
    #     ),
    #     # mli = depset( ## FIXME: not needed?
    #     #     order=dsorder,
    #     #     direct = [work_mli],
    #     #     transitive=depsets.deps.mli
    #     # ),
    #     cmts = depset(
    #         order=dsorder,
    #         transitive=depsets.deps.cmts
    #     ),

    ## FIXME: deal with empty depsets.deps.cmtis
    # cmtis_depset = depset(
    #     order=dsorder,
    #     direct = [out_cmti],
    #     transitive = depsets.deps.cmtis
    # )

    #     paths = depset(
    #         order=dsorder,
    #         transitive=depsets.deps.paths
    #     ),
    #     jsoo_runtimes = depset(
    #         order=dsorder,
    #         transitive=depsets.deps.jsoo_runtimes
    #     ),
    # )

    ## FIXME: use MergedDepsProvider?
    ocamlProvider  = OCamlDepsProvider(
        # inputs   = new_inputs_depset,
        # linkargs = linkargs_depset,
        sigs       = sigs_depset,
        #FIXME: cmtis      = cmtis_depset,
        cli_link_deps = depset(
            order = dsorder,
            transitive = depsets.deps.cli_link_deps
        ),
        structs    = structs_depset,
        ofiles     = ofiles_depset,
        archives   = archives_depset,
        afiles     = afiles_depset,
        astructs   = astructs_depset,
        # cclibs   = cclibs_depset,
        paths      = paths_depset,
    )

    sigProvider = OCamlSignatureProvider(
        cmi = out_cmi,
        cmti = out_cmti if out_cmti else None,
        mli = work_mli,
        xmo = xmo, # True if xmo else False,
        merged_deps = MergedDepsProvider( # OCamlDepsProvider?
            # NB: sigs_depset contains out_cmi
            sigs       = sigs_depset,
            # cli_link_deps = depset(
            #     order = dsorder,
            #     transitive = depsets.deps.cli_link_deps
            # ),
            structs    = structs_depset,
            ofiles     = ofiles_depset,
            archives   = archives_depset,
            afiles     = afiles_depset,
            astructs   = astructs_depset,
            # cclibs   = cclibs_depset,
        paths      = paths_depset,
        )
    )

    ## FIXME:  cc deps
    # ccInfo = ...

    providers = [
        defaultInfo,
        ocamlProvider,
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
        sig  = default_depset,
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
    doc = """Generates OCaml .cmi (inteface) file. [User Guide](../ug/ocaml_signature.md). Provides `OCamlSignatureProvider`.

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
                [OcamlArchiveMarker],
                [OcamlImportMarker],
                [OcamlLibraryMarker],
                [OcamlModuleMarker],
                [OcamlNsMarker],
            ],
            # cfg = ocaml_signature_deps_out_transition
        ),
        src = attr.label(
            doc = "A single .mli source file label",
            allow_single_file = [".mli", ".ml"] #, ".cmi"]
        ),

        pack = attr.string(
            doc = "Experimental",
        ),

        open = attr.label_list(
            doc = "List of OCaml dependencies to be passed with -open.",
            providers = [
                [OCamlSignatureProvider],
                [OCamlDepsProvider],
                [OcamlArchiveMarker],
                [OcamlImportMarker],
                [OcamlLibraryMarker],
                [OcamlModuleMarker],
                [OcamlNsMarker],
            ],
            # cfg = ocaml_signature_deps_out_transition
        ),

        data = attr.label_list(
            allow_files = True
        ),

        ns_resolver = attr.label(
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

        module = attr.string(
            doc = "Set module (sig) name to this string"
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
    # cfg = toolchain_in_transition,
    provides = [OCamlSignatureProvider],
    executable = False,
    toolchains = ["@rules_ocaml//toolchain/type:std",
                  "@rules_ocaml//toolchain/type:profile",
                  "@bazel_tools//tools/cpp:toolchain_type"]
)

