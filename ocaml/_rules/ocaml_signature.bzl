load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "AdjunctDepsProvider",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlArchiveProvider",
     # "OcamlDepsetProvider",
     "OcamlSignatureProvider",
     # "OcamlInterfacePayload",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsEnvProvider",
     "OcamlNsArchiveProvider",
     "OcamlNsLibraryProvider",
     "OpamDepsProvider",
     "OpamPkgInfo",
     "PpxArchiveProvider",
     "PpxExecutableProvider")

load("//ocaml/_rules/utils:rename.bzl", "rename_module")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_deps:depsets.bzl", "get_all_deps")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "file_to_lib_name",
     "get_opamroot",
     "get_sdkpath",
)

load(":options.bzl", "options", "options_ppx")

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
    # if (ctx.label.name == "_Impl"):
    #     debug = True

    if debug:
        print("OCAML INTERFACE TARGET: %s" % ctx.label.name)

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    ################
    direct_files = []
    indirect_file_depsets = [] # will be added to inputs and passed on as transitive outputs

    indirect_opam_depsets = []

    indirect_adjunct_depsets = []  # list of depsets gathered from direct deps
    indirect_adjunct_path_depsets = []  # list of depsets gathered from direct deps
    indirect_adjunct_opam_depsets  = []  # list of depsets gathered from direct deps

    indirect_path_depsets = []

    direct_resolver = None
    indirect_resolver_depsets = []

    direct_cc_deps  = []
    indirect_cc_deps  = []
    ################

    dep_graph = []

    sigfile = None
    opam_deps = []
    nopam_deps = []

    build_deps = []
    dso_deps = []
    includes   = []

    if ctx.attr.ppx:
        ## this will also handle ns
        sigfile = impl_ppx_transform("ocaml_signature", ctx, ctx.file.src)
        # (tmpdir, sigfile) = impl_ppx_transform("ocaml_signature", ctx, ctx.file.src)
    elif ctx.attr.ns_env:
        sigfile = rename_module(ctx, ctx.file.src) #, ctx.attr.ns_env)
    else:
        if ctx.attr.module:
            sigfile = rename_module(ctx, ctx.file.src) #, ctx.attr.ns_env)
        else:
            sigfile = ctx.file.src

    # cmifname = ctx.file.src.basename.rstrip("mli") + "cmi"
    if debug:
        print("SIGFILE: %s" % sigfile)
    cmifname = sigfile.basename.rstrip("mli") + "cmi"
    if debug:
        print("CMIFNAME: %s" % cmifname)

    obj_cmi = ctx.actions.declare_file(tmpdir + cmifname)

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

    ns = None
    ## ns target produces two files, module and interface
    if ctx.files.ns_env:
        for dep in ctx.files.ns_env:
            # print("NS DEP: %s" % dep)
            bn = dep.basename
            # print("NS DEP BASENAME: %s" % bn)
            ext = dep.extension
            ns = bn[:-(len(ext)+1)]
            # print("NS: %s" % ns)
            if dep.extension == "cmo":
                dep_graph.append(dep)
                # args.add(dep)
            if dep.extension == "cmi":
                dep_graph.append(dep)

    if ns != None:
        args.add("-no-alias-deps")
        args.add("-open", ns)

    merge_deps(ctx.attr.deps,
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
    for resolver in indirect_resolvers_depset.to_list():
          args.add("-open", resolver)

    args.add("-c") # interfaces always compile-only?

    includes.append(obj_cmi.dirname)

    ppx_opam_adjunct_deps = []
    ppx_nopam_adjunct_deps = []

    if ctx.attr.ppx:
        provider = ctx.attr.ppx[AdjunctDepsProvider]
        for opam in provider.opam.to_list():
            args.add("-package", opam)

        for nopam in provider.nopam.to_list():
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

    cc_deps  = []
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

    args.add_all(link_search, before_each="-ccopt", uniquify = True)
    args.add_all(cc_deps, before_each="-cclib", uniquify = True)

    args.add_all(includes, before_each="-I", uniquify = True)
    args.add_all(build_deps)

    args.add("-o", obj_cmi)

    # args.add(ctx.file.src)
    args.add("-intf", sigfile)

    dep_graph.append(sigfile) #] + build_deps
    # if ctx.attr.ns_env:
    #     if mode == "native":
    #         dep_graph.append(ctx.attr.ns_env[OcamlNsLibraryProvider].payload.cmx)
    #     else:
    #         dep_graph.append(ctx.attr.ns_env[OcamlNsLibraryProvider].payload.cmo)

    input_depset = depset(direct = dep_graph, # direct_files,
                          transitive = indirect_file_depsets)

    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs = input_depset, # dep_graph,
        outputs = [obj_cmi],
        tools = [tc.ocamlopt],
        mnemonic = "OcamlInterface",
        progress_message = "{mode} compiling ocaml_signature: @{ws}//{pkg}:{tgt}{msg}".format(
            mode = mode,
            ws  = ctx.label.workspace_name,
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

    return [
        defaultInfo,
        defaultMemo,
        sigProvider,
        opamProvider]

################################
rule_options = options("@ocaml")
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

        ## FIXME: does this make sense for signature files?
        ## No: just use opts
        # linkall = attr.bool(default = True),

        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        # module_name   = attr.string(
        #     doc = "Module name."
        # ),
        # ns_sep = attr.string(
        #     doc = "Namespace separator.  Default: '__'",
        #     default = "__"
        # ),
        ns_env = attr.label(
            doc = "Label of an ocaml_ns_env target. Used for renaming struct source file. See [Namepaces](../namespaces.md) for more information.",
            providers = [OcamlNsEnvProvider],
            default = None
        ),
        # ns_init = attr.label(
        #     doc = "Experimental"
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
            providers = [[OpamPkgInfo],
                         [OcamlArchiveProvider],
                         [OcamlSignatureProvider],
                         [OcamlLibraryProvider],
                         [OcamlNsArchiveProvider],
                         [OcamlNsLibraryProvider],
                         [PpxArchiveProvider],
                         [OcamlModuleProvider]]
        ),
        deps_opam = attr.string_list(
            doc = "List of OPAM package names"
        ),
        _mode       = attr.label(
            default = "@ocaml//mode",
        ),
        msg = attr.string(
            doc = "Deprecated"
        ),
        _rule = attr.string( default = "ocaml_signature" )
    ),
    provides = [OcamlSignatureProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
