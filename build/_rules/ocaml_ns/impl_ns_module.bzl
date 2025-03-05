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
def impl_ns_module(ctx):
    debug               = False
    debug_ns            = False
    debug_manifest      = False
    debug_import_as      = False
    debug_ns_import_as = False
    debug_ns_merge    = False

    if debug:
        print("{c}ocaml_ns_module: {lbl}{r}".format(
            c=CCBLUYEL, lbl=ctx.label, r=CCRESET))

    tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]

    bottomup = False

    ## RULE: do not allow mixing bottomup and topdown namespaces.
    # but what happens if a selected submodule also elects?

    ## NB: always use capitalization in module aliasing equations
    ## and in modname, but leave filename unchanged
    ## unless _normalize_modname is passed

    depsets = DepsAggregator()

    ns_modname = None
    ns_fs_stem = None

    nsrp = ctx.attr.ns_config[0][OCamlNsResolverProvider]

    ns_name = nsrp.modname
    ns_modname = nsrp.modname
    ns_prefix = ns_name[:1].capitalize() + ns_name[1:]
    ns_fqn = nsrp.ns_fqn

    ################
    default_outputs = [] ## .cmi, .cmo or .cmx, .o
    action_outputs = []  ## .cmx, .cmi, .o
    rule_outputs = [] # excludes .cmi

    out_struct = None
    out_cmi = None

    aliases = []

    if debug: print("ns_name: %s" % ns_name)

    action_inputs = []
    ns_deps = []

    resolver_src_file = nsrp.resolver_src

    ns_fs_stem = nsrp.stem
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
    import_as_list = nsrp.import_as
    ns_import_as_list = nsrp.ns_import_as
    ns_merge_list  = nsrp.ns_merge

    for tgt in nsrp.import_as.keys():
        if debug_import_as: print("IMPORT_AS: %s" % tgt)
        ns_deps.append(tgt.files)
    for tgt in nsrp.ns_import_as.keys():
        if debug_import_as: print("NS_IMPORT_AS: %s" % tgt)
        ns_deps.append(tgt.files)
    for tgt in nsrp.ns_merge:
        if debug: print("NS_MERGE: %s" % tgt)
        ns_deps.append(tgt.files)

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
        transitive = ns_deps
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
        resolver_src = nsrp.resolver_src,
        submodules   = nsrp.submodules,
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
        modname      = nsrp.modname,
        fs_prefix    = nsrp.fs_prefix,
        ns_fqn       = nsrp.ns_fqn,
        # prefixes     = ns_prefix,
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
