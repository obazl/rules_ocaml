load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

# load("//ocaml/_transitions:in_transitions.bzl",
#      "nsarchive_in_transition")

# load("//ocaml/_transitions:out_transitions.bzl",
#      "ocaml_signature_deps_out_transition")

load("//ocaml:providers.bzl",
     "OCamlSigInfo",
     "OcamlProvider",

     "OcamlArchiveMarker",
     "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker",
     "OcamlNsResolverProvider",
     "OcamlSDK",
     "OcamlSignatureProvider")

load("//ppx:providers.bzl",
     "PpxCodepsInfo",
)

load("@rules_ocaml//ocaml:ocamlinfo.bzl",
     "aggregate_deps",
     "aggregate_codeps",
     "new_deps_aggregator",
     "DepsAggregator",
     "OCamlInfo",
     "COMPILE", "LINK", "COMPILE_LINK")

load("//ocaml/_functions:module_naming.bzl",
     "derive_module_name_from_file_name")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     # "get_sdkpath",
)
load("//ocaml/_functions:module_naming.bzl",
     "normalize_module_name",
     "normalize_module_label")

load(":options.bzl",
     "options",
     "options_ns_opts",
     "options_ppx",
     "options_signature")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

# load(":impl_ccdeps.bzl", "link_ccdeps", "dump_CcInfo")

load(":impl_common.bzl",
     "dsorder",
     "opam_lib_prefix",
     "tmpdir")

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
        nsrp = ctx.attr.ns_resolver[OcamlNsResolverProvider]
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
        nsrp = ctx.attr._ns_resolver[OcamlNsResolverProvider]
        if debug_ns:
            print("_ns_resolver: %s" % ctx.attr._ns_resolver)
            print("nsrp: %s" % nsrp)
        if not nsrp.tag == "NULL": # hasattr(nsrp, "ns_name"):
            ns_enabled = True
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
    #     c=CCGRN, r=CCRESET, s=ctx.attr._ns_resolver[OcamlNsResolverProvider]))
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
#     nsrp       = None  # OcamlNsResolverProvider
#     nsop       = None  # ns resolver OcamlProvider
#     ns_name    = None
#     path_list  = []

#     if ctx.attr.ns_resolver:
#         if debug_ns: print("BOTTOMUP NS")
#         ns_enabled = True
#         ## topdown (hidden) resolver
#         nsrp = ctx.attr.ns_resolver[OcamlNsResolverProvider]
#         nsop = ctx.attr.ns_resolver[OcamlProvider]
#         print("_NS_RESOLVER: %s" % nsrp)
#         if hasattr(nsrp, "ns_name"):
#             ns_name = nsrp.ns_name
#             if debug_ns:
#                 print("TOP DOWN ns name: %s" % ns_name)

#     elif ctx.attr._ns_resolver:
#         nsrp = ctx.attr._ns_resolver[OcamlNsResolverProvider]
#         nsop = ctx.attr._ns_resolver[OcamlProvider]
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
        nsrp = ctx.attr.ns_resolver[OcamlNsResolverProvider]
        if hasattr(nsrp, "ns_name"):
            ns_name = nsrp.ns_name
            ns_enabled = True

        if hasattr(nsrp, "ns_module_name"):
            ns_module_name = nsrp.ns_module_name
            ns_enabled = True

    ## top-down namespacing
    elif ctx.attr._ns_resolver:
        nsrp = ctx.attr._ns_resolver[OcamlNsResolverProvider]
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

    depsets = new_deps_aggregator()

    for dep in ctx.attr.deps:
        depsets = aggregate_deps(ctx, dep, depsets, manifest)

    for dep in ctx.attr.open: # opened modules are deps
        depsets = aggregate_deps(ctx, dep, depsets, manifest)

    if ns_enabled:
        depsets = aggregate_deps(ctx, ns_resolver, depsets, manifest)

    if hasattr(ctx.attr, "ppx_codeps"):
        for codep in ctx.attr.ppx_codeps:
            depsets = aggregate_codeps(ctx, COMPILE_LINK, codep, depsets, manifest)

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
        work_mli = impl_ppx_transform("ocaml_signature", ctx,
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
        # sp = ctx.file.src.short_path
        # spdir = paths.dirname(sp)
        # if paths.basename(spdir) + "/" == workdir:
        #     pkgdir = paths.dirname(spdir)
        # else:
        #     pkgdir = spdir
        # print("target spec pkg: %s" % ctx.label.package)
        # print("sigfiles pkgdir: %s" % pkgdir)

        # if ctx.label.package == pkgdir:
        #     print("PKGDIR == sigfile dir")
        #     sigsrc_modname = normalize_module_name(ctx.file.src.basename)
        #     print("sigsrc modname %s" % sigsrc_modname)
        #     if modname == sigsrc_modname:
        #         work_mli = ctx.file.src
        #         work_cmi = ctx.actions.declare_file(modname + ".cmi")
        #     else:
        #         work_mli = ctx.actions.declare_file(
        #             workdir + modname + ".mli")
        #         ctx.actions.symlink(output = work_mli,
        #                             target_file = ctx.file.src)
        #         work_cmi = ctx.actions.declare_file(
        #             workdir + modname + ".cmi")

        #     # work_cmi = sigProvider.cmi
        # else:  ## mli src in different pkg dir
        # if from_name == module_name:
        #     if debug: print("no namespace renaming")
        #     # work_mli = sig_src
        work_mli = ctx.actions.declare_file(
            workdir + modname + ".mli")
            # workdir + ctx.file.mli.basename)
        ctx.actions.symlink(output = work_mli,
                            target_file = ctx.file.src)
        # out_cmi = ctx.actions.declare_file(modname + ".cmi")
        # work_cmi = ctx.actions.declare_file(
        #     workdir + modname + ".cmi")

        # else:
        #     if debug: print("namespace renaming")
        #     # namespaced w/o ppx: symlink sig_src to prefixed name, so
        #     # that output dir will contain both renamed input mli and
        #     # output cmi.
        #     ns_sig_src = module_name + ".mli"
        #     if debug:
        #         print("ns_sig_src: %s" % ns_sig_src)
        #     work_mli = ctx.actions.declare_file(workdir + ns_sig_src)
        #     ctx.actions.symlink(output = work_mli,
        #                         target_file = sig_src)
        #     if debug:
        #         print("work_mli %s" % work_mli)

    out_cmi = ctx.actions.declare_file(workdir + modname + ".cmi")

    # out_cmi = ctx.actions.declare_file(workdir + modname + ".cmi")
    # out_cmi = work_cmi
    action_outputs = [out_cmi]
    # out_cmi = ctx.actions.declare_file(workdir + module_name + ".cmi")
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
    #     provider = ctx.attr.ppx[PpxCodepsInfo]

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

    # if OcamlProvider in ctx.attr._ns_resolver:
    #     ns_resolver_depset = [ctx.attr._ns_resolver[OcamlProvider].inputs]
    # else:
    #     ns_resolver_depset = []

    if ns_enabled:
        args.add("-no-alias-deps")
        args.add("-open", nsrp.module_name)
 # ctx.attr._ns_resolver[OcamlNsResolverProvider].ns_name)

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
        # we only need sig deps?

         # indirect_ppx_codep_depsets
        # + [ppx_codep_structset]
        # + [depset(direct=archives)]
         # ns_deps
        # depsets.deps.structs # structs_secondary
        # + depsets.deps.ofiles # ofiles_secondary
        # + depsets.deps.archives # archives_secondary
        # + depsets.deps.afiles   # afiles_secondary
        # + depsets.deps.astructs # astructs_secondary
        # + cclibs_secondary
        # + bottomup_ns_inputs
    )
    # if ctx.label.name in ["Red_cmi"]:
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

    sigInfo = OCamlSigInfo(
        cmi  = out_cmi,
        cmti = out_cmti if out_cmti else None,
        mli  = work_mli,
        xmo  = True if xmo else False
    )

    sigProvider = OcamlSignatureProvider( #FIXME: obsolete
        mli = work_mli,
        cmi = out_cmi,
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
    ocamlInfo = OCamlInfo(
        sigs  = depset(
            order = dsorder,
            direct = [out_cmi],
            transitive = depsets.deps.sigs
        ),
        cli_link_deps = depset(
            order = dsorder,
            transitive = depsets.deps.cli_link_deps
        ),
        archives = depset(
            order = dsorder,
            transitive = depsets.deps.archives
        ),
        afiles   = depset(
            order = dsorder,
            transitive = depsets.deps.afiles
        ),
        astructs = depset(
            order = dsorder,
            transitive = depsets.deps.astructs
        ),
        structs = depset(
            order = dsorder,
            transitive = depsets.deps.structs
        ),
        ofiles = depset(
            order=dsorder,
            transitive=depsets.deps.ofiles
        ),
        # mli = depset( ## FIXME: not needed?
        #     order=dsorder,
        #     direct = [work_mli],
        #     transitive=depsets.deps.mli
        # ),
        cmts = depset(
            order=dsorder,
            transitive=depsets.deps.cmts
        ),
        cmtis = depset(
            order=dsorder,
            direct = out_cmti,
            transitive=depsets.deps.cmtis
        ),
        paths = depset(
            order=dsorder,
            transitive=depsets.deps.paths
        ),
        jsoo_runtimes = depset(
            order=dsorder,
            transitive=depsets.deps.jsoo_runtimes
        ),
    )

    ocamlProvider  = OcamlProvider(
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
        ocamlInfo,
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
rule_options = options("ocaml")
rule_options.update(options_signature)
# rule_options.update(options_ns_opts("ocaml"))
rule_options.update(options_ppx)

#######################
ocaml_signature = rule(
    implementation = _ocaml_signature_impl,
    doc = """Generates OCaml .cmi (inteface) file. [User Guide](../ug/ocaml_signature.md). Provides `OcamlSignatureProvider`.

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
    attrs = dict(
        rule_options,
        ## RULE DEFAULTS
        # _linkall     = attr.label(default = "@rules_ocaml//cfg/signature/linkall"), # FIXME: call it alwayslink?
        # _threads     = attr.label(default = "@rules_ocaml//cfg/signature/threads"),
        _warnings  = attr.label(default = "@rules_ocaml//cfg/signature:warnings"),
        #### end options ####

        # src = attr.label(
        #     doc = "A single .mli source file label",
        #     allow_single_file = [".mli", ".ml"] #, ".cmi"]
        # ),

        # ns_submodule = attr.label_keyed_string_dict(
        #     doc = "Extract cmi file from namespaced module",
        #     providers = [
        #         [OcamlNsMarker, OcamlArchiveMarker],
        #     ]
        # ),

        # pack = attr.string(
        #     doc = "Experimental",
        # ),

        # deps = attr.label_list(
        #     doc = "List of OCaml dependencies. Use this for compiling a .mli source file with deps. See [Dependencies](#deps) for details.",
        #     providers = [
        #         [OcamlProvider],
        #         [OcamlArchiveMarker],
        #         [OcamlImportMarker],
        #         [OcamlLibraryMarker],
        #         [OcamlModuleMarker],
        #         [OcamlNsMarker],
        #     ],
        #     # cfg = ocaml_signature_deps_out_transition
        # ),

        # data = attr.label_list(
        #     allow_files = True
        # ),

        # ################################################################
        # _ns_resolver = attr.label(
        #     doc = "Experimental",
        #     providers = [OcamlNsResolverProvider],
        #     default = "@rules_ocaml//cfg/ns:resolver",
        #     # cfg = ocaml_signature_deps_out_transition
        # ),

        # _ns_submodules = attr.label( # _list(
        #     doc = "Experimental.  May be set by ocaml_ns_library containing this module as a submodule.",
        #     default = "@rules_ocaml//cfg/ns:submodules", ## NB: ppx modules use ocaml_signature
        # ),
        # _ns_strategy = attr.label(
        #     doc = "Experimental",
        #     default = "@rules_ocaml//cfg/ns:strategy"
        # ),
        # _mode       = attr.label(
        #     default = "@rules_ocaml//build/mode",
        # ),

        module = attr.string(
            doc = "Set module (sig) name to this string"
        ),

        xmo = attr.bool(
            doc = "Cross-module optimization. If false, compile with -opaque",
            default = True
        ),

        _rule = attr.string( default = "ocaml_signature" ),

        # _sdkpath = attr.label(
        #     default = Label("@rules_ocaml//cfg:sdkpath")
        # ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
    ),
    incompatible_use_toolchain_transition = True,
    provides = [OcamlSignatureProvider],
    executable = False,
    toolchains = ["@rules_ocaml//toolchain/type:std",
                  "@rules_ocaml//toolchain/type:profile",
                  "@bazel_tools//tools/cpp:toolchain_type"]
)
