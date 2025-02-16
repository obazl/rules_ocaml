load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("@rules_ocaml//build:providers.bzl",
     "OCamlModuleProvider",
     "OCamlNsResolverProvider",
     "OcamlNsSubmoduleMarker",
     "OCamlDepsProvider")

load("@rules_ocaml//lib:merge.bzl",
     "merge_deps",
     "aggregate_codeps",
     "DepsAggregator",
     "COMPILE", "LINK", "COMPILE_LINK")

load("//build/_lib:utils.bzl", "get_fs_prefix")

load("//build/_lib:utils.bzl",
     "get_options", "dsorder", "module_sep",
     "resolver_suffix", "tmpdir")

load("//build/_lib:module_naming.bzl",
     "label_to_module_name",
     "normalize_module_label",
     "normalize_module_name")

load("@rules_ocaml//lib:colors.bzl",
     "CCRED", "CCREDBG", "CCYEL", "CCGRN", "CCBLU", "CCBLUYEL", "CCMAG", "CCCYN", "CCRESET")

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

    depsets = DepsAggregator()

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
                OCamlDepsProvider(),
                OCamlNsResolverProvider(tag = "NULL")
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
                                OCamlDepsProvider(),
                                OCamlNsResolverProvider(ns_name = "FOO")]

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
        # submodule = capitalize_initial_char(submodule)
        submodule = submodule[:1].capitalize() + submodule[1:]

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

    if ctx.attr.include:
        if debug_includes: print("iterating includes")
        ## include specific exogenous (sub)modules, namespaced or not
        for k,v in ctx.attr.include.items():
            if debug_includes: print("k %s" % k)
            ## WARNING: check for namespacing first
            if OcamlNsSubmoduleMarker in k:
                if debug_includes: print("submodule")
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
            elif OCamlModuleProvider in k:
                if debug_includes: print("submodule")
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
        if  OCamlNsResolverProvider in k:
            resolver = k[OCamlNsResolverProvider]
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
        if  OCamlNsResolverProvider in f:
            resolver = f[OCamlNsResolverProvider]
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

    ##########################
    ## user-provided resolver
    if user_ns_resolver:
        if debug_ns:
            print("User-provided resolver for ns: %s" % ns_name)
            print(" resolver: %s" % user_ns_resolver)
            fail("udr")

        defaultInfo = DefaultInfo()
        return [DefaultInfo(),
                OCamlDepsProvider(),
                OCamlNsResolverProvider(ns_name = ns_name)]
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
    #             OCamlDepsProvider(),
    #             OCamlNsResolverProvider(ns_name = ns_name)]
    #     # debug=True
    #     # print("LBL: %s" % ctx.label)
    #     if user_ns_resolver:
    #         print("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
    #     #     return [DefaultInfo(),
    #     #             OCamlDepsProvider(),
    #     #             OCamlNsResolverProvider(
    #     #                 ns_name = ns_name,
    #     #                 module_name = user_ns_resolver
    #     #             )]
    #     else:
    #     #     if debug: print("NO ALIASES: %s" % ctx.label)
    #         print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA %s" % ns_name)
    #     #     print("user_ns_resolver: %s" % user_ns_resolver)
    #         return [DefaultInfo(),
    #                 OCamlDepsProvider(),
    #                 OCamlNsResolverProvider(ns_name = ns_name)]

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

    if "-bin-annot" in _options:
        f = resolver_module_name + ".cmt"
        out_cmt = ctx.actions.declare_file(f, sibling = out_struct)
        action_outputs.append(out_cmt)

    args.add("-I", resolver_src_file.dirname)
    action_inputs = []
    merge_depsets = []

    ## FIXME: handle cdeps v. ldeps
    for tgt in ctx.attr.merge:
        if debug: print("MERGE: %s" % tgt)
        merge_depsets.append(tgt.files)
    for tgt in ctx.attr.include:
        if debug_includes: print("INCLUDE: %s" % tgt)
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

    ## an ns resolver is just a module, but
    ## we provide OCamlNsResolverProvider
    ## instead of OCamlModuleProvider
    nsResolverProvider = OCamlNsResolverProvider(
        # provide src for output group, for easy reference
        resolver_src = resolver_src_file,
        submodules   = subnames,
        # WARNING: modname may differ from ns name,
        # e.g. nsname Foo, modname Foo__
        # FIXME: always use modname
        modname      = resolver_module_name,
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

    ## Question: a default ns_resolver will have no deps;
    ## but a user-defined ns resolver may have deps.
    ## in that case, do we need to merge deps?
    sigs_depset     = depset(order=dsorder,
                             direct=[out_cmi],
                             )
    structs_depset  = depset(order=dsorder,
                            direct=[out_struct],
                             )
    astructs_depset = depset(order=dsorder,
                             )
    ofiles_depset  = depset(order=dsorder,
                            direct=[out_ofile] if out_ofile else [],
                            )

    cli_link_deps_depset = depset(
        order=dsorder,
        direct=[out_struct],
        ## FIXME: merge deps, so:
        # transitive = depsets.deps.cli_link_deps
    )

    ## needed for cli_link_deps for executables?
    ocamlDepsProvider = OCamlDepsProvider(
        cmi      = out_cmi,
        sigs     = sigs_depset,
        structs  = structs_depset,
        ofiles   = ofiles_depset,
        archives   = depset(order=dsorder,
                            ),
        afiles   = depset(order=dsorder,
                          ),
        astructs = astructs_depset,
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
        #         ocamlDepsProvider_files_depset,
        #         ppx_codeps_depset,
        #         # depset(action_inputs_ccdep_filelist)
        #     ]
        # )
    )

    if debug: print("resolver OCamlDepsProvider: %s" % ocamlDepsProvider)
    if debug: print("resolver nsrp: %s" % nsResolverProvider)

    return [
        defaultInfo,
        nsResolverProvider,
        ocamlDepsProvider,
        outputGroupInfo
    ]
