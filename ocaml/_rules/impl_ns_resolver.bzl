load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "CompilationModeSettingProvider",
     "OcamlNsResolverProvider")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "normalize_module_label",
     "get_fs_prefix",
     "get_opamroot",
     "get_sdkpath",
)

load(":impl_common.bzl",
     "dsorder")

module_sep = "__"

resolver_suffix = module_sep + "0Resolver"

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

    submodules = ctx.attr._ns_submodules[BuildSettingInfo].value
    if len(submodules) < 1:
        if debug:
            print("NO SUBMODULES")
        return [DefaultInfo(),
                OcamlNsResolverProvider()]

    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    ################
    action_outputs = []

    obj_cm_ = None
    obj_cmi = None

    aliases = []

    ns_prefixes = ctx.attr._ns_prefixes[BuildSettingInfo].value

    user_main = False

    for submod_label in submodules:  # e.g. [Color, Red, Green, Blue], where main = Color
        submodule = normalize_module_label(submod_label)
        # if ctx.attr._ns_strategy[BuildSettingInfo].value == "fs":
        #     ## NB: submodules may come from different pkgs
        #     fs_prefix = get_fs_prefix(submod_label)
        #     alias_prefix = fs_prefix
        # else:
        fs_prefix = ""
        alias_prefix = module_sep.join(ns_prefixes) ## ns_prefix

        ## an ns can be used as a submodule of another ns
        ## if so, do not prepend alias_prefix
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
        return [DefaultInfo(),
                OcamlNsResolverProvider()]

    if user_main:
        resolver_module_name = module_sep.join(ns_prefixes) + resolver_suffix
    else:
        resolver_module_name = module_sep.join(ns_prefixes)

    resolver_src_filename = resolver_module_name + ".ml"
    resolver_src_file = ctx.actions.declare_file(resolver_src_filename)

    ## action: generate ns resolver module file with alias content
    ##################
    ctx.actions.write(
        output = resolver_src_file,
        content = "\n".join(aliases) + "\n"
    )
    ##################

    ## then compile it:

    obj_cmi_fname = resolver_module_name + ".cmi"
    obj_cmi = ctx.actions.declare_file(obj_cmi_fname)
    action_outputs.append(obj_cmi)

    if mode == "native":
        obj_o_fname = resolver_module_name + ".o"
        obj_o = ctx.actions.declare_file(obj_o_fname)
        action_outputs.append(obj_o)
        obj_cm__fname = resolver_module_name + ".cmx"
    else:
        obj_cm__fname = resolver_module_name + ".cmo"

    obj_cm_ = ctx.actions.declare_file(obj_cm__fname)
    action_outputs.append(obj_cm_)

    ################################
    args = ctx.actions.args()

    if mode == "native":
        args.add(tc.ocamlopt.basename)
    else:
        args.add(tc.ocamlc.basename)

    if ctx.attr._warnings:
        args.add_all(ctx.attr._warnings[BuildSettingInfo].value, before_each="-w", uniquify=True)

    args.add("-I", resolver_src_file.dirname)
    action_inputs = []

    action_inputs.append(resolver_src_file)

    ## -no-alias-deps is REQUIRED for ns modules;
    ## see https://caml.inria.fr/pub/docs/manual-ocaml/modulealias.html
    args.add("-no-alias-deps")

    args.add("-c")

    args.add("-o", obj_cm_)

    args.add("-impl")
    args.add(resolver_src_file.path)

    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs = action_inputs,
        outputs = action_outputs,
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
            order  = dsorder,
            direct = action_outputs + [resolver_src_file] # [obj_cm_]
        )
    )

    nsResolverProvider = OcamlNsResolverProvider(
        # files    = depset(
        #     order = dsorder,
        #     direct = action_outputs,
        # ),
        # paths     = depset(direct = [obj_cmi.dirname]),
        submodules = submodules,
        resolver = resolver_module_name,
        prefixes   = ns_prefixes,
    )

    ocamlProvider = OcamlProvider(
        files    = depset(
            order = dsorder,
            direct = action_outputs + [resolver_src_file],
        ),
        paths     = depset(direct = [obj_cmi.dirname]),
    )

    return [
        defaultInfo,
        nsResolverProvider,
        ocamlProvider,
    ]
