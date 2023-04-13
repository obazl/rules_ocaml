load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("@rules_ocaml//providers:moduleinfo.bzl", "OCamlModuleInfo")

load("@rules_ocaml//ocaml:ocamlinfo.bzl",
     "aggregate_deps",
     "aggregate_codeps",
     "new_deps_aggregator",
     "DepsAggregator",
     "OCamlInfo",
     "COMPILE", "LINK", "COMPILE_LINK")

load("//ocaml:providers.bzl",
     "OcamlModuleMarker",
     "OcamlProvider",
     "OcamlNsResolverProvider",
     "OcamlNsSubmoduleMarker")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_fs_prefix",
     # "get_sdkpath",
)

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load("//ocaml/_functions:module_naming.bzl",
     "label_to_module_name",
     "normalize_module_label",
     "normalize_module_name")

load(":impl_common.bzl",
     "dsorder",
     "module_sep",
     "opam_lib_prefix",
     "resolver_suffix",
     "tmpdir"
     )

load("@rules_ocaml//ocaml/_debug:colors.bzl",
     "CCRED", "CCREDBG", "CCYEL", "CCGRN", "CCBLU", "CCMAG", "CCCYN", "CCRESET")

CCBLUYEL = "\033[44m\033[33m"

workdir = tmpdir

#################
def impl_ns_resolver(ctx):

    debug            = False
    debug_ns         = False
    debug_submodules = False
    debug_includes   = False
    debug_embeds     = False
    debug_merges     = False
    # if ctx.label.name == "Jsoo_runtime":
    #     debug = True

    ## if resolver is user-provided, then this should immediately
    ## return a null result

    if debug:
        print("{c}ocaml_ns_resolver: {lbl}{r}".format(
            c=CCBLUYEL, lbl=ctx.label, r=CCRESET))

        print("{c}attrs:{r}".format(c=CCYEL,r=CCRESET))
        print("attr._ns_prefixes: %s" % ctx.attr._ns_prefixes[BuildSettingInfo].value)
        # print("attr._ns_submodules: %s" % ctx.attr._ns_submodules[BuildSettingInfo].value)

    ## if ns:prefixes and ns:submodules are empty, return empy

    ################################################################

    tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]

    depsets = new_deps_aggregator()


    ## RULE: do not allow mixing bottomup and topdown namespaces.
    # but what happens if a selected submodule also elects?

    bottomup = False

    if ctx.attr.ns:
        bottomup = True
        if debug: print("has ns attr: %s" % ctx.attr.ns)
        # fail("fasdf")
        ns_prefixes = [ctx.attr.ns]
    else:
        # ns_prefixes = [ctx.label.name]
        ns_prefixes = ctx.attr._ns_prefixes[BuildSettingInfo].value
        if debug: print("no ns attr, using _ns_prefixes: %s" % ns_prefixes)

    if ctx.attr.manifest:
        ## verify not also topdown
        subnames = ctx.attr.manifest
        if debug: print("subnames: has manifest attr: %s" % subnames)
    else:
        subnames = ctx.attr._ns_submodules[BuildSettingInfo].value
        if debug: print("subnames: no manifest attr, using _ns_submodules: %s" % subnames)
        # for sub in subnames:
        #     print("subname: %s" % sub[0])

        bottomup = False

    subnames_ct = len(subnames)

    ################
    if len(ns_prefixes) == 0 and subnames_ct == 0:
        if debug:
            print("{c}returning null ns_resolver{r}".format(c=CCREDBG,r=CCRESET))
        return [DefaultInfo(),
                OcamlProvider(),
                OcamlNsResolverProvider(tag = "NULL")
                ]
    ################

    if bottomup:
        if len(ctx.attr.manifest) < 1:
            if len(ctx.attr.include) < 1:
                if len(ctx.attr.embed) < 1:
                    if len(ctx.attr.merge) < 1:
                        if debug:
                            print("NO SUBMODULES/MODULES/MERGE")
                            print("label: %s" % ctx.label)
                        return [DefaultInfo(),
                                OcamlProvider(),
                                OcamlNsResolverProvider(ns_name = "FOO")]

    # env = {"PATH": get_sdkpath(ctx)}

    ################
    default_outputs = [] ## .cmi, .cmo or .cmx, .o
    action_outputs = []  ## .cmx, .cmi, .o
    rule_outputs = [] # excludes .cmi

    out_struct = None
    out_cmi = None

    aliases = []

    if debug:
        print("ctx.attr.ns: %s" % ctx.attr.ns)
        print("ctx.attr._ns_prefixes: %s" % ctx.attr._ns_prefixes[BuildSettingInfo].value)

    sigs_primary   = []
    sigs_secondary = []
    structs_primary   = []
    structs_secondary = []
    ofiles_primary   = [] # never? ofiles only come from deps
    ofiles_secondary = []
    astructs_primary = []
    astructs_secondary = []
    afiles_primary   = []
    afiles_secondary = []
    archives_primary = []
    archives_secondary = []
    # cclibs_primary = []
    # cclibs_secondary = []

    no_main_alias = False
    # if subnames_ct == 0:
    #     no_main_alias = False
    # else:
    #     no_main_alias = True
    user_ns_resolver = None

    if debug_submodules: print("iterating submodules: %s" % subnames)
    for submod_label in subnames:  # e.g. [Color, Red, Green, Blue], where main = Color
        if debug_submodules: print("next submod label: %s" % submod_label)
        if debug_submodules: print("next submod: %s" % submod_label)

        submod_is_main = False

        # NB: //a/b:c will be normalized to C
        submodule = label_to_module_name(submod_label)
        if debug_submodules: print("submodule normed: %s" % submodule)
        # if ctx.attr._ns_strategy[BuildSettingInfo].value == "fs":
        #     ## NB: subnames may come from different pkgs
        #     fs_prefix = get_fs_prefix(submod_label)
        #     alias_prefix = fs_prefix
        # else:
        fs_prefix = ""
        alias_prefix = module_sep.join(ns_prefixes) ## ns_prefix
        if debug_submodules: print("alias_prefix: %s" % alias_prefix)

        ## an ns can be used as a submodule of another ns
        nslib_submod = False
        # if submodule.startswith("#"):
        #     # this is an nslib submodule, do not prefix
        #     nslib_submod = True
        #     submodule = capitalize_initial_char(submodule[1:])

        if len(ns_prefixes) > 0:
            if debug_submodules: print("len(pfxs) > 0")
            if len(ns_prefixes) == 1:
                if debug_submodules:
                    print("single ns_prefix: %s" % ns_prefixes)
                    print("submodule: %s" % submodule)
                ## this is the top-level nslib - do not use fs_prefix
                if submodule == ns_prefixes[0]:
                    if debug_submodules:
                        print("submod == ns pfx[0]")
                    # if subnames_ct == 1:
                    #     # print("SUBMODULE %s" % submodule)
                    #     # print("SUBMOD_LABEL %s" % submod_label)
                    #     fail("Disallowed: ns of one submodule whose name matches ns name ({n}). Use ocaml_module with ocaml_library or ocaml_archive; or change  the name of either the ns or the submodule.".format(n=submodule))
                    no_main_alias = True
                    submod_is_main = True
                    # if debug_submodules:
                    #     print("submodule == ns_prefixes[0]: %s" % submodule)

                    # # ctx.attr.manifest can only be explicitly set
                    # # in bottom-up ns using ocaml_ns_resolver target
                    if ctx.attr.manifest or ctx.attr.merge:
                        user_ns_resolver = submod_label
                    # if debug_submodules:
                    #     print("USER_NS_RESOLVER: %s" % user_ns_resolver)
                    # continue ## no alias for main module
                else:
                    if debug_submodules:
                        print("submodule != ns_prefixes[0]: %s" % submodule)
            elif submodule == ns_prefixes[-1]: # last pfx
                # this is main nslib module
                no_main_alias = True
                submod_is_main = True
                if ctx.attr.manifest:
                    user_ns_resolver = submod_label
                continue ## no alias for main module
        ## else len(pfxs) !> 0

        # print("submodule pre: %s" % submodule)
        submodule = capitalize_initial_char(submodule)
        if debug_submodules: print("submodule uc: %s" % submodule)
        # if attr.module:
        #     if debug_submodules: print("module attrib: %s" % attr.module)

        if not submod_is_main:
            alias = "module {mod} = {ns}{sep}{mod}".format(
                mod = submodule,
                sep = "" if nslib_submod else module_sep, # fs_prefix != "" else module_sep,
                ns  = "" if nslib_submod else alias_prefix
            )
            if debug_submodules: print("appending alias: %s" % alias)
            aliases.append(alias)

    if debug_submodules: print("finished iterating submodules")

    if debug_includes: print("iterating includes")
    ## include specific exogenous (sub)modules, namespaced or not
    for k,v in ctx.attr.include.items():
        ## WARNING: check for namespacing first
        if OcamlNsSubmoduleMarker in k:
            resolver = k[OcamlNsSubmoduleMarker]
            if debug_includes:
                print("FUSE namespaced module, ns: %s" % resolver.ns_name)
            alias = "module {alias} = {ns}{sep}{mod}".format(
                alias = v,
                sep = "__", # if nslib_submod else module_sep,
                ns  = resolver.ns_name,
                mod = k.label.name
            )
            aliases.append(alias)
        elif OcamlModuleMarker in k:
            if debug_includes:
                print("FUSE non-namespaced module: {} -> {}".format(v, k))
            alias = "module {alias} = {mod}".format(
                alias = v,
                mod = normalize_module_name(k.label.name)
            )
            aliases.append(alias)
    if debug_includes: print("finished iterating includes")

    if debug_embeds: print("iterating embeds")
    # embed exogenous namespace (not its submodules)
    for k,v in ctx.attr.embed.items():
        if debug_embeds:
            print("EMBED: {} -> {}".format(v, k))
        if  OcamlNsResolverProvider in k:
            resolver = k[OcamlNsResolverProvider]
            if debug_embeds:
                print("EMBED NS: %s" % resolver.ns_name)
            alias = "module {alias} = {mod}".format(
                alias = v,
                ## FIXME: derive module name from label name
                mod = resolver.ns_name
            )
            aliases.append(alias)
    if debug_embeds: print("finished iterating embeds")

    if debug_merges: print("iterating merges")
    # import ALL submodules from exogenous namespaces
    for f in ctx.attr.merge:
        if debug_merges: print("IMPORT: {}".format(f))
        if  OcamlNsResolverProvider in f:
            resolver = f[OcamlNsResolverProvider]
            if debug_merges: print("IMPORT ns: %s" % resolver.ns_name)
            for submod in resolver.submodules:
                alias = "module {alias} = {ns}{sep}{mod}".format(
                    alias = submod,
                    ns  = resolver.ns_name,
                    sep = "__", # if nslib_submod else module_sep,
                    mod = submod
                )
                aliases.append(alias)
            # FIXME: what if merged ns has merges?
    if debug_merges: print("finished iterating merges")

    ## We've iterated over submodules, includes, embeds, merges giving
    ## us aliases list.

    ## Now we derive the ns module name itself. If manifest does NOT
    ## contain a module with same name as ns name, then the resolver
    ## name must be ns module name; otherwise, ns name with suffix '__'.

    ns_name = module_sep.join(ns_prefixes)
    if debug: print("ns_name: %s" % ns_name)
    if debug: print("aliases: %s" % aliases)

    if ns_name == "":
        print("WTF?")
        fail("xxxxxxxxxxxxxxxx")

    ################################################################
    ## user-provided resolver
    if user_ns_resolver:
        if debug_ns:
            print("User-provided resolver for ns: %s" % ns_name)
            print(" resolver: %s" % user_ns_resolver)
            fail("uda")

        defaultInfo = DefaultInfo()
        #     files = depset(
        #         order  = dsorder,
        #         # direct = default_outputs # action_outputs
        #         direct = user_ns_resolver
        #     )
        # )

        # nsResolverProvider = OcamlNsResolverProvider(
        #     # resolver_file = resolver_src_file,
        #     # subnames = subnames,
        #     # resolver = resolver_module_name,
        #     # prefixes   = ns_prefixes,
        #     ns_name    = ns_name
        # )

        # ocamlProvider = OcamlProvider(
        #     inputs    = depset(
        #         order = dsorder,
        #         transitive = user_ns_resolver
        #     ),
        #     paths     = depset(direct = [out_cmi.dirname]),
        # )

        return [DefaultInfo(),
                # ocamlProvider,
                OcamlNsResolverProvider(ns_name = ns_name)]
        # resolver_module_name = ns_name + resolver_suffix

    ################################################################
    else:
        if no_main_alias:
            resolver_module_name = ns_name + "__"
        else:
            resolver_module_name = ns_name

    # Always generate a resolver, even if no aliases
    # (in case user provides one, or its a singleton with module name matching ns name; ns has '__' suffix
    # if len(aliases) < 1:
    #     if debug_ns:
    #         print("NO ALIASES NO ALIASES NO ALIASES")
    #     return [DefaultInfo(),
    #             OcamlProvider(),
    #             OcamlNsResolverProvider(ns_name = ns_name)]
    #     # debug=True
    #     # print("LBL: %s" % ctx.label)
    #     if user_ns_resolver:
    #         print("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
    #     #     return [DefaultInfo(),
    #     #             OcamlProvider(),
    #     #             OcamlNsResolverProvider(
    #     #                 ns_name = ns_name,
    #     #                 module_name = user_ns_resolver
    #     #             )]
    #     else:
    #     #     if debug: print("NO ALIASES: %s" % ctx.label)
    #         print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA %s" % ns_name)
    #     #     print("user_ns_resolver: %s" % user_ns_resolver)
    #         return [DefaultInfo(),
    #                 OcamlProvider(),
    #                 OcamlNsResolverProvider(ns_name = ns_name)]

    resolver_src_filename = resolver_module_name + ".ml"
    resolver_src_file = ctx.actions.declare_file(workdir + resolver_src_filename)

    if debug:
        print("resolver_module_name: %s" % resolver_module_name)
    ## action: generate ns resolver module file with alias content
    ##################
    ctx.actions.write(
        output = resolver_src_file,
        content = "\n".join(aliases) + "\n"
    )
    ##################

    ## then compile it:

    out_cmi_fname = resolver_module_name + ".cmi"
    out_cmi = ctx.actions.declare_file(workdir + out_cmi_fname)
    action_outputs.append(out_cmi)

    out_ofile = None
    if tc.target == "vm":
        out_struct_fname = resolver_module_name + ".cmo"
    else:
        out_ofile_fname = resolver_module_name + ".o"
        out_ofile = ctx.actions.declare_file(workdir + out_ofile_fname)
        action_outputs.append(out_ofile)
        default_outputs.append(out_ofile)
        # rule_outputs.append(out_ofile)
        out_struct_fname = resolver_module_name + ".cmx"

    out_struct = ctx.actions.declare_file(workdir + out_struct_fname)
    action_outputs.append(out_struct)
    # default_outputs.append(out_struct)
    default_outputs.extend([out_cmi, out_struct])
    # rule_outputs.append(out_struct)

    ################################
    args = ctx.actions.args()

    _options = get_options(ctx.attr._rule, ctx)
    args.add_all(_options)

    if ctx.attr._warnings:
        args.add_all(ctx.attr._warnings[BuildSettingInfo].value, before_each="-w", uniquify=True)

    args.add("-I", resolver_src_file.dirname)
    action_inputs = []
    merge_depsets = []

    ## FIXME: handle cdeps v. ldeps
    for tgt in ctx.attr.merge:
        if debug: print("MERGE: %s" % tgt)
        merge_depsets.append(tgt.files)
    for tgt in ctx.attr.include:
        if debug: print("INCLUDE: %s" % tgt)
        merge_depsets.append(tgt.files)

    action_inputs.append(resolver_src_file)
    if debug: print("action_inputs: %s" % action_inputs)

    ## -no-alias-deps is REQUIRED for ns modules;
    ## see https://caml.inria.fr/pub/docs/manual-ocaml/modulealias.html
    args.add("-no-alias-deps")

    args.add("-c")

    args.add("-o", out_struct)

    args.add("-impl")
    args.add(resolver_src_file.path)

    action_inputs_depset = depset(
        direct = action_inputs,
        transitive = merge_depsets
    )

    ctx.actions.run(
        # env = env,
        executable = tc.compiler,
        arguments = [args],
        inputs = action_inputs_depset,
        outputs = action_outputs,
        tools = [tc.compiler],
        mnemonic = "CompileOCamlNsResolver",
        progress_message = "{mode} compiling ns resolver: {impl}".format(
            # to {ws}//{pkg}:{tgt}".format(
            mode = tc.host + ">" + tc.target,
            impl = resolver_src_file.basename,
            # rule=ctx.attr._rule,
            # ws  = "@" + ctx.label.workspace_name if ctx.label.workspace_name else "", ## ctx.workspace_name,
            # pkg = ctx.label.package,
            # tgt=ctx.label.name,
        )
    )

    ################################################################
    ## construct Providers
    ########################

    defaultInfo = DefaultInfo(
        files = depset(
            order  = dsorder,
            direct = [out_struct],
            #default_outputs.extend([out_cmi, out_struct])
            # direct = default_outputs # action_outputs
        )
    )

    nsResolverProvider = OcamlNsResolverProvider(
        # provide src for output group, for easy reference
        resolver_src = resolver_src_file,
        submodules   = subnames,
        module_name  = resolver_module_name,
        prefixes     = ns_prefixes,
        ns_name      = ns_name,
        cmi          = out_cmi,
        struct       = out_struct,
        ofile        = out_ofile if out_ofile else None
    )

    # new_cdeps_depset = depset(
    #     order = dsorder,
    #     direct = # [action_inputs_depset]
    #     action_outputs
    #     # + ns_resolver_files
    #     # + ctx.files.deps_runtime,
    #     # transitive = # cdeps_depsets
    #     # indirect_ppx_codep_depsets
    #     # + ns_deps
    #     # + bottomup_ns_inputs
    # )

    # new_ldeps_depset = depset(
    #     order = dsorder,
    #     direct = #[action_inputs_depset]
    #     action_outputs
    #     # + ns_resolver_files
    #     # + ctx.files.deps_runtime,
    #     # transitive = # ldeps_depsets ## cdeps_depsets
    #     # indirect_ppx_codep_depsets
    #     # + ns_deps
    #     # + bottomup_ns_inputs
    # )

    # linkset    = depset(direct = [out_struct])

    # fileset_depset = depset(direct=action_outputs)

    # closure_depset = depset(
    #     direct = action_outputs
    # )

    sigs_depset     = depset(order=dsorder,
                             direct=[out_cmi], # sigs_primary,
                             transitive=sigs_secondary)
    structs_depset  = depset(order=dsorder,
                            direct=[out_struct],  ## structs_primary,
                            transitive=structs_secondary)
    astructs_depset = depset(order=dsorder,
                             # direct=[out_struct],  ## structs_primary,
                             # direct=astructs_primary,
                             transitive=astructs_secondary)
    ofiles_depset  = depset(order=dsorder,
                            direct=[out_ofile] if out_ofile else [],
                            transitive=ofiles_secondary)

    cli_link_deps_depset = depset()

    # if ctx.attr._rule.endswith("archive"):
    #     cli_link_deps_depset = depset()
    # else:
    #     cli_link_deps_depset = depset(order = dsorder,
    #                                   direct = [out_struct]
    #                                   # direct = ns resolver,
    #                                   # transitive = depsets.deps.cli_link_deps
    #                                   )

    moduleInfo = OCamlModuleInfo(
        name = resolver_module_name,
        label_name = ctx.label.name,
        # namespaced = ns_enabled, # FIXME: a resolver could be namespaced
        sig  = out_cmi,
        # sig_src = #FIXME
        # cmti = #FIXME
        struct = out_struct,
        struct_src = resolver_src_file,
        structfile = resolver_src_filename,
        ofile = out_ofile if out_ofile else None,
        # cmt = #FIXME
        # files = #FIXME
    )

    ocamlProvider = OcamlProvider(
        # cmi      = depset(direct = [out_cmi]),
        cmi      = out_cmi,
        # fileset  = fileset_depset,
        # linkargs = linkset,
        # cdeps    = new_cdeps_depset,
        # ldeps    = new_ldeps_depset,
        # inputs   = closure_depset, ## action_inputs_depset,

        sigs     = sigs_depset,
        structs  = structs_depset,
        ofiles   = ofiles_depset,
        archives   = depset(order=dsorder,
                          direct=archives_primary,
                          transitive=archives_secondary),
        afiles   = depset(order=dsorder,
                           direct=afiles_primary,
                           transitive=afiles_secondary),
        astructs = astructs_depset,
        # cclibs   = depset(order=dsorder,
        #                    direct=cclibs_primary,
        #                    transitive=cclibs_secondary),

        paths    = depset(direct = [out_cmi.dirname]),

        cli_link_deps = cli_link_deps_depset
    )

    outputGroupInfo = OutputGroupInfo(
        cmi        = depset(direct=[out_cmi]),
        # fileset    = fileset_depset,
        # linkset    = linkset,
        inputs = action_inputs_depset,
        # all = depset(
        #     order = dsorder,
        #     transitive=[
        #         default_depset,
        #         ocamlProvider_files_depset,
        #         ppx_codeps_depset,
        #         # depset(action_inputs_ccdep_filelist)
        #     ]
        # )
    )

    if debug: print("resolver OcamlProvider: %s" % ocamlProvider)
    if debug: print("resolver nsrp: %s" % nsResolverProvider)

    return [
        defaultInfo,
        nsResolverProvider,
        OcamlModuleMarker(marker="OcamlModule"),
        moduleInfo,
        ocamlProvider,
        outputGroupInfo
    ]
