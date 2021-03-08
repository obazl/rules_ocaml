load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlModuleProvider",
     "OcamlNsResolverProvider",
     "OcamlNsArchiveProvider",
     "OcamlNsLibraryProvider",
     "OcamlSignatureProvider",
     "OpamDepsProvider",
     "PpxModuleProvider",
     "PpxNsLibraryProvider")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
)

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_common.bzl",
     "merge_deps",
     "tmpdir")

###########################
def get_module_name(f):
    "Derive module name from file name"

    basename = capitalize_initial_char(f.basename)
    ext = f.extension
    mname = basename[:-(len(ext)+1)]

    return mname

###########################
# def get_prefix(ctx):
#     print("LABEL: %s" % ctx.label)
#     print("WS: %s" % ctx.label.workspace_name)
#     # if ctx.workspace_name == "__main__": # default, if not explicitly named
#     #     ws = "Main"
#     # else:
#     #     # ws = ctx.workspace_name
#     #     # print("WS: %s" % ws)
#     ws = ctx.label.workspace_name
#     ws = capitalize_initial_char(ws)

#     ns_sep = "_" ## ctx.attr.sep
#     pathsegs = [x.replace("-", "_").capitalize() for x in ctx.label.package.split('/')]
#     ns_prefix = ws + ns_sep + ns_sep.join(pathsegs)

#     return ns_prefix

###########################
# def get_resolver_name(ctx):

#     ns_sep = "_" ## ctx.attr.sep

#     if ctx.attr._ns_resolver:
#         ns_prefix = ctx.attr._ns_resolver[OcamlNsResolverProvider].prefix
#         ns_main   = ctx.label.name
#         resolver_name = ns_prefix + "__" + capitalize_initial_char(ns_main)
#     else:
#         if ctx.workspace_name == "__main__": # default, if not explicitly named
#             ws = "Main"
#         else:
#             ws = ctx.workspace_name
#             # print("WS: %s" % ws)
#         ws = capitalize_initial_char(ws)
#         pathsegs = [x.replace("-", "_").capitalize() for x in ctx.label.package.split('/')]
#         ns_prefix = ws + ns_sep + ns_sep.join(pathsegs)
#         # ns_prefix = ws + "_" + ctx.label.package.replace("/", "_").replace("-", "_")
#         ns_main   = ctx.label.name
#         resolver_name = ns_prefix + "__" + capitalize_initial_char(ns_main)

#     return resolver_name

########################
def build_resolvers(ctx, tc, env, mode): #, aliases):
    ## return the pkg-level resolver(s)
    ## the submodules list may contain submodules from different packages.
    ## we need to go through them all and deliver their pkg resolvers for output
    ## but some submodules may be ns modules - ???
    resolver_files = []
    indirect_resolver_depsets = []
    # for [target, sm_name] in ctx.attr.submodules.items():
    for target in ctx.attr.submodules:
        indirect_resolver_depsets.append(target[DefaultMemo].resolvers)
        # if OcamlModuleProvider in target:
        #     indirect_resolver_depsets.append(target[OcamlModuleProvider].resolvers)
        # elif OcamlSignatureProvider in target:
        #     indirect_resolver_depsets.append(target[OcamlSignatureProvider].resolvers)
        # elif OcamlNsLibraryProvider in target:
        #     indirect_resolver_depsets.append(target[OcamlNsLibraryProvider].resolvers)
        # else:
        #     fail("oops?")

        for dep in target.files.to_list():
            resolver_files.append(dep)

    return [indirect_resolver_depsets, resolver_files]

#################
def impl_ns_library(ctx):

    debug = False
    # if ctx.label.name in ["logproc_lib"]:
    #     debug = True

    if debug:
        print("")
        print("Start: IMPL_NS_LIBRARY: %s" % ctx.label)

    ## FIXME: call impl_library ???

    # print("NS LIB rule: %s" % ctx.label.name)

    # if (ctx.attr.include and ctx.attr.main):
    #     fail("Attributes 'include' and 'main' are mutually exclusive.")

    # name must be legal OCaml module name
    if not ctx.label.name.lstrip("_")[0].isalpha():
        fail("Name must be a legal OCaml module name: %s" % ctx.label.name)

    # if ctx.files.main:
    #     if OcamlModuleProvider not in ctx.attr.main:
    #     #     print("MAIN MODULE: %s" % ctx.attr.main)
    #     # else:
    #         # print("MAIN FILES: %s" % len(ctx.files.main))
    #         if len(ctx.files.main) > 1:
    #             fail("Only one file allow in 'main' attribute.")

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    aliases = []

    ################
    direct_file_deps = []
    indirect_file_depsets  = []

    indirect_opam_depsets  = []

    indirect_adjunct_depsets = []  # list of depsets gathered from direct deps
    indirect_adjunct_path_depsets = [] # paths for indirect_adjunct deps
    indirect_adjunct_opam_depsets  = []  # list of depsets gathered from direct deps

    indirect_path_depsets  = []

    direct_resolver = None
    indirect_resolver_depsets = []

    direct_cc_deps  = {}
    indirect_cc_deps  = {}
    ################

    resolver_files = None

    submodules = []
    includes   = []

    # if ctx.attr.ns_resolver:
    #     direct_resolver = get_resolver_name(ctx)
    #     # print("DIRECT_RESOLVER: %s" % direct_resolver)
    #     ns_library_name = direct_resolver #  + "__" + ctx.label.name.replace("-", "_")
    # else:
    #     if ctx.attr.main:
    #         # ns_library_name = ctx.file.main.basename.replace("-", "_")[:3]
    #         ns_library_name = ctx.label.name.replace("-", "_")
    #     elif ctx.attr.includes:
    #         ns_library_name = ctx.label.name.replace("-", "_")
    #     else:
    #         ns_library_name = ctx.label.name.replace("-", "_")
    # print("NS_LIBRARY_NAME: %s" % ns_library_name)

    ## if no main, use ns module as resolver (generate it)
    ## otherwise, use main as ns module, and the resolver is computed from package name


    # ns_filename = tmpdir + ns_library_name + ".ml"
    # ns_file = None

    ## make aliases, one per submodule regardless of pkg
    ## the aliasing equations for this ns module may resolve to any pkg
    ## We may use main ns or submodules from other pkgs, but we do not use their resolvers.
    ## one reason for this is that there is no requirement that modules names match file names.
    ## so the same submodule could go under different submodule names in different packages.
    ## or even in different main ns modules in the same pkg.
    ## So: we always need to generate a resolver for the current package.

    ## Alternatively: module filenames are independent of aliasing
    ## equations. So to construct a resolver all we need is the
    ## filename, not the local resolver. In fact a given module may be
    ## resolved by multiple resolvers local to its own pkg (e.g. if
    ## the ns_librarys use different 'prefix' values.)

    ## In short: deriving alias equations from submodule items will always work.

    # mydeps = ctx.attr.submodules.keys()
    mydeps = ctx.attr.submodules + ctx.attr.sublibs
    merge_deps(mydeps,
               indirect_file_depsets,
               indirect_path_depsets,
               indirect_resolver_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    # if debug:
    #     print("OcamlNsResolverProvider: %s" % ctx.attr._ns_resolver[0][OcamlNsResolverProvider])

    # if hasattr(ctx.attr._ns_resolver[0][OcamlNsResolverProvider], "files"):
    #     indirect_file_depsets.append(ctx.attr._ns_resolver[0][OcamlNsResolverProvider].files)

    mode = ctx.attr._mode[CompilationModeSettingProvider].value
    # print("NS LIB MODE %s" % mode)

    ## we always want the resolvers of submodules?
    [indirect_resolver_depsets, resolver_files] = build_resolvers(
        ctx, tc, env, mode  # , aliases
    )

    if ctx.files.main:
        ## FIXME: verify that main module is also listed in submodules
        if debug:
            print("DIRECT_FILE_DEPS: %s" % direct_file_deps)
            print("INDIRECT_FILE_DEPS: %s" % indirect_file_depsets)
            print("MAIN: %s" % ctx.files.main)
        # dd = [ctx.files.main] + direct_file_deps
        inputs_depset = depset(
            order = "postorder",
            direct = ctx.files.main,
            transitive = indirect_file_depsets
        )
    else:
        inputs_depset = depset(
            order = "postorder",
            # direct = ctx.files.main,
            transitive = indirect_file_depsets
        )

    if debug:
        print("INPUTS_DEPSET: %s" % inputs_depset)

    ctx.actions.do_nothing(
        mnemonic = "NS_LIB",
        inputs = inputs_depset
    )

    # ctx.actions.run(
    #     env = env,
    #     executable = tc.ocamlfind,
    #     arguments = [args],
    #     inputs = depset(direct = direct_file_deps, transitive = indirect_file_depsets),
    #     outputs = outputs,
    #     tools = [tc.ocamlfind, tc.ocamlopt],
    #     mnemonic = mnemonic,
    #     progress_message = "{mode} compiling: @{ws}//{pkg}:{tgt} (rule {rule})".format(
    #         mode = mode,
    #         ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
    #         pkg = ctx.label.package,
    #         rule=ctx.attr._rule,
    #         tgt=ctx.label.name,
    #     )
    # )

    defaultInfo = DefaultInfo(
        files = depset(
            order = "postorder",
            # direct = [inputs_depset],
            transitive = [inputs_depset] + indirect_file_depsets
            # transitive = [mydeps.nopam] # , mydeps.opam]
            # depset(order="postorder", direct = indirects)]
        )
    )

    # search_paths = sets.to_list(sets.make(includes))
    # search_paths.append(obj_cm_.dirname)

    defaultMemo = DefaultMemo(
        # paths  = depset(direct = search_paths, transitive=indirect_path_depsets),
        paths  = depset(transitive=indirect_path_depsets),
        resolvers = depset(transitive = indirect_resolver_depsets)
    )

    # resolvers = []
    # for dep in ctx.attr.submodules.keys():
    #     resolvers.append(dep[OcamlNsLibraryProvider].resolver

    nslibProvider = None

    if ctx.attr._rule == "ocaml_ns_library":
        ## ns resolver provider: aggregate of resolvers in depgraph
        nslibProvider = OcamlNsLibraryProvider(
            # name      = capitalize_initial_char(paths.split_extension(obj_cm_.basename)[0]),
            # resolvers = ... use DefaultMemo???
            # resolvers are passed up from ocaml_ns to ocaml_modules to ocaml_ns_lib to ocaml_executable
        )
    else:
        nslibProvider = PpxNsLibraryProvider(
            # name      = capitalize_initial_char(paths.split_extension(obj_cm_.basename)[0]),
            # module    = obj_cm_,
        )

    opam_depset = depset(transitive = indirect_opam_depsets)
    opamProvider = OpamDepsProvider(
        pkgs = opam_depset
    )

    cclibs = {}
    if len(indirect_cc_deps) > 0:
        cclibs.update(indirect_cc_deps)
    ccProvider = CcDepsProvider(
        ## WARNING: cc deps must be passed as a dictionary, not a file depset!!!
        libs = cclibs
    )

    return [
        defaultInfo,
        defaultMemo,
        nslibProvider,
        opamProvider,
        ccProvider
    ]

