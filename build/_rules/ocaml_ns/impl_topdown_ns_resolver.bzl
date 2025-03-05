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
def impl_topdown_ns_resolver(ctx):

    debug            = False
    debug_ns         = False
    debug_submodules = False
    debug_includes   = False
    debug_ns_aliases = False
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

    ## MANIFESTS - ns-submodules
    ## OCaml has
    ##   include M - imports and exports all definitions of M
    ##   open M - imports but does not export

    ## We have:
    ##   manifest - list of direct ns-submodules in this ns
    ##   include - specific exogenous (sub)modules, ns’ed or not
    ##           - like OCaml include?
    ##   open - import ALL submodules from exogenous namespaces
    ##   ns_aliases - aliase exogenous namespaces to new ns

    bottomup = False

    ## RULE: do not allow mixing bottomup and topdown namespaces.
    # but what happens if a selected submodule also elects?

    ## NB: always use capitalization in module aliasing equations
    ## and in modname, but leave filename unchanged
    ## unless _normalize_modname is passed

    depsets = DepsAggregator()

    ## NAMING
    ## We have:
    ##   ns_resolver_name - name of the ns module (normalized)
    ##   ns_resolver_filename - unnormalized unless user asks
    ##   fs_prefix - filesystem prefixes, used by clients
    ##   ns_prefix - normalized fs_prefix, used for aliasing

    private = True
    if ctx.attr.visibility:
        if  ctx.attr.visibility == []:
            fail("visibility []")
        elif ctx.attr.visibility[0] == Label("//visibility:private"):
            private = True
        else:
            private = False
    else:
        ## no visibility attr, default to false
        private = False

    ns_modname = None
    ns_fs_stem = None
    if ctx.attr.ns:
        bottomup = True
        ns_modname = ctx.attr.ns[:1].capitalize() + ctx.attr.ns[1:]
        if private:
            ns_modname = ns_modname + "__"
            # resolver_filename = ns_fs_stem
            # fs_prefix = ns_fs_stem + "__"

        if ctx.attr._normalize_modname[BuildSettingInfo].value == True:
            ns_fs_stem = ns_modname
        else:
            if private:
                ns_fs_stem = ctx.attr.ns + "__"
            else:
                ns_fs_stem = ctx.attr.ns
        if debug: print("has ns attr: %s" % ns_modname)

        # if ctx.attr._normalize_modname[BuildSettingInfo].value == True:
        ns_prefixes = [ctx.attr.ns[:1].capitalize() + ctx.attr.ns[1:]]
        # else:
        #     ns_prefixes = [ctx.attr.ns]
        # ns_prefixes = [ctx.attr.ns]
    else: # no ctx.attr.nx
        bottomup = False
        # ns_prefixes = [ctx.label.name]
        ns_prefixes = ctx.attr._ns_prefixes[BuildSettingInfo].value
        if ns_prefixes == []:
            ns_fs_stem = None
        else:
            # ns_fs_stem = ns_prefixes[0]
            ns_fs_stem = module_sep.join(ns_prefixes)

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
                if len(ctx.attr.ns_aliases) < 1:
                    if len(ctx.attr.merge) < 1:
                        if debug:
                            print("NO SUBMODULES/MODULES/MERGE")
                            print("label: %s" % ctx.label)
                        return [DefaultInfo(),
                                OCamlDepsProvider(),
                                OCamlNsResolverProvider(ns_fqn = "FOO")]

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
        # NB: this is string to modname, not label
        submodule = label_to_module_name(submod_label)
        if debug_submodules: print("submodule normed: %s" % submodule)
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
                    print("XXXXXXXXXXXXXXXX")
                    user_ns_resolver = submod_label
                continue ## no alias for main module
        ## else len(pfxs) !> 0

        # print("submodule pre: %s" % submodule)
        # submodule = capitalize_initial_char(submodule)
        # if ctx.attr._normalize_modname[BuildSettingInfo].value == True:
        submodule = submodule[:1].capitalize() + submodule[1:]

        if debug_submodules: print("submodule uc: %s" % submodule)
        # if attr.module:
        #     if debug_submodules: print("module attrib: %s" % attr.module)

        if not submod_is_main:
            alias = "module {mod} = {ns}{sep}{mod}".format(
                mod = submodule,
                sep = "" if nslib_submod else "_" if alias_prefix.endswith("_") else module_sep,
                ns  = "" if nslib_submod else alias_prefix
            )
            if debug_submodules: print("appending alias: %s" % alias)
            aliases.append(alias)

    if debug_submodules: print("finished iterating submodules")

    action_inputs = []
    merge_depsets = []
    # ns_deps = []

    # if ctx.attr.ns_deps:
    #     for dep in ctx.attr.ns_deps:
    #         submodule = "Greek"
    #         alias = "module {mod} = {mod}".format(
    #             mod = submodule,
    #         )
    #         aliases.append(alias)
    #         ns_deps.append(dep[DefaultInfo].files)

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
                    print("FUSE namespaced module, ns: %s" % resolver.ns_fqn)
                alias = "module {alias} = {ns}{sep}{mod}".format(
                    alias = v,
                    sep = "_" if resolver.ns_fqn.endswith("_") else module_sep,
                    # sep = "__", # if nslib_submod else module_sep,
                    ns  = resolver.ns_fqn,
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

    if debug_ns_aliases: print("iterating ns_aliases")
    # ns_aliases exogenous namespace (not its submodules)
    for k,v in ctx.attr.ns_aliases.items():
        if debug_ns_aliases:
            print("NS_ALIASES: {} -> {}".format(v, k))
        if  OCamlNsResolverProvider in k:
            resolver = k[OCamlNsResolverProvider]
            if debug_ns_aliases:
                print("NS_ALIASES NS: %s" % resolver.ns_fqn)
            alias = "module {alias} = {mod}".format(
                alias = v,
                ## FIXME: derive module name from label name
                mod = resolver.ns_fqn
            )
            aliases.append(alias)
    if debug_ns_aliases: print("finished iterating ns_aliases")

    if debug_merges: print("iterating merges")
    # import ALL submodules from exogenous namespaces
    for f in ctx.attr.merge:
        if debug_merges: print("IMPORT: {}".format(f))
        if  OCamlNsResolverProvider in f:
            resolver = f[OCamlNsResolverProvider]
            if debug_merges: print("IMPORT ns: %s" % resolver.ns_fqn)
            for submod in resolver.submodules:
                alias = "module {alias} = {ns}{sep}{mod}".format(
                    alias = submod,
                    ns  = resolver.ns_fqn,
                    sep = "_" if resolver.ns_fqn.endswith("_") else module_sep,
                    # sep = "__", # if nslib_submod else module_sep,
                    mod = submod
                )
                aliases.append(alias)
            # FIXME: what if merged ns has merges?
    if debug_merges: print("finished iterating merges")

    ## We've iterated over submodules, includes, ns_aliases, merges giving
    ## us aliases list.

    ## NAMING
    ## fs_prefix: used to rename ns component modules, e.g. Foo__
    ## ns_modname: used as filename for resolver, e.g. Foo (.ml)
    ##     -- but may be same as fs_prefix, see ocaml-re example
    ## ns_fqn:  ???

    ## Now we derive the ns module name itself. If manifest does
    ## NOT contain a module with same name as ns name,
    ## then the resolver name must be ns module name;
    ## otherwise, ns name with suffix '__' (i.e. fs_prefix).

    ns_fqn = module_sep.join(ns_prefixes)
    ##########################
    ## user-provided resolver
    if user_ns_resolver:
        if debug_ns:
            print("User-provided resolver for ns: %s" % ns_fqn)
            print(" resolver: %s" % user_ns_resolver)
            # fail("udr")
        ns_modname = ns_modname + "__"
        resolver_filename = ns_fs_stem + "__"
        fs_prefix = ns_fs_stem + "__"

        # defaultInfo = DefaultInfo()
        # return [DefaultInfo(),
        #         OCamlDepsProvider(),
        #         OCamlNsResolverProvider(ns_fqn = ns_fqn)]
        # resolver_module_name = ns_fqn + resolver_suffix
    else:
        if ns_modname:
            # if no_main_alias:
            # ns_modname = ns_modname + "__"
            # resolver_filename = ns_fs_stem
            if private:
                fs_prefix = ns_fs_stem
            else:
                fs_prefix = ns_fs_stem + "__"
            # else:
            #     resolver_module_name = ns_modname + "__"
        else:
            if private:
                ns_modname = ns_fqn + "__"
            else:
                ns_modname = ns_fqn
            # resolver_module_name = ns_fqn # + "__"
            resolver_filename = ns_fs_stem # + "__"
            fs_prefix = ns_fs_stem + "__"

    # Always generate a resolver, even if no aliases
    # (in case user provides one, or its a singleton with module name matching ns name; ns has '__' suffix
    # if len(aliases) < 1:
    #     if debug_ns:
    #         print("NO ALIASES NO ALIASES NO ALIASES")
    #     return [DefaultInfo(),
    #             OCamlDepsProvider(),
    #             OCamlNsResolverProvider(ns_fqn = ns_fqn)]
    #     # debug=True
    #     # print("LBL: %s" % ctx.label)
    #     if user_ns_resolver:
    #         print("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
    #     #     return [DefaultInfo(),
    #     #             OCamlDepsProvider(),
    #     #             OCamlNsResolverProvider(
    #     #                 ns_fqn = ns_fqn,
    #     #                 module_name = user_ns_resolver
    #     #             )]
    #     else:
    #     #     if debug: print("NO ALIASES: %s" % ctx.label)
    #         print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA %s" % ns_fqn)
    #     #     print("user_ns_resolver: %s" % user_ns_resolver)
    #         return [DefaultInfo(),
    #                 OCamlDepsProvider(),
    #                 OCamlNsResolverProvider(ns_fqn = ns_fqn)]

    # resolver_src_filename = ns_fs_stem + ".ml"
    resolver_src_file = ctx.actions.declare_file(
        workdir + ns_fs_stem + ".ml") #resolver_src_filename)

    if debug:
        print("""

private:  {private}
visibility: '{viz}'
ns_modname: {modname}
ns_fqn: {fqn}
ns_fs_stem: {stem}
fs_prefix:  {fs_pfx}
ns_prefixes: {prefixes}
resolver_file: {rfn}
aliases: {aliases}
user_ns_resolver: {user}
        """.format(
            private = private,
            viz = ctx.attr.visibility,
            modname = ns_modname,
            fqn = ns_fqn,
            stem = ns_fs_stem,
            fs_pfx = fs_prefix,
            prefixes = ns_prefixes,
            rfn = resolver_src_file,
            aliases = aliases,
            user = user_ns_resolver))

    # if debug:
    #     print("resolver_module_name: %s" % resolver_module_name)
    ## action: generate ns resolver module file with alias content
    ##################
    ctx.actions.write(
        output = resolver_src_file,
        content = "\n".join(aliases) + "\n"
    )
    ##################

    ## then compile it:

    out_cmi_fname = ns_fs_stem + ".cmi"
    out_cmi = ctx.actions.declare_file(workdir + out_cmi_fname)
    action_outputs.append(out_cmi)

    out_ofile = None
    if tc.target == "vm":
        out_struct_fname = ns_fs_stem + ".cmo"
    else:
        out_ofile_fname = ns_fs_stem + ".o"
        out_ofile = ctx.actions.declare_file(workdir + out_ofile_fname)
        action_outputs.append(out_ofile)
        default_outputs.append(out_ofile)
        # rule_outputs.append(out_ofile)
        out_struct_fname = ns_fs_stem + ".cmx"

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
        f = ns_modname + ".cmt"
        out_cmt = ctx.actions.declare_file(f, sibling = out_struct)
        action_outputs.append(out_cmt)

    args.add("-I", resolver_src_file.dirname)

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
    default_depset = depset(
        order  = dsorder,
        direct = [out_struct],
        #default_outputs.extend([out_cmi, out_struct])
        # direct = default_outputs # action_outputs
    )

    defaultInfo = DefaultInfo(
        files = default_depset
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
        # i.e. modname matches filename stem
        # e.g. Foo.A - compiler looks for file matching
        # modname Foo, finds Foo.cmx
        # then looks for A alias, finds A => Foo__A
        # ns_fs_stem = ns_fs_stem + "__"
        # fs_prefix = ns_fs_stem + "__"
        # ns_fs_stem = ns_fs_stem + "__"
        # fs_prefix = ns_fs_stem + "__"
        modname      = ns_modname,
        fs_prefix    = fs_prefix,
        ns_fqn       = ns_fqn,
        prefixes     = ns_prefixes,
        cmi          = out_cmi,
        struct       = out_struct,
        ofile        = out_ofile if out_ofile else None
    )

    ## Question: a default ns_resolver will have no deps;
    ## but a user-defined ns resolver may have deps.
    ## in that case, do we need to merge deps?
    sigs_depset     = depset(order=dsorder,
                             direct=[out_cmi],
                             )
    structs_depset  = depset(order=dsorder,
                             direct=[out_struct],
                             # transitive = ns_deps
                             )
    astructs_depset = depset(order=dsorder,
                             )
    ofiles_depset  = depset(order=dsorder,
                            direct=[out_ofile] if out_ofile else [],
                            )
    cmxs_depset  = depset(order=dsorder,
                          )

    cmts_depset  = depset(order=dsorder,
                          #direct=[out_cmt]
                          )

    if len(depsets.deps.cmtis) == 0:
        cmtis_depset = []
    else:
        cmtis_depset  = depset(# order = dsorder,
            transitive = depsets.deps.cmtis)

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
        cmxs     = cmxs_depset,
        cmts     = cmts_depset,
        cmtis     = cmtis_depset,
        paths    = depset(direct = [out_cmi.dirname]),
        cli_link_deps = cli_link_deps_depset
    )

    all_depset = depset(
        direct=[
            out_struct, out_cmi
        ] + ([out_ofile] if out_ofile else [])
        + [resolver_src_file]
    )

    outputGroupInfo = OutputGroupInfo(
        cmi        = depset(direct=[out_cmi]),
        # fileset    = fileset_depset,
        # linkset    = linkset,
        inputs = action_inputs_depset,
        all = all_depset
    )

    if debug: print("OUT resolver OCamlDepsProvider: %s" % ocamlDepsProvider)
    if debug: print("OUT resolver nsrp: %s" % nsResolverProvider)

    return [
        defaultInfo,
        nsResolverProvider,
        ocamlDepsProvider,
        outputGroupInfo,
    ]
