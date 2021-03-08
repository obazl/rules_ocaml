load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
    "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlModuleProvider",
     "OcamlNsArchiveProvider",
     "OcamlSignatureProvider",
     "OpamDepsProvider",
     "PpxModuleProvider",
     "PpxNsArchiveProvider")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_projroot",
     "get_sdkpath",
)

load(":impl_ns_library.bzl", "impl_ns_library")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_common.bzl", "tmpdir")

#################
def impl_ns_archive(ctx):

    # print("NS LIB rule: %s" % ctx.label.name)
    debug = False
    # if (ctx.label.name == "stdune"):
    #     debug = True

    # mode = "bytecode" # default
    # if ctx.attr._rule == "ocaml_ns_archive":
    #     mode = ctx.attr._mode[CompilationModeSettingProvider].value
    # elif ctx.attr._rule == "ppx_ns_archive":
    mode = ctx.attr._mode[CompilationModeSettingProvider].value
    # print("NS ARCHIVE MODE %s" % mode)

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    ####  call impl_ns_library  ####
    [defaultInfo,
     defaultMemo,
     nslibProvider,
     opamProvider] = impl_ns_library(ctx)
    ####

    ################################################################
    ns_archive_name = ctx.label.name.replace("-", "_")
    ns_ext = ".cma" if mode == "bytecode" else ".cmxa"
    ns_archive_filename = tmpdir + ns_archive_name + ns_ext
    ns_archive_file = ctx.actions.declare_file(ns_archive_filename)

    #########################
    args = ctx.actions.args()

    if mode == "native":
        # print("NATIVE")
        args.add(tc.ocamlopt.basename)
    else:
        # print("BC")
        args.add(tc.ocamlc.basename)

    options = get_options(ctx.attr._rule, ctx)
    args.add_all(options)

    args.add_all(defaultMemo.paths, before_each="-I", uniquify = True)

    for dep in defaultInfo.files.to_list():
        if dep.extension not in ["cmi", "mli", "o"]:
            args.add(dep)

    args.add("-a")

    # print("NS ARCHIVE FILE: %s" % ns_archive_file)
    args.add("-o", ns_archive_file)

    if ctx.attr._rule == "ocaml_ns_archive":
        mnemonic = "OcamlNsArchive"
    elif ctx.attr._rule == "ppx_ns_archive":
        mnemonic = "PpxNsArchive"
    else:
        fail("Unexpected rule type for impl_ns_archive: %s" % ctx.attr_rule)

    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs = defaultInfo.files,
        outputs = [ns_archive_file],
        # tools = [tc.ocamlfind, tc.ocamlopt],
        mnemonic = mnemonic,
        progress_message = "{mode} compiling {rule}: @{ws}//{pkg}:{tgt}".format(
            mode = mode,
            rule = ctx.attr._rule,
            ws  = ctx.label.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
            # msg = "" if not ctx.attr.msg else ": " + ctx.attr.msg
        )
    )

    newDefaultInfo = DefaultInfo(
        files = depset(
            order  = "postorder",
            direct = [ns_archive_file],
            transitive = [defaultInfo.files]
        )
    )

    execroot = get_projroot(ctx)
    apath = execroot + "/" + ctx.workspace_name + "/" + ns_archive_file.dirname
    # print("APATH %s" % apath)

    newDefaultMemo = DefaultMemo(
        paths     = depset(direct = [apath], transitive = [defaultMemo.paths]),
        resolvers = depset()
        # resolvers = depset(direct = [direct_resolver] if direct_resolver else [],
        #                    transitive = [indirect_resolvers_depset]),
    )

    if ctx.attr._rule == "ocaml_ns_archive":
        nsArchiveProvider = OcamlNsArchiveProvider(
                name   = ns_archive_name,
                module = ns_archive_file
            )
    elif ctx.attr._rule == "ocaml_ns_library":
        nsArchiveProvider = OcamlNsArchiveProvider(
                name   = ns_archive_name,
                module = ns_archive_file
            )
    elif ctx.attr._rule == "ppx_ns_archive":
        nsArchiveProvider = PpxNsArchiveProvider(
                name   = ns_archive_name,
                module = ns_archive_file
            )
    elif ctx.attr._rule == "ppx_ns_library":
        nsArchiveProvider = PpxNsArchiveProvider(
                name   = ns_archive_name,
                module = ns_archive_file
            )
    else:
        fail("Unrecognized ctx.attr._rule: %s" % ctx.attr._rule)

    return [newDefaultInfo,
            newDefaultMemo,
            # nslibProvider,
            # opamProvider,
            nsArchiveProvider
            ]


