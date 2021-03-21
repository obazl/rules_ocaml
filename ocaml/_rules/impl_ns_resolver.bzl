load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlNsResolverProvider")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "normalize_module_label",
     "get_fs_prefix",
     "get_opamroot",
     "get_sdkpath",
)

#################
def impl_ns_resolver(ctx):

    debug = False
    # if ctx.label.name == "":
    #     debug = True

    if debug:
        print("")
        print("Start: IMPL_NS %s" % ctx.label.name)
        print("LABEL: %s" % ctx.label)
        print("_NS_PREFIXES: %s" % ctx.attr._ns_prefixes[BuildSettingInfo].value)
        print("_NS_SUBMODULES: %s" % ctx.attr._ns_submodules[BuildSettingInfo].value)

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    outputs = []

    module_sep = "__"

    obj_cm_ = None
    obj_cmi = None

    aliases = []

    ns_prefixes = ctx.attr._ns_prefixes[BuildSettingInfo].value
    submodules = ctx.attr._ns_submodules[BuildSettingInfo].value

    if len(submodules) < 1:
        if debug:
            print("NO SUBMODULES")
        return [DefaultInfo(files = depset()),
                DefaultMemo(paths=depset(), files=depset()),
                OcamlNsResolverProvider(
                )]

    user_main = False

    for submod_label in submodules:  # e.g. [Color, Red, Green, Blue], where main = Color
        submodule = normalize_module_label(submod_label)
        if ctx.attr._ns_strategy[BuildSettingInfo].value == "fs":
            ## NB: submodules may come from different pkgs
            fs_prefix = get_fs_prefix(submod_label)
            alias_prefix = fs_prefix ##  + "__"
        else:
            fs_prefix = "" # ns_prefix + "__"
            alias_prefix = "__".join(ns_prefixes) ## ns_prefix

        nslib_submod = False
        if submodule.startswith("#"):
            # this is an nslib submodule, do not prefix
            nslib_submod = True
            submodule = capitalize_initial_char(submodule[1:])

        if len(ns_prefixes) > 0:
            if len(ns_prefixes) == 1:
                ## this is the top-level nslib - do not use fs_prefix
                if submodule == ns_prefixes[0]:
                    user_main = True
                    continue ## no alias for main module
            elif submodule == ns_prefixes[-1]:
                # this is main nslib module
                user_main = True
                continue ## no alias for main module

        submodule = capitalize_initial_char(submodule)

        alias = "module {mod} = {ns}{sep}{mod}".format(
            mod = submodule,
            sep = "" if nslib_submod else module_sep, # fs_prefix != "" else module_sep,
            ns  = "" if nslib_submod else alias_prefix
        )
        aliases.append(alias)

    # do not generate a resolver module unless we have at least one alias
    if len(aliases) < 1:
        return [DefaultInfo(files = depset()),
                DefaultMemo(paths=depset(), files=depset()),
                OcamlNsResolverProvider(
                )]

    if user_main:
        resolver_module_name = "__".join(ns_prefixes) + "__0Resolver"
    else:
        resolver_module_name = "__".join(ns_prefixes)

    ns_filename = resolver_module_name + ".ml"
    ns_file = ctx.actions.declare_file(ns_filename)

    ## action: generate ns resolver module file with alias content
    ##################
    ctx.actions.write(
        output = ns_file,
        content = "\n".join(aliases) + "\n"
    )
    ##################

    ## then compile it:

    obj_cmi_fname = resolver_module_name + ".cmi"
    obj_cmi = ctx.actions.declare_file(obj_cmi_fname)
    outputs.append(obj_cmi)

    if mode == "native":
        obj_o_fname = resolver_module_name + ".o"
        obj_o = ctx.actions.declare_file(obj_o_fname)
        outputs.append(obj_o)
        obj_cm__fname = resolver_module_name + ".cmx"
    else:
        obj_cm__fname = resolver_module_name + ".cmo"

    obj_cm_ = ctx.actions.declare_file(obj_cm__fname)
    outputs.append(obj_cm_)

    ################################
    args = ctx.actions.args()

    if mode == "native":
        args.add(tc.ocamlopt.basename)
    else:
        args.add(tc.ocamlc.basename)

    if ctx.attr._warnings:
        args.add_all(ctx.attr._warnings[BuildSettingInfo].value, before_each="-w", uniquify=True)

    args.add("-I", ns_file.dirname)
    dep_graph = []

    dep_graph.append(ns_file)

    ## -no-alias-deps is REQUIRED for ns modules;
    ## see https://caml.inria.fr/pub/docs/manual-ocaml/modulealias.html
    args.add("-no-alias-deps")

    args.add("-c")

    args.add("-o", obj_cm_)

    args.add("-impl")
    args.add(ns_file.path)

    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs = dep_graph,
        outputs = outputs,
        tools = [tc.ocamlfind, tc.ocamlopt],
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
            order  = "postorder",
            direct = [obj_cm_] # outputs
        )
    )

    defaultMemo = DefaultMemo(
        paths     = depset(direct = [obj_cmi.dirname]),
        files     = depset(direct = outputs)
                           # transitive = indirect_file_depsets + indirect_archive_depsets)
    )

    nsProvider = OcamlNsResolverProvider(
        files    = depset(
            order = "postorder",
            direct = outputs,
            transitive = [
                depset(order = "postorder", direct = [obj_cmi] if obj_cmi else [])
            ]
        ),
        submodules = submodules,
        resolver = resolver_module_name,
        prefixes   = ns_prefixes,
    )

    return [
        defaultInfo,
        defaultMemo,
        nsProvider
    ]
