load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/_transitions:ns_transitions.bzl", "nsarchive_in_transition")

load("//ocaml:providers.bzl",
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
     "PpxCodepsProvider",
)

load("//ocaml/_rules/utils:rename.bzl",
     "get_module_name",
     "rename_srcfile")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_transitions:transitions.bzl", "ocaml_signature_deps_out_transition")

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

load(":impl_ccdeps.bzl", "link_ccdeps", "dump_CcInfo")

load(":impl_common.bzl",
     "dsorder",
     "opam_lib_prefix",
     "tmpdir")

workdir = tmpdir

################
def _handle_ns_deps(ctx):
    debug    = True
    debug_ns = True

    if debug: print("_handle_ns_deps ****************")

    path_list = []

    ## renaming and ppx already handled we need: ns name for '-open
    ## <nsname>', deps for action inputs and target outputs.

    ## the resolver will be in one of two places:
    ##   ctx.attr._ns_resolver (topdown) default "@rules_ocaml//cfg/ns:resolver",
    ##   ctx.attr.ns_resolver  (bottomup) - defaults to None

    ## _ns_resolver is always present since it has a default value

    ns_enabled = False
    nsrp       = None  # OcamlNsResolverProvider
    nsop       = None  # ns resolver OcamlProvider
    ns_name    = None
    path_list  = []

    if ctx.attr.ns_resolver:
        if debug_ns: print("BOTTOMUP NS")
        ns_enabled = True
        ## topdown (hidden) resolver
        nsrp = ctx.attr.ns_resolver[OcamlNsResolverProvider]
        nsop = ctx.attr.ns_resolver[OcamlProvider]
        print("_NS_RESOLVER: %s" % nsrp)
        if hasattr(nsrp, "ns_name"):
            ns_name = nsrp.ns_name
            if debug_ns:
                print("TOP DOWN ns name: %s" % ns_name)

    elif ctx.attr._ns_resolver:
        nsrp = ctx.attr._ns_resolver[OcamlNsResolverProvider]
        nsop = ctx.attr._ns_resolver[OcamlProvider]
        if nsrp.ns_name:
            ns_name = nsrp.ns_name
            if debug_ns: print("TOPDOWN, ns name: %s" % ns_name)
            ns_enabled = True
        else:
            if debug_ns: print("NOT NAMEPACED - exiting _handle_ns_deps")
            return None

    ## DEPS
    ## ns resolvers have no deps
    ## however a user-defined resolver may have deps. sigh.
    ## so we need all six dep classes: sig, struct, ofile, archive, etc.
    ns_cmi             = None
    ns_struct          = None
    ns_ofile           = None

    sigs_secondary     = []
    structs_secondary  = []
    ofiles_secondary   = []
    astructs_secondary = []
    afiles_secondary   = []
    archives_secondary = []
    # cclibs_secondary = []

    if debug_ns: print("collecting ns deps")

    ns_cmi    = nsrp.cmi
    ns_struct = nsrp.struct
    ns_ofile  = nsrp.ofile
    sigs_secondary.append(nsop.sigs)
    structs_secondary.append(nsop.structs)
    ofiles_secondary.append(nsop.ofiles)
    archives_secondary.append(nsop.archives)
    afiles_secondary.append(nsop.afiles)
    astructs_secondary.append(nsop.astructs)
    # cclibs_secondary.append(nsop.cclibs)
    path_list.append(nsop.paths)

    if debug_ns: print("**************** exiting _handle_ns_deps")

    return (ns_enabled, ns_name, ns_cmi, ns_struct, ns_ofile,
            sigs_secondary, structs_secondary, ofiles_secondary,
            archives_secondary, afiles_secondary, astructs_secondary,
            # cclibs_secondary,
            path_list)

########## RULE:  OCAML_SIGNATURE  ################
def _ocaml_signature_impl(ctx):

    debug      = False
    debug_deps = False
    debug_ns   = False
    debug_ppx  = True
    debug_sig  = False
    debug_xmo  = False


    # if ctx.label.name in ["_Impl.cmi"]:
    #     debug = True

    if debug:
        print("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$")
        print("SIG %s" % ctx.label)

    tc = ctx.toolchains["@rules_ocaml//toolchain:type"]

    ################
    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    indirect_cc_deps  = {}

    ################
    includes   = []

    sig_src = ctx.file.src
    if debug:
        print("sig_src: %s" % sig_src)

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
        (from_name, modname) = get_module_name(ctx, ctx.file.src)

    # (from_name, module_name) = get_module_name(ctx, sig_src)

    if ctx.attr.ppx:
        if debug_ppx: print("ppxing sig")
        ## work_mli output is generated output of ppx processing
        work_mli = impl_ppx_transform("ocaml_signature", ctx,
                                      ctx.file.src, ## sig_src,
                                      modname + ".mli")
                                      # module_name + ".mli")
        work_cmi = ctx.actions.declare_file(
            workdir + modname + ".cmi")

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
        work_cmi = ctx.actions.declare_file(
            workdir + modname + ".cmi")

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

    # out_cmi = ctx.actions.declare_file(workdir + modname + ".cmi")
    out_cmi = work_cmi
    # out_cmi = ctx.actions.declare_file(workdir + module_name + ".cmi")
    if debug: print("out_cmi %s" % out_cmi)

    #########################
    args = ctx.actions.args()

    _options = get_options(rule, ctx)
    if "-opaque" in _options:
        xmo = False
    elif "-no-opaque" in _options:
        xmo = True
    else:
        xmo = ctx.attr._xmo

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

    # args.add_all(includes, before_each="-I", uniquify = True)

    # paths_primary   = []
    # paths_secondary = []
    # all_deps_list = []
    # direct_deps_list = []
    # archive_deps_list = []
    # archive_inputs_list = [] # not for command line!

    # input_deps_list = []

    #### INDIRECT DEPS first ####
    # these direct deps are "indirect" from the perspective of the consumer
    # indirect_inputs_depsets = []
    # indirect_linkargs_depsets = []
    indirect_paths_depsets = []

    ccInfo_list            = []

    sigs_primary           = []
    sigs_secondary         = []
    structs_primary        = []
    structs_secondary      = []
    ofiles_primary         = [] # never? ofiles only come from deps
    ofiles_secondary       = []
    astructs_primary       = []
    astructs_secondary     = []
    afiles_primary         = []
    afiles_secondary       = []
    archives_primary       = []
    archives_secondary     = []
    # cclibs_primary       = []
    # cclibs_secondary     = []
    path_depsets           = []

    the_deps = ctx.attr.deps + ctx.attr.open
    for dep in the_deps:

        if OcamlProvider in dep:
            # indirect_inputs_depsets.append(dep[OcamlProvider].inputs)
            # indirect_linkargs_depsets.append(dep[OcamlProvider].linkargs)
            indirect_paths_depsets.append(dep[OcamlProvider].paths)

            ## xmo-independent logic
            sigs_secondary.append(dep[OcamlProvider].sigs)
            structs_secondary.append(dep[OcamlProvider].structs)
            ofiles_secondary.append(dep[OcamlProvider].ofiles)
            archives_secondary.append(dep[OcamlProvider].archives)
            afiles_secondary.append(dep[OcamlProvider].afiles)
            astructs_secondary.append(dep[OcamlProvider].astructs)
            # cclibs_secondary.append(dep[OcamlProvider].cclibs)
            path_depsets.append(dep[OcamlProvider].paths)

        if CcInfo in dep:
            ccInfo_list.append(dep[CcInfo])

    ns_enabled = False
    ns_name    = None
    ns_cmi    = None
    ns_struct = None
    ns_ofile  = None

    if ctx.attr.ns_resolver:
        ns_enabled = True
    elif ctx.attr._ns_resolver:
        nsrp = ctx.attr._ns_resolver[OcamlNsResolverProvider]
        if nsrp.ns_name:
            ns_enabled = True

    ns_path_depsets = []
    if ns_enabled:
        (ns_enabled, ns_name,
         ns_cmi, ns_struct, ns_ofile,
         nssigs_secondary, nsstructs_secondary, nsofiles_secondary,
         nsarchives_secondary, nsafiles_secondary, nsastructs_secondary,
         # nscclibs_secondary,
         ns_path_depsets) = _handle_ns_deps(ctx)

        sigs_secondary.extend(nssigs_secondary)
        structs_secondary.extend(nsstructs_secondary)
        ofiles_secondary.extend(nsofiles_secondary)
        astructs_secondary.extend(nsastructs_secondary)
        afiles_secondary.extend(afiles_secondary)
        archives_secondary.extend(archives_secondary)
        # cclibs_secondary.extend(nscclibs_secondary)
        path_depsets.extend(ns_path_depsets)



    # print("SIGARCHDL: %s" % archive_deps_list)
    ################ PPX Adjunct Deps ################
    ## add adjunct_deps from ppx provider
    ## adjunct deps in the dep graph are NOT compile deps of this module.
    ## only the adjunct deps of the ppx are.
    adjunct_deps = []
    if ctx.attr.ppx:
        provider = ctx.attr.ppx[PpxCodepsProvider]

        for ppx_codep in provider.ppx_codeps.to_list():
            adjunct_deps.append(ppx_codep)
            # if OcamlImportArchivesMarker in ppx_codep:
            #     adjuncts = ppx_codep[OcamlImportArchivesMarker].archives
            #     for f in adjuncts.to_list():
            if ppx_codep.extension in ["cmxa", "a"]:
                if (ppx_codep.path.startswith(opam_lib_prefix)):
                    dir = paths.relativize(ppx_codep.dirname, opam_lib_prefix)
                    includes.append( "+../" + dir )
                else:
                    includes.append(ppx_codep.dirname)
                args.add(ppx_codep.path)

    paths_depset  = depset(
        order = dsorder,
        direct = [out_cmi.dirname],
        transitive = path_depsets + indirect_paths_depsets
    )

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
        args.add("-open", ns_name)
 # ctx.attr._ns_resolver[OcamlNsResolverProvider].ns_name)

    if ctx.attr.open:
        for dep in ctx.files.open:
            args.add("-open", normalize_module_name(dep.basename))

    args.add("-c")
    args.add("-o", out_cmi)

    args.add("-intf", work_mli)

    # inputs_depset = depset(
    #     order = dsorder,
    #     direct = [work_mli], # + ctx.files._ns_resolver,
    #     transitive = indirect_inputs_depsets + ns_resolver_depset
    # )
    action_inputs_depset = depset(
        order = dsorder,
        direct = [work_mli]
        + archives_primary
        + afiles_primary
        + astructs_primary,
        # + ns_resolver_files
        # + ctx.files.deps_runtime,
        transitive = # sigs_depsets
         # indirect_ppx_codep_depsets
        # + [ppx_codep_structset]
        # + [depset(direct=archives)]
         # ns_deps
        structs_secondary
        + ofiles_secondary
        + archives_secondary
        + afiles_secondary
        + astructs_secondary
        + sigs_secondary
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
        outputs = [out_cmi],
        tools = [tc.ocamlopt],
        mnemonic = "CompileOcamlSignature",
        progress_message = "{mode} compiling ocaml_signature: {ws}//{pkg}:{tgt}".format(
            mode = tc.target,
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

    sigProvider = OcamlSignatureProvider(
        mli = work_mli,
        cmi = out_cmi,
        xmo = True if xmo else False
    )

    # new_inputs_depset = depset(
    #     direct = [out_cmi],
    #     transitive = indirect_inputs_depsets
    # )
    # linkargs_depset = depset(
    #     # cmi file does not go in linkargs
    #     transitive = indirect_linkargs_depsets
    # )

    sigs_depset = depset(
        order = dsorder,
        direct = [out_cmi],
        transitive = sigs_secondary
    )
    structs_depset = depset(
        order = dsorder,
        transitive = structs_secondary
    )
    ofiles_depset   = depset(order=dsorder,
                           transitive=ofiles_secondary)
    archives_depset = depset(order=dsorder,
                             transitive=archives_secondary)
    afiles_depset   = depset(order=dsorder,
                            transitive=afiles_secondary)
    astructs_depset = depset(order=dsorder,
                              transitive=astructs_secondary)
    # cclibs_depset = depset(order=dsorder,
    #                          transitive=cclibs_secondary)

    ocamlProvider  = OcamlProvider(
        # inputs   = new_inputs_depset,
        # linkargs = linkargs_depset,
        sigs       = sigs_depset,
        structs    = structs_depset,
        ofiles     = ofiles_depset,
        archives   = archives_depset,
        afiles     = afiles_depset,
        astructs   = astructs_depset,
        # cclibs   = cclibs_depset,
        paths      = paths_depset,
    )

    providers = [
        defaultInfo,
        ocamlProvider,
        sigProvider,
    ]

    ## ppx codeps? signatures may contribute to construction of a
    ## ppx_executable, but they will not inject codeps, since they are
    ## just interfaces, not runing code.

    if ccInfo_list:
        providers.append(
            cc_common.merge_cc_infos(cc_infos = ccInfo_list)
        )


    outputGroupInfo = OutputGroupInfo(
        cmi        = default_depset,
    )

    providers.append(outputGroupInfo)

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
    toolchains = ["@rules_ocaml//toolchain:type"],
)
