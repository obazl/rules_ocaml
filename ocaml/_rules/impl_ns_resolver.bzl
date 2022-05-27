load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
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
     "normalize_module_label",
     "normalize_module_name")

load(":impl_common.bzl",
     "dsorder",
     "module_sep",
     "opam_lib_prefix",
     "resolver_suffix",
     "tmpdir"
     )

workdir = tmpdir

#################
def impl_ns_resolver(ctx, mode, tool, tool_args):

    debug = False
    # if ctx.label.name == "":
    #     debug = True

    if debug:
        print("")
        print("Start: IMPL_NS %s" % ctx.label.name)
        print("LABEL: %s" % ctx.label)
        print("_NS_PREFIXES: %s" % ctx.attr._ns_prefixes[BuildSettingInfo].value)
        print("_NS_SUBMODULES: %s" % ctx.attr._ns_submodules[BuildSettingInfo].value)


    ## RULE: do not allow mixing bottomup and topdown namespaces.
    # but what happens if a selected submodule also elects?

    if ctx.attr.submodules:
        ## verify not also topdown
        subnames = ctx.attr.submodules
        bottomup = True
    else:
        subnames = ctx.attr._ns_submodules[BuildSettingInfo].value
        bottomup = False

    if bottomup:
        if len(ctx.attr.submodules) < 1:
            if len(ctx.attr.include) < 1:
                if len(ctx.attr.embed) < 1:
                    if len(ctx.attr.merge) < 1:
                        if debug:
                            print("NO SUBMODULES/MODULES/MERGE")
                            print("label: %s" % ctx.label)
                        return [DefaultInfo(),
                                OcamlNsResolverProvider()]

    # env = {"PATH": get_sdkpath(ctx)}

    # tc = ctx.toolchains["@rules_ocaml//ocaml:toolchain"]

    # mode = ctx.attr._mode[CompilationModeSettingProvider].value

    # if mode == "native":
    #     exe = tc.ocamlopt.basename
    # else:
    #     exe = tc.ocamlc.basename

    ################
    default_outputs = [] ## .cmx only
    action_outputs = []  ## .cmx, .cmi, .o
    rule_outputs = [] # excludes .cmi

    out_cm_ = None
    out_cmi = None

    aliases = []

    if ctx.attr.ns:
        ns_prefixes = [ctx.attr.ns]
    else:
        # ns_prefixes = [ctx.label.name]
        ns_prefixes = ctx.attr._ns_prefixes[BuildSettingInfo].value

    # print("label: %s" % ctx.label)
    # print("ctx.attr.ns: %s" % ctx.attr.ns)
    # print("ctx.attr._ns_prefixes: %s" % ctx.attr._ns_prefixes[BuildSettingInfo].value)
    # print("NS_PREFIXES: %s" % ns_prefixes)

    user_ns_resolver = None

    for submod_label in subnames:  # e.g. [Color, Red, Green, Blue], where main = Color
        if debug: print("submod_label: %s" % submod_label)
        # NB: //a/b:c will be normalized to C
        submodule = normalize_module_label(submod_label)
        # print("submodule normed: %s" % submodule)
        # if ctx.attr._ns_strategy[BuildSettingInfo].value == "fs":
        #     ## NB: subnames may come from different pkgs
        #     fs_prefix = get_fs_prefix(submod_label)
        #     alias_prefix = fs_prefix
        # else:
        fs_prefix = ""
        alias_prefix = module_sep.join(ns_prefixes) ## ns_prefix
        # print("alias_prefix: %s" % alias_prefix)

        ## an ns can be used as a submodule of another ns
        nslib_submod = False
        # if submodule.startswith("#"):
        #     # this is an nslib submodule, do not prefix
        #     nslib_submod = True
        #     submodule = capitalize_initial_char(submodule[1:])

        if len(ns_prefixes) > 0:
            if len(ns_prefixes) == 1:
                if debug:
                    print("lbl: %s" % ctx.label)
                    print("one ns_prefixes: %s" % ns_prefixes)
                    print("submodule: %s" % submodule)
                ## this is the top-level nslib - do not use fs_prefix
                if submodule == ns_prefixes[0]:
                    if debug:
                        print("submodule == ns_prefixes[0]: %s" % submodule)
                    user_ns_resolver = submod_label
                    if debug:
                        print("user_ns_resolver: %s" % user_ns_resolver)
                    continue ## no alias for main module
                else:
                    if debug:
                        print("submodule != ns_prefixes[0]: %s" % submodule)
            elif submodule == ns_prefixes[-1]:
                # this is main nslib module
                user_ns_resolver = submod_label
                continue ## no alias for main module
        # print("submodule pre: %s" % submodule)
        submodule = capitalize_initial_char(submodule)
        # print("submodule uc: %s" % submodule)
        alias = "module {mod} = {ns}{sep}{mod}".format(
            mod = submodule,
            sep = "" if nslib_submod else module_sep, # fs_prefix != "" else module_sep,
            ns  = "" if nslib_submod else alias_prefix
        )
        aliases.append(alias)

    ## include specific exogenous (sub)modules, namespaced or not
    for k,v in ctx.attr.include.items():
        ## WARNING: check for namespacing first
        if OcamlNsSubmoduleMarker in k:
            resolver = k[OcamlNsSubmoduleMarker]
            if debug:
                print("FUSE namespaced module, ns: %s" % resolver.ns_name)
            alias = "module {alias} = {ns}{sep}{mod}".format(
                alias = v,
                sep = "__", # if nslib_submod else module_sep,
                ns  = resolver.ns_name,
                mod = k.label.name
            )
            aliases.append(alias)
        elif OcamlModuleMarker in k:
            if debug:
                print("FUSE non-namespaced module: {} -> {}".format(v, k))
            alias = "module {alias} = {mod}".format(
                alias = v,
                mod = normalize_module_name(k.label.name)
            )
            aliases.append(alias)

    # embed exogenous namespace (not its submodules)
    for k,v in ctx.attr.embed.items():
        if debug:
            print("EMBED: {} -> {}".format(v, k))
        if  OcamlNsResolverProvider in k:
            resolver = k[OcamlNsResolverProvider]
            if debug:
                print("EMBED NS: %s" % resolver.ns_name)
            alias = "module {alias} = {mod}".format(
                alias = v,
                ## FIXME: derive module name from label name
                mod = resolver.ns_name
            )
            aliases.append(alias)

    # import ALL submodules from exogenous namespaces
    for f in ctx.attr.merge:
        if debug: print("IMPORT: {}".format(f))
        if  OcamlNsResolverProvider in f:
            resolver = f[OcamlNsResolverProvider]
            if debug: print("IMPORT ns: %s" % resolver.ns_name)
            for submod in resolver.submodules:
                alias = "module {alias} = {ns}{sep}{mod}".format(
                    alias = submod,
                    ns  = resolver.ns_name,
                    sep = "__", # if nslib_submod else module_sep,
                    mod = submod
                )
                aliases.append(alias)

    if debug: print("aliases: %s" % aliases)

    ns_name = module_sep.join(ns_prefixes)

    ################################################################
    ## user-provided resolver
    if user_ns_resolver:
        if debug:
            print("User-provided resolver for ns: %s" % ns_name)
            print(" resolver: %s" % user_ns_resolver)

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
        resolver_module_name = ns_name

    # do not generate a resolver module unless we have at least one alias
    if len(aliases) < 1:
        # print("NO ALIASES: %s" % ctx.label)
        return [DefaultInfo(),
                OcamlNsResolverProvider(ns_name = ns_name)]

    resolver_src_filename = resolver_module_name + ".ml"
    resolver_src_file = ctx.actions.declare_file(workdir + resolver_src_filename)

    # print("resolver_module_name: %s" % resolver_module_name)
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

    if mode == "native":
        obj_o_fname = resolver_module_name + ".o"
        obj_o = ctx.actions.declare_file(workdir + obj_o_fname)
        action_outputs.append(obj_o)
        # rule_outputs.append(obj_o)
        out_cm__fname = resolver_module_name + ".cmx"
    else:
        out_cm__fname = resolver_module_name + ".cmo"

    out_cm_ = ctx.actions.declare_file(workdir + out_cm__fname)
    action_outputs.append(out_cm_)
    default_outputs.append(out_cm_)
    # rule_outputs.append(out_cm_)

    ################################
    args = ctx.actions.args()

    args.add_all(tool_args)

    _options = get_options(ctx.attr._rule, ctx)
    args.add_all(_options)

    if ctx.attr._warnings:
        args.add_all(ctx.attr._warnings[BuildSettingInfo].value, before_each="-w", uniquify=True)

    args.add("-I", resolver_src_file.dirname)
    action_inputs = []
    merge_depsets = []
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

    args.add("-o", out_cm_)

    args.add("-impl")
    args.add(resolver_src_file.path)

    inputs_depset = depset(
        direct = action_inputs,
        transitive = merge_depsets
    )

    # print("TOOL: %s" % tool)
    ctx.actions.run(
        # env = env,
        executable = tool,
        arguments = [args],
        inputs = inputs_depset,
        outputs = action_outputs,
        tools = [tool] + tool_args,
        mnemonic = "OcamlNsResolverAction" if ctx.attr._rule == "ocaml_ns" else "PpxNsResolverAction",
        progress_message = "{mode} compiling {rule}: {ws}//{pkg}:{tgt}".format(
            mode = mode,
            rule=ctx.attr._rule,
            ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
        )
    )

    defaultInfo = DefaultInfo(
        files = depset(
            order  = dsorder,
            direct = default_outputs # action_outputs
        )
    )

    nsResolverProvider = OcamlNsResolverProvider(
        # provide src for output group, for easy reference
        resolver_file = resolver_src_file,
        submodules = subnames,
        resolver = resolver_module_name,
        prefixes   = ns_prefixes,
        ns_name    = ns_name
    )

    linkset    = depset(direct = [out_cm_])

    fileset_depset = depset(direct=action_outputs)

    closure_depset = depset(
        direct = action_outputs
    )

    ocamlProvider = OcamlProvider(
        cmi      = depset(direct = [out_cmi]),
        fileset  = fileset_depset,
        linkargs = linkset,
        inputs   = closure_depset, ## inputs_depset,
        paths    = depset(direct = [out_cmi.dirname]),
    )

    outputGroupInfo = OutputGroupInfo(
        cmi        = depset(direct=[out_cmi]),
        fileset    = fileset_depset,
        # linkset    = linkset,
        inputs = inputs_depset,
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

    # print("resolver provider: %s" % ocamlProvider)

    return [
        defaultInfo,
        nsResolverProvider,
        ocamlProvider,
        outputGroupInfo
    ]
