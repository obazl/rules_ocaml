load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "AdjunctDepsProvider",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlArchiveProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsResolverProvider",
     "OcamlNsArchiveProvider",
     "OcamlNsLibraryProvider",
     "OcamlSDK",
     "OcamlSignatureProvider",
     "OpamDepsProvider",
     "PpxArchiveProvider",
     "PpxModuleProvider",
     "PpxNsLibraryProvider",
     "PpxExecutableProvider")

load("//ocaml/_rules/utils:rename.bzl",
     "get_module_name",
     "rename_module",
     "rename_srcfile")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_transitions:transitions.bzl",
    "ocaml_signature_deps_out_transition")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "file_to_lib_name",
     "get_fs_prefix",
     "get_opamroot",
     "get_sdkpath",
     "normalize_module_label",
)

load(":options.bzl",
     "options",
     "options_ns_opts",
     "options_ppx")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_common.bzl",
     "merge_deps",
     "tmpdir")

OCAML_INTF_FILETYPES = [
    ".mli", ".cmi"
]

########## RULE:  OCAML_SIGNATURE  ################
def _ocaml_signature_impl(ctx):

    debug = False
    # if ctx.label.name in ["_Base58_check.cmi"]:
    #     debug = True

    ns_submodules = []
    for lbl in ctx.attr._ns_submodules[BuildSettingInfo].value:
        submod = normalize_module_label(lbl)
        ns_submodules.append(submod)

    print("SIG SUBMODS: %s" % ns_submodules)
    ns_prefix     = ctx.attr._ns_prefix[BuildSettingInfo].value
    if ns_prefix in ns_submodules:
        ns_resolver = ns_prefix + "__0Resolver"
    else:
        ns_resolver = ns_prefix

    if debug:
        print("")
        if ctx.attr._rule == "ocaml_signature":
            print("Start: OCAMLSIG %s" % ctx.label)
        else:
            fail("Unexpected rule for 'ocaml_signature_impl': %s" % ctx.attr._rule)
        print("  ns_prefix: %s" % ns_prefix)
        print("  ns_submodules: %s" % ns_submodules)

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
    OCAMLFIND_IGNORE = ""
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/digestif"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/digestif/c"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml/compiler-libs"

    env = {
        "OPAMROOT": get_opamroot(),
        "PATH": get_sdkpath(ctx),
        "OCAMLFIND_IGNORE_DUPS_IN": OCAMLFIND_IGNORE
    }

    ################
    direct_file_deps = []
    indirect_file_depsets = [] # will be added to inputs and passed on as transitive outputs

    indirect_opam_depsets = []

    indirect_adjunct_depsets = []  # list of depsets gathered from direct deps
    indirect_adjunct_path_depsets = []  # list of depsets gathered from direct deps
    indirect_adjunct_opam_depsets  = []  # list of depsets gathered from direct deps

    indirect_path_depsets = []

    direct_resolver = None
    indirect_resolver_depsets = []

    direct_cc_deps  = {}
    indirect_cc_deps  = {}
    ################

    dep_graph = []

    sigfile = None
    opam_deps = []
    nopam_deps = []

    build_deps = []
    dso_deps = []
    includes   = []

    if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "files"):
        ns_files_depset = ctx.attr._ns_resolver[OcamlNsResolverProvider].files
    else:
        ns_files_depset = depset()

    (from_name, module_name) = get_module_name(ctx, ctx.file.src)
    print("GOT FROM NAME: %s" % from_name)
    print("GOT MODULE NAME: %s" % module_name)

    if ctx.attr.ppx:
        ## this will also handle ns
        sigfile = impl_ppx_transform("ocaml_signature", ctx, ctx.file.src)
        direct_file_deps.append(ctx.file.ppx)
        # (tmpdir, sigfile) = impl_ppx_transform("ocaml_signature", ctx, ctx.file.src)
    # elif ctx.attr.ns_resolver:
    #     sigfile = rename_module(ctx, ctx.file.src) #, ctx.attr.ns_resolver)

    elif module_name != from_name:
        sigfile = rename_srcfile(ctx, ctx.file.src, module_name + ".mli")
    else:
        sigfile = ctx.file.struct

    # elif len(ns_submodules) > 0:
    #     (this_module, ext) = paths.split_extension(ctx.file.src.basename)
    #     this_module = capitalize_initial_char(this_module)
    #     if debug:
    #         print("THIS_MODULE: %s" % this_module)
    #         print("SUBMODULES:  %s" % ns_submodules)
    #     if this_module in ns_submodules:
    #         # rename this module to put it in the namespace
    #         # sigfile = rename_module(ctx, ctx.file.src) #, ctx.attr._ns_resolver)
    #         fs_prefix = get_fs_prefix(str(ctx.label))
    #         sigfile = rename_submodule(ctx, fs_prefix, ctx.file.src)
    #     else:
    #         sigfile = ctx.file.src
    # else:
    # #     if ctx.attr.module:
    # #         sigfile = rename_module(ctx, ctx.file.src) #, ctx.attr.ns_resolver)
    #     sigfile = ctx.file.src

    if debug:
        print("SOURCE SIGFILE: %s" % sigfile)

    scope = ""  ## replaces tmpdir, in case we want to support 'pkg'

    # cmifname = ctx.file.src.basename.rstrip("mli") + "cmi"
    if debug:
        print("SIGFILE: %s" % sigfile)
    cmifname = sigfile.basename.rstrip("mli") + "cmi"
    if debug:
        print("CMIFNAME: %s" % cmifname)

    obj_cmi = ctx.actions.declare_file(scope + cmifname)

    if debug:
        print("OBJ_CMI: %s" % obj_cmi)

    ################################################################
    args = ctx.actions.args()

    # args.add("ocamlc")
    if mode == "native":
        args.add(tc.ocamlopt.basename)
    else:
        args.add(tc.ocamlc.basename)
    # options = tc.opts + ctx.attr.opts
    # args.add_all(options)
    args.add_all(ctx.attr.opts)
    # for opt in ctx.attr._opts[BuildSettingInfo].value:
    #     # print("EXTRA OPT: %s" % opt)
    #     args.add(opt)

    options = get_options(rule, ctx)
    args.add_all(options)

    if ns_resolver:
        args.add("-no-alias-deps")
        args.add("-open", ns_resolver)

    mydeps = ctx.attr.deps + [ctx.attr._ns_resolver]

    merge_deps(mydeps,
               indirect_file_depsets,
               indirect_path_depsets,
               indirect_resolver_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    indirect_paths_depset = depset(transitive = indirect_path_depsets)
    for path in indirect_paths_depset.to_list():
            includes.append(path)

    indirect_resolvers_depset = depset(transitive = indirect_resolver_depsets)
    # for resolver in indirect_resolvers_depset.to_list():
    #       args.add("-open", resolver)

    args.add("-c") # interfaces always compile-only?

    includes.append(obj_cmi.dirname)

    ppx_opam_adjunct_deps = []
    ppx_nopam_adjunct_deps = []

    if ctx.attr.ppx:
        provider = ctx.attr.ppx[AdjunctDepsProvider]
        for opam in provider.opam.to_list():
            args.add("-package", opam)

        for nopam in provider.nopam.to_list():
            if debug:
                print("NOAPM adjunct: %s" % nopam)
      # if PpxExecutableProvider in ctx.attr.ppx:
      #     ppx_opam_adjunct_deps = ctx.attr.ppx[PpxExecutableProvider].deps.opam_adjunct
      #     for dep in ppx_opam_adjunct_deps.to_list():
      #         opam_deps.append(dep.pkg.name)
      #         # for p in dep.pkg.to_list():
      #         #     opam_deps.append(p.name)
      #     ppx_nopam_adjunct_deps = ctx.attr.ppx[PpxExecutableProvider].deps.nopam_adjunct
      #     for adjunct_dep in ppx_nopam_adjunct_deps.to_list():
      #         # if debug:
      #         #     print("ADJUNCT DEP: %s" % adjunct_dep)
      #         nopam_deps.append(adjunct_dep)
      #         includes.append(adjunct_dep.dirname)

    # for dep in mydeps.opam.to_list():
    #     if not dep.ppx_driver: ## FIXME: is this correct?
    #         opam_deps.append(dep.pkg.name)
        # for x in dep.pkg.to_list():
        #     opam_deps.append(x.name)

    if len(opam_deps) > 0:
        ## linking not needed to produce .cmi files
        # args.add("-linkpkg")
        for dep in opam_deps:  # mydeps.opam.to_list():
            ## FIXME: we do not want to add opam ppx deps, they cause
            ## ocamlfind to inject a -ppx option that introduces ppx_deriving
            # if ctx.label.name == "_Parallel_scan.cmi":
            #     if dep.startswith("ppx"):
            #         print("OMITTING PPX dep: %s" % dep)
            #     else:
            #         args.add("-package", dep)
            # else:
            args.add("-package", dep)

    indirect_opams_depset = depset(transitive = indirect_opam_depsets)
    for opam in indirect_opams_depset.to_list():
        args.add("-package", opam)

    if ctx.attr.deps_opam:
        args.add("-linkpkg")  ## add files to cmd line
        for dep in ctx.attr.deps_opam:
            args.add("-package", dep)  ## add dirs to search path

    intf_dep = None

    cc_deps  = {}
    link_search = []

    # for dep in mydeps.nopam.to_list():
    #   if debug:
    #       print("NOPAM DEP: %s" % dep)
    #       print("NOPAM DEP ext: %s" % dep.extension)
    #   # if dep.basename.startswith("ppx"):
    #   #     print("OMITTING PPX dep: %s" % dep)
    #   if dep.extension == "cmx":
    #       includes.append(dep.dirname)
    #       dep_graph.append(dep)
    #       # ocamlc chokes on cmx when building cmi
    #       # build_deps.append(dep)
    #   elif dep.extension == "cmo":
    #       includes.append(dep.dirname)
    #       dep_graph.append(dep)
    #       # ocamlc chokes on cmx when building cmi
    #       # build_deps.append(dep)
    #   elif dep.extension == "cmi":
    #       includes.append(dep.dirname)
    #       dep_graph.append(dep)
    #   elif dep.extension == "mli":
    #       includes.append(dep.dirname)
    #       dep_graph.append(dep)
    #   elif dep.extension == "cma":
    #       includes.append(dep.dirname)
    #       dep_graph.append(dep)
    #       build_deps.append(dep)
    #   elif dep.extension == "cmxa":
    #       includes.append(dep.dirname)
    #       dep_graph.append(dep)
    #       # build_deps.append(dep)
    #       # build_deps.append(dep) ## compiler "don't know what to do with" cmxa files
    #       # for g in dep[OcamlArchiveProvider].deps.nopam.to_list():
    #       #     if g.path.endswith(".cmx"):
    #       #         includes.append(g.dirname)
    #       #         build_deps.append(g)
    #       #         dep_graph.append(g)
    #   elif dep.extension == "o":
    #       # build_deps.append(dep)
    #       includes.append(dep.dirname)
    #       dep_graph.append(dep)
    #   elif dep.extension == "a":
    #       # build_deps.append(dep)
    #       includes.append(dep.dirname)
    #       dep_graph.append(dep)
    #   elif dep.extension == "lo":
    #       if debug:
    #           print("NOPAM .lo DEP: %s" % dep)
    #           dep_graph.append(dep)
    #           args.add("-ccopt", "-l" + dep.path)
    #   elif dep.extension == "so":
    #       if debug:
    #           print("ADDING DSO FILE: %s" % dep)
    #       dep_graph.append(dep)
    #       link_search.append("-L" + dep.dirname)
    #       libname = file_to_lib_name(dep)
    #       cc_deps.append("-l" + libname)
    #       # libname = dep.basename[:-3]
    #       # libname = libname[3:]
    #       # args.add("-ccopt", "-L" + dep.dirname)
    #       # args.add("-cclib", "-l" + libname)
    #       # cclib_deps.append(dep)
    #   elif dep.extension == "dylib":
    #       if debug:
    #           print("ADDING DYLIB: %s" % dep)
    #       dep_graph.append(dep)
    #       link_search.append("-L" + dep.dirname)
    #       libname = file_to_lib_name(dep)
    #       cc_deps.append("-l" + libname)
    #       # libname = dep.basename[:-6]
    #       # libname = libname[3:]
    #       # args.add("-ccopt", "-L" + dep.dirname)
    #       # args.add("-cclib", "-l" + libname)
    #       # includes.append(dep.dirname)
    #       # cclib_deps.append(dep)
    #   elif dep.extension == ".cmxs":
    #       includes.append(dep.dirname)
    #   else:
    #       if debug:
    #           print("NOMAP DEP not .cmx, ,cmxa, .o, .so: %s" % dep.path)

    # print("XXXX DEPS for %s" % ctx.label.name)
    # for dep in ctx.attr.deps:
    #     if debug:
    #         print("DEP: %s" % dep)
    #     # if OpamPkgInfo in dep:
    #     #   g = dep[OpamPkgInfo].pkg.to_list()[0]
    #     #   args.add("-package", dep[OpamPkgInfo].pkg.to_list()[0].name)
    #     # else:
    #     for g in dep[DefaultInfo].files.to_list():
    #         if debug:
    #             print("DEPFILE %s" % g)
    #         # print(g)
    #         # if g.path.endswith(".o"):
    #         #   dep_graph.append(g)
    #         #   includes.append(g.dirname)
    #         if g.path.endswith(".cmx"):
    #             dep_graph.append(g)
    #             includes.append(g.dirname)
    #         elif g.path.endswith(".cmxa"):
    #             dep_graph.append(g)
    #             includes.append(g.dirname)
    #             ## expose cmi files of deps for linking
    #             if OcamlArchiveProvider in dep:
    #                 for h in dep[OcamlArchiveProvider].deps.nopam.to_list():
    #                     # print("LIBDEP: %s" % h)
    #                     if h.path.endswith(".cmx"):
    #                         dep_graph.append(h)
    #                         includes.append(h.dirname)
    #             elif PpxArchiveProvider in dep:
    #                 for h in dep[PpxArchiveProvider].deps.nopam.to_list():
    #                     # print("LIBDEP: %s" % h)
    #                     if h.path.endswith(".cmx"):
    #                         dep_graph.append(h)
    #                         includes.append(h.dirname)
    #         elif g.path.endswith(".cmi"):
    #             intf_dep = g
    #             #   dep_graph.append(g)
    #             includes.append(g.dirname)

    # args.add_all(link_search, before_each="-ccopt", uniquify = True)
    # args.add_all(cc_deps, before_each="-cclib", uniquify = True)

    args.add_all(includes, before_each="-I", uniquify = True)
    args.add_all(build_deps)

    args.add("-o", obj_cmi)

    # args.add(ctx.file.src)
    args.add("-intf", sigfile)

    dep_graph.append(sigfile) #] + build_deps
    # if ctx.attr.ns_resolver:
    #     if mode == "native":
    #         dep_graph.append(ctx.attr.ns_resolver[OcamlNsLibraryProvider].payload.cmx)
    #     else:
    #         dep_graph.append(ctx.attr.ns_resolver[OcamlNsLibraryProvider].payload.cmo)

    input_depset = depset(direct = dep_graph, # direct_file_deps,
                          transitive = indirect_file_depsets)

    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs = input_depset, # dep_graph,
        outputs = [obj_cmi],
        tools = [tc.ocamlopt],
        mnemonic = "OcamlInterface",
        progress_message = "{mode} compiling ocaml_signature: {ws}//{pkg}:{tgt}{msg}".format(
            mode = mode,
            ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
            msg = "" if not ctx.attr.msg else ": " + ctx.attr.msg
        )
        # progress_message = "ocaml_signature compile {}".format(
        #     # ctx.label.name,
        #     ctx.attr.msg
        #   )
    )

    defaultInfo = DefaultInfo(
        files = depset(order="postorder",
                       direct = [obj_cmi],
                       transitive = [depset(order="postorder",
                                            direct = [sigfile],
                                            transitive = indirect_file_depsets
                                            )])
    )

    search_paths = sets.to_list(sets.make(includes))  ## uniqify

    defaultMemo = DefaultMemo(
        paths     = depset(direct = search_paths, transitive = [indirect_paths_depset]),
        resolvers = depset(direct = [direct_resolver] if direct_resolver else [],
                           transitive = [indirect_resolvers_depset]),
    )

    deps_opam = depset(direct = ctx.attr.deps_opam, transitive = indirect_opam_depsets)
    opamProvider = OpamDepsProvider(
        pkgs = deps_opam
    )

    sigProvider = OcamlSignatureProvider(
        name      = capitalize_initial_char(paths.split_extension(obj_cmi.basename)[0]),
        module    = obj_cmi,
    )

    ## FIXME: add CcDepsProvider
    return [
        defaultInfo,
        defaultMemo,
        sigProvider,
        opamProvider]

################################
rule_options = options("ocaml")
rule_options.update(options_ns_opts("ocaml"))
rule_options.update(options_ppx)

#######################
ocaml_signature = rule(
    implementation = _ocaml_signature_impl,
    doc = """Generates OCaml .cmi (inteface) file. [User Guide](../ug/ocaml_signature.md). Provides `OcamlSignatureProvider`.

**CONFIGURABLE DEFAULTS** for rule `ocaml_executable`

In addition to the [OCaml configurable defaults](#configdefs) that apply to all
`ocaml_*` rules, the following apply to this rule:

| Label | Default | `opts` attrib |
| ----- | ------- | ------- |
| @ocaml//interface:linkall | True | `-linkall`, `-no-linkall`|
| @ocaml//interface:thread | True | `-thread`, `-no-thread`|
| @ocaml//interface:warnings | `@1..3@5..28@30..39@43@46..47@49..57@61..62-40`| `-w` plus option value |

**NOTE** These do not support `:enable`, `:disable` syntax.

 See [Configurable Defaults](../ug/configdefs_doc.md) for more information.
    """,
    attrs = dict(
        rule_options,
        ## RULE DEFAULTS
        _linkall     = attr.label(default = "@ocaml//signature/linkall"), # FIXME: call it alwayslink?
        _thread     = attr.label(default = "@ocaml//signature/thread"),
        _warnings  = attr.label(default = "@ocaml//signature:warnings"),
        #### end options ####

        # module_name   = attr.string(
        #     doc = "Module name."
        # ),
        # ns_sep = attr.string(
        #     doc = "Namespace separator.  Default: '__'",
        #     default = "__"
        # ),
        src = attr.label(
            doc = "A single .mli source file label",
            allow_single_file = OCAML_INTF_FILETYPES
        ),
        module = attr.string(
            doc = "Name for output file. Use to coerce input file with different name, e.g. for a file generated from a .mli file to a different name, like foo.cppo.mli."
        ),
        deps = attr.label_list(
            doc = "List of OCaml dependencies. See [Dependencies](#deps) for details.",
            providers = [[OcamlArchiveProvider],
                         [OcamlSignatureProvider],
                         [OcamlLibraryProvider],
                         [OcamlNsArchiveProvider],
                         [OcamlNsLibraryProvider],
                         [PpxArchiveProvider],
                         [PpxModuleProvider],
                         [PpxNsLibraryProvider],
                         [OcamlModuleProvider]],
            # cfg = ocaml_signature_deps_out_transition
        ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
        deps_opam = attr.string_list(
            doc = "List of OPAM package names"
        ),
        ################################################################
        _ns_resolver = attr.label(
            doc = "Experimental",
            providers = [OcamlNsResolverProvider],
            default = "@ocaml//ns",
        ),
        _ns_submodules = attr.label( # _list(
            doc = "Experimental.  May be set by ocaml_ns_library containing this module as a submodule.",
            default = "@ocaml//ns:submodules", ## NB: ppx modules use ocaml_signature
        ),
        _ns_strategy = attr.label(
            doc = "Experimental",
            default = "@ocaml//ns:strategy"
        ),

        _mode       = attr.label(
            default = "@ocaml//mode",
        ),
        msg = attr.string(
            doc = "Deprecated"
        ),
        _rule = attr.string( default = "ocaml_signature" ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
    ),
    provides = [OcamlSignatureProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
