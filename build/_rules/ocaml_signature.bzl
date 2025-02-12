load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//build:providers.bzl",
     "OcamlArchiveMarker",
     "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker",
     "OCamlNsResolverProvider",
     "OCamlProvider",
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
     "aggregate_deps",
     "aggregate_codeps",
     "DepsAggregator",
     "MergedDepsProvider",      #  ??
     "COMPILE", "LINK", "COMPILE_LINK")

load("//build:actions.bzl", "ppx_transformation")

workdir = tmpdir

##########################
def _handle_ns_stuff(ctx):

    debug_ns = False

    if not hasattr(ctx.attr, "ns_resolver"):
        ## this is an ocaml_ns_resolver module
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

    # elif hasattr(ctx.attr, "_ns_resolver"):
    #     if debug_ns: print("m: implicit resolver for %s" % ctx.label)
    #     ns_resolver = ctx.attr._ns_resolver ## [0] # index by int?
    #     ns_resolver_files = ctx.files._ns_resolver ## [0] # index by int?

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

################
# def _handle_ns_deps(ctx):
#     debug    = False
#     debug_ns = False

#     if debug_ns:
#         if debug: print("_handle_ns_deps ****************")

#     path_list = []

#     ## renaming and ppx already handled we need: ns name for '-open
#     ## <nsname>', deps for action inputs and target outputs.

#     ## the resolver will be in one of two places:
#     ##   ctx.attr._ns_resolver (topdown) default "@rules_ocaml//cfg/ns:resolver",
#     ##   ctx.attr.ns_resolver  (bottomup) - defaults to None

#     ## _ns_resolver is always present since it has a default value

#     ns_enabled = False
#     nsrp       = None  # OCamlNsResolverProvider
#     nsop       = None  # ns resolver OCamlProvider
#     ns_name    = None
#     path_list  = []

#     if ctx.attr.ns_resolver:
#         if debug_ns: print("BOTTOMUP NS")
#         ns_enabled = True
#         ## topdown (hidden) resolver
#         nsrp = ctx.attr.ns_resolver[OCamlNsResolverProvider]
#         nsop = ctx.attr.ns_resolver[OCamlProvider]
#         print("_NS_RESOLVER: %s" % nsrp)
#         if hasattr(nsrp, "ns_name"):
#             ns_name = nsrp.ns_name
#             if debug_ns:
#                 print("TOP DOWN ns name: %s" % ns_name)

#     elif ctx.attr._ns_resolver:
#         nsrp = ctx.attr._ns_resolver[OCamlNsResolverProvider]
#         nsop = ctx.attr._ns_resolver[OCamlProvider]
#         if nsrp.ns_name:
#             ns_name = nsrp.ns_name
#             if debug_ns: print("TOPDOWN, ns name: %s" % ns_name)
#             ns_enabled = True
#         else:
#             if debug_ns: print("NOT NAMEPACED - exiting _handle_ns_deps")
#             return None

#     ## DEPS
#     ## ns resolvers have no deps
#     ## however a user-defined resolver may have deps. sigh.
#     ## so we need all six dep classes: sig, struct, ofile, archive, etc.
#     ns_cmi             = None
#     ns_struct          = None
#     ns_ofile           = None

#     sigs_secondary     = []
#     structs_secondary  = []
#     ofiles_secondary   = []
#     astructs_secondary = []
#     afiles_secondary   = []
#     archives_secondary = []
#     # cclibs_secondary = []

#     if debug_ns: print("collecting ns deps")

#     ns_cmi    = nsrp.cmi
#     ns_struct = nsrp.struct
#     ns_ofile  = nsrp.ofile
#     sigs_secondary.append(nsop.sigs)
#     structs_secondary.append(nsop.structs)
#     ofiles_secondary.append(nsop.ofiles)
#     archives_secondary.append(nsop.archives)
#     afiles_secondary.append(nsop.afiles)
#     astructs_secondary.append(nsop.astructs)
#     # cclibs_secondary.append(nsop.cclibs)
#     path_list.append(nsop.paths)

#     if debug_ns: print("**************** exiting _handle_ns_deps")

#     return (ns_enabled, ns_name, ns_cmi, ns_struct, ns_ofile,
#             sigs_secondary, structs_secondary, ofiles_secondary,
#             archives_secondary, afiles_secondary, astructs_secondary,
#             # cclibs_secondary,
#             path_list)

########## RULE:  OCAML_SIGNATURE  ################
def _ocaml_signature_impl(ctx):

    debug      = False
    debug_deps = False
    debug_ns   = False
    debug_ppx  = False
    debug_sig  = False
    debug_tc   = False
    debug_xmo  = False


    # if ctx.label.name in ["_Impl.cmi"]:
    #     debug = True

    if debug:
        print("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$")
        print("SIG %s" % ctx.label)

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
    ## bottom-up namespacing
    if ctx.attr.ns_resolver:
        ns_enabled = True
        ns_resolver = ctx.attr.ns_resolver ## [0] # index by int?
        ns_resolver_files = ctx.files.ns_resolver ## [0] # index by int?
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
            ns_name = nsrp.ns_name
            ns_module_name = nsrp.module_name
            ns_resolver = ctx.attr._ns_resolver ## [0] # index by int?
            ns_resolver_files = ctx.files._ns_resolver ## [0] # index by int?
        # if hasattr(nsrp, "ns_module_name"):
            # ns_enabled = True

    # elif ctx.attr.resolver:
    #     if debug_ns: print("lib: user-provided resolver")
    #     ns_resolver = ctx.attr.resolver
    #     ns_resolver_files = ctx.files.resolver
    # elif hasattr(ctx.attr, "_ns_resolver"):
    #     if debug_ns: print("lib: implicit resolver for %s" % ctx.label)
    #     ns_resolver = ctx.attr._ns_resolver ## [0] # index by int?
    #     ns_resolver_files = ctx.files._ns_resolver ## [0] # index by int?
    else:
        if debug_ns: print("lib: no resolver for %s" % ctx.label)
        ns_resolver = None
        ns_resolver_files = []

    (ns_enabled, ns_name, nsrp, ns_resolver) = _handle_ns_stuff(ctx)


    manifest = []
    ## FIXME: handle non-namespaced archive manifests
    # if hasattr(nsrp, "submodules"):
    #     manifest = nsrp.submodules
    #     if debug_ns:
    #         print("ns manifest: %s" % manifest)

    depsets = DepsAggregator()

    for dep in ctx.attr.deps:
        depsets = aggregate_deps(ctx, dep, depsets, manifest)

    for dep in ctx.attr.open: # opened modules are deps
        depsets = aggregate_deps(ctx, dep, depsets, manifest)

    if ns_enabled:
        depsets = aggregate_deps(ctx, ns_resolver, depsets, manifest)

    ## NB: sigs never have direct codeps
    if ctx.attr.ppx:
        depsets = aggregate_deps(ctx, ctx.attr.ppx, depsets, manifest)

    if hasattr(ctx.attr, "ppx_compile_codeps"):
        for codep in ctx.attr.ppx_compile_codeps:
            depsets = aggregate_codeps(ctx, COMPILE, codep, depsets, manifest)

    if hasattr(ctx.attr, "ppx_link_codeps"):
        for codep in ctx.attr.ppx_link_codeps:
            depsets = aggregate_codeps(ctx, LINK, codep, depsets, manifest)

    # add prefix if namespaced. from_name == normalized module name
    # derived from sig_src; module_name == prefixed if ns else same as
    # from_name.

    modname = None
    # if ctx.label.name[:1] == "@":
    # if ctx.attr.forcename:
    if ctx.attr.module:
        if debug: print("Setting module name to %s" % ctx.attr.module)
        basename = ctx.attr.module
        modname = basename[:1].capitalize() + basename[1:]
        #FIXME: add ns prefix if needed
    else:
        (mname, extension) = paths.split_extension(
            ctx.file.src.basename)
        (from_name, modname) = derive_module_name_from_file_name(ctx, mname)
        # (from_name, modname) = derive_module_name_from_file_name(ctx, ctx.file.src)

    # (from_name, module_name) = derive_module_name_from_file_name(ctx, sig_src)

    if ctx.attr.ppx:
        if debug_ppx: print("ppxing sig")
        ## work_mli output is generated output of ppx processing
        ppx_src_mli, work_mli = ppx_transformation("ocaml_signature", ctx,
                                      ctx.file.src, ## sig_src,
                                      modname + ".mli")
                                      # module_name + ".mli")
        # work_cmi = ctx.actions.declare_file(
        #     workdir + modname + ".cmi")

    else:
        ## for now, symlink everything to workdir
        ## later we can optimize, avoiding symlinks if src in pkg dir
        ## and no renaming
        if debug: print("no ppx")
        work_mli = ctx.actions.declare_file(
            workdir + modname + ".mli")
        ctx.actions.symlink(output = work_mli,
                            target_file = ctx.file.src)
    out_cmi = ctx.actions.declare_file(workdir + modname + ".cmi")

    action_outputs = [out_cmi]
    if debug: print("out_cmi %s" % out_cmi)

    #########################
    args = ctx.actions.args()

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
        out_cmti = ctx.actions.declare_file(workdir + modname + ".cmti")
        action_outputs.append(out_cmti)
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


    # ccInfo_list            = []

    ################ PPX Codeps ################

    ## FIXME: ppx codeps aggregated above; here, deal with
    ## depsets.codeps

    ## add ppx_codeps from ppx provider
    ## only the codeps of the ppx executable deps of this sig.
    ## ppx codeps in the dep graph are NOT compile deps of this sig.
    # ppx_codeps_inputs = []
    # if ctx.attr.ppx:
    #     provider = ctx.attr.ppx[OCamlCodepsProvider]

    #     for ppx_codep in provider.sigs.to_list():
    #         ppx_codeps_inputs.append(ppx_codep)

    #     for ppx_codep in provider.structs.to_list():
    #         ppx_codeps_inputs.append(ppx_codep)

    #         # if OcamlImportArchivesMarker in ppx_codep:
    #         #     adjuncts = ppx_codep[OcamlImportArchivesMarker].archives
    #         #     for f in adjuncts.to_list():

    #     for ppx_codep in provider.archives.to_list():
    #         # if ppx_codep.extension in ["cmxa", "a"]:
    #         if (ppx_codep.path.startswith(opam_lib_prefix)):
    #             dir = paths.relativize(ppx_codep.dirname, opam_lib_prefix)
    #             includes.append( "+../" + dir )
    #         else:
    #             includes.append(ppx_codep.dirname)
    #         # args.add(ppx_codep.path)
    #         ppx_codeps_inputs.append(ppx_codep)

    paths_depset = depset(
        order=dsorder,
        direct = [out_cmi.dirname],
        transitive = depsets.deps.paths # astructs_secondary
    )

    ##FIXME depsets.deps.paths should be a depset?
    args.add_all(paths_depset.to_list(), before_each="-I")

    # for f in ctx.files._ns_resolver:
    #     if f.extension == "cmx":
    #         args.add("-I", f.dirname) ## REQUIRED, even if cmx has full path
    #         args.add(f.path)

    # if OCamlProvider in ctx.attr._ns_resolver:
    #     ns_resolver_depset = [ctx.attr._ns_resolver[OCamlProvider].inputs]
    # else:
    #     ns_resolver_depset = []

    if ns_enabled:
        args.add("-no-alias-deps")
        args.add("-open", nsrp.module_name)
 # ctx.attr._ns_resolver[OCamlNsResolverProvider].ns_name)

    if ctx.attr.open:
        for dep in ctx.files.open:
            args.add("-open", normalize_module_name(dep.basename))

    args.add("-c")
    args.add("-o", out_cmi)

    args.add("-intf", work_mli)
    # args.add(work_mli)

    # inputs_depset = depset(
    #     order = dsorder,
    #     direct = [work_mli], # + ctx.files._ns_resolver,
    #     transitive = indirect_inputs_depsets + ns_resolver_depset
    # )
    action_inputs_depset = depset(
        order = dsorder,

        direct = [work_mli]
        # + archives_primary
        # + afiles_primary
        # + astructs_primary
        # + ns_resolver_files
        # + ctx.files.deps_runtime,
        # + ppx_codeps_inputs
        ,
        transitive =
        depsets.deps.sigs
        + depsets.codeps.sigs
        + depsets.codeps.cli_link_deps
        + depsets.codeps.structs
        + depsets.codeps.ofiles
        + depsets.codeps.astructs
        + depsets.codeps.archives ## FIXME: redundant (cli_link_deps)
        + depsets.codeps.afiles
    )
    #     print("SIGACTION INPUTS: %s" % ctx.label)
    #     for dep in action_inputs_depset.to_list():
    #         print("IDEP: %s" % dep.path)
    # #         # args.add("-I", dep.short_path)
    #         args.add("-I", dep.dirname)

    ################
    ctx.actions.run(
        # env = env,
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

    # sigInfo = OCamlSigInfo(
    #     cmi  = out_cmi,
    #     cmti = out_cmti if out_cmti else None,
    #     mli  = work_mli,
    #     xmo  = True if xmo else False
    # )

    sigProvider = OCamlSignatureProvider( #FIXME: obsolete?
        cmi = out_cmi,
        cmti = out_cmti if out_cmti else None,
        mli = work_mli,
        xmo = True if xmo else False
    )

    # sigs_depset = depset(
    #     order = dsorder,
    #     direct = [out_cmi],
    #     transitive = sigs_secondary
    # )
    sigs_depset = depset(
        order = dsorder,
        direct = [out_cmi],
        transitive = depsets.deps.sigs
    )
    structs_depset = depset(
        order = dsorder,
        transitive = depsets.deps.structs ## structs_secondary
    )
    ofiles_depset   = depset(
        order=dsorder,
        transitive=depsets.deps.ofiles ##ofiles_secondary
    )
    archives_depset = depset(
        order = dsorder,
        transitive = depsets.deps.archives #archives_secondary
    )
    afiles_depset   = depset(
        order = dsorder,
        transitive = depsets.deps.afiles #afiles_secondary
    )
    astructs_depset = depset(
        order=dsorder,
        transitive = depsets.deps.astructs # astructs_secondary
    )
    # cclibs_depset = depset(order=dsorder,
    #                          transitive=cclibs_secondary)

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
    #     cmtis = depset(
    #         order=dsorder,
    #         direct = out_cmti,
    #         transitive=depsets.deps.cmtis
    #     ),
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
    ocamlProvider  = OCamlProvider(
        # inputs   = new_inputs_depset,
        # linkargs = linkargs_depset,
        sigs       = sigs_depset,
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

    ## FIXME:  cc deps
    # ccInfo = ...

    providers = [
        defaultInfo,
        # ocamlInfo,
        ocamlProvider,
        sigProvider,
    ]

    ## ppx codeps? signatures may contribute to construction of a
    ## ppx_executable, but they will not inject codeps, since they are
    ## just interfaces, not running code.

    ## FIXME: handle depsets.ccinfos
    # if ccInfo_list:
    #     providers.append(
    #         cc_common.merge_cc_infos(cc_infos = ccInfo_list)
    #     )

    # outputGroupInfo = OutputGroupInfo(
    #     cmi        = default_depset,
    # )

    # providers.append(outputGroupInfo)

    return providers


################################################################
################################################################

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
                [OCamlProvider],
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
                [OCamlProvider],
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

