load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/_providers:ocaml.bzl",
     "CompilationModeSettingProvider",
     "OcamlArchiveProvider",
     "OcamlDepsetProvider",
     "OcamlInterfaceProvider",
     "OcamlInterfacePayload",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider")

load("@obazl_rules_opam//opam/_providers:opam.bzl", "OpamPkgInfo")

load("//ppx:_providers.bzl",
     "PpxArchiveProvider",
     "PpxExecutableProvider",
     "PpxNsModuleProvider")

load("//ocaml/_actions:rename.bzl", "rename_module")

load("//ocaml/_actions:ppx_transform.bzl", "ppx_transform")

load("//ocaml/_deps:depsets.bzl", "get_all_deps")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "file_to_lib_name",
     "get_opamroot",
     "get_sdkpath",
)

load(":options_ocaml.bzl", "options_ocaml")

load("//ocaml/_actions:utils.bzl", "get_options")

OCAML_INTF_FILETYPES = [
    ".mli", ".cmi"
]

########## RULE:  OCAML_INTERFACE  ################
def _ocaml_interface_impl(ctx):

  debug = False
  # if (ctx.label.name == "_Impl"):
  #     debug = True

  if debug:
      print("OCAML INTERFACE TARGET: %s" % ctx.label.name)

  mode = ctx.attr._mode[CompilationModeSettingProvider].value

  mydeps = get_all_deps("ocaml_interface", ctx) # ctx.attr.deps)
  # print("ALL DEPS for target %s" % ctx.label.name)
  # print(mydeps)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  dep_graph = []

  xsrc = None
  opam_deps = []
  nopam_deps = []

  build_deps = []
  dso_deps = []
  includes   = []

  tmpdir = "_obazl_/"
  if ctx.attr.ppx:
      ## this will also handle ns
    (tmpdir, xsrc) = ppx_transform("ocaml_interface", ctx, ctx.file.src)
  elif ctx.attr.ns:
    xsrc = rename_module(ctx, ctx.file.src) #, ctx.attr.ns)
  else:
    xsrc = ctx.file.src

  # cmifname = ctx.file.src.basename.rstrip("mli") + "cmi"
  if debug:
      print("XSRC: %s" % xsrc)
  cmifname = xsrc.basename.rstrip("mli") + "cmi"
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

  # args.add("-thread")

  args.add("-c") # interfaces always compile-only?

  if ctx.attr.ns:
    args.add("-no-alias-deps")
    if OcamlNsModuleProvider in ctx.attr.ns:
        provider = ctx.attr.ns[OcamlNsModuleProvider]
        dep_graph.append(provider.payload.cmi)
        if hasattr(provider.payload, "cmo"):
            ns_cm = provider.payload.cmo
            dep_graph.append(provider.payload.cmo)
        elif hasattr(provider.payload, "cmx"):
            ns_cm = provider.payload.cmx
            dep_graph.append(provider.payload.cmx)
        else:
            fail("OcamlNsModuleProvider neither cmo nor cmx: %s" % provider)
    else:
        provider = ctx.attr.ns[PpxNsModuleProvider]
        dep_graph.append(provider.payload.cmi)
        if hasattr(provider.payload, "cmo"):
            ns_cm = provider.payload.cmo
            dep_graph.append(ctx.attr.ns[PpxNsModuleProvider].payload.cmo)
        elif hasattr(provider.payload, "cmx"):
            ns_cm = provider.payload.cmx
            dep_graph.append(ctx.attr.ns[PpxNsModuleProvider].payload.cmx)
        else:
            fail("PpxNsModuleProvider payload neither cmo nor cmx: %s" % provider)
    # if mode == "native":
    #     ns_cm = ctx.attr.ns[OcamlNsModuleProvider].payload.cmx
    #     dep_graph.append(ctx.attr.ns[OcamlNsModuleProvider].payload.cmx)
    # else:
    ns_mod = capitalize_initial_char(paths.split_extension(ns_cm.basename)[0])
    args.add("-open", ns_mod)

    # capitalize_initial_char(ctx.attr.ns[PpxNsModuleProvider].payload.ns))

  # if ctx.attr.ns:
  #   args.add("-open", ctx.attr.ns)
  includes.append(obj_cmi.dirname)
  # args.add("-I", obj_cmi.dirname)

  # args.add("-linkpkg")
  # args.add("-linkall")

  ppx_opam_lazy_deps = []
  ppx_nopam_lazy_deps = []

  ## FIXME: use mydeps.opam_lazy
  if ctx.attr.ppx:
    if PpxExecutableProvider in ctx.attr.ppx:
        ppx_opam_lazy_deps = ctx.attr.ppx[PpxExecutableProvider].deps.opam_lazy
        for dep in ppx_opam_lazy_deps.to_list():
            opam_deps.append(dep.pkg.name)
            # for p in dep.pkg.to_list():
            #     opam_deps.append(p.name)
        ppx_nopam_lazy_deps = ctx.attr.ppx[PpxExecutableProvider].deps.nopam_lazy
        for lazy_dep in ppx_nopam_lazy_deps.to_list():
            # if debug:
            #     print("LAZY DEP: %s" % lazy_dep)
            nopam_deps.append(lazy_dep)
            includes.append(lazy_dep.dirname)

  for dep in mydeps.opam.to_list():
      if not dep.ppx_driver: ## FIXME: is this correct?
          opam_deps.append(dep.pkg.name)
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

  intf_dep = None

  cc_deps  = []
  link_search = []

  for dep in mydeps.nopam.to_list():
    if debug:
        print("NOPAM DEP: %s" % dep)
        print("NOPAM DEP ext: %s" % dep.extension)
    # if dep.basename.startswith("ppx"):
    #     print("OMITTING PPX dep: %s" % dep)
    if dep.extension == "cmx":
        includes.append(dep.dirname)
        dep_graph.append(dep)
        # ocamlc chokes on cmx when building cmi
        # build_deps.append(dep)
    elif dep.extension == "cmo":
        includes.append(dep.dirname)
        dep_graph.append(dep)
        # ocamlc chokes on cmx when building cmi
        # build_deps.append(dep)
    elif dep.extension == "cmi":
        includes.append(dep.dirname)
        dep_graph.append(dep)
    elif dep.extension == "mli":
        includes.append(dep.dirname)
        dep_graph.append(dep)
    elif dep.extension == "cma":
        includes.append(dep.dirname)
        dep_graph.append(dep)
        build_deps.append(dep)
    elif dep.extension == "cmxa":
        includes.append(dep.dirname)
        dep_graph.append(dep)
        # build_deps.append(dep)
        # build_deps.append(dep) ## compiler "don't know what to do with" cmxa files
        # for g in dep[OcamlArchiveProvider].deps.nopam.to_list():
        #     if g.path.endswith(".cmx"):
        #         includes.append(g.dirname)
        #         build_deps.append(g)
        #         dep_graph.append(g)
    elif dep.extension == "o":
        # build_deps.append(dep)
        includes.append(dep.dirname)
        dep_graph.append(dep)
    elif dep.extension == "a":
        # build_deps.append(dep)
        includes.append(dep.dirname)
        dep_graph.append(dep)
    elif dep.extension == "lo":
        if debug:
            print("NOPAM .lo DEP: %s" % dep)
            dep_graph.append(dep)
            args.add("-ccopt", "-l" + dep.path)
    elif dep.extension == "so":
        if debug:
            print("ADDING DSO FILE: %s" % dep)
        dep_graph.append(dep)
        link_search.append("-L" + dep.dirname)
        libname = file_to_lib_name(dep)
        cc_deps.append("-l" + libname)
        # libname = dep.basename[:-3]
        # libname = libname[3:]
        # args.add("-ccopt", "-L" + dep.dirname)
        # args.add("-cclib", "-l" + libname)
        # cclib_deps.append(dep)
    elif dep.extension == "dylib":
        if debug:
            print("ADDING DYLIB: %s" % dep)
        dep_graph.append(dep)
        link_search.append("-L" + dep.dirname)
        libname = file_to_lib_name(dep)
        cc_deps.append("-l" + libname)
        # libname = dep.basename[:-6]
        # libname = libname[3:]
        # args.add("-ccopt", "-L" + dep.dirname)
        # args.add("-cclib", "-l" + libname)
        # includes.append(dep.dirname)
        # cclib_deps.append(dep)
    elif dep.extension == ".cmxs":
        includes.append(dep.dirname)
    else:
        if debug:
            print("NOMAP DEP not .cmx, ,cmxa, .o, .so: %s" % dep.path)

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
  args.add("-intf", xsrc)

  dep_graph.append(xsrc) #] + build_deps
  # if ctx.attr.ns:
  #     if mode == "native":
  #         dep_graph.append(ctx.attr.ns[OcamlNsModuleProvider].payload.cmx)
  #     else:
  #         dep_graph.append(ctx.attr.ns[OcamlNsModuleProvider].payload.cmo)

  ctx.actions.run(
      env = env,
      executable = tc.ocamlfind,
      arguments = [args],
      inputs = dep_graph,
      outputs = [obj_cmi],
      tools = [tc.ocamlopt],
      mnemonic = "OcamlInterface",
      progress_message = "{mode} compiling ocaml_interface: @{ws}//{pkg}:{tgt}{msg}".format(
          mode = mode,
          ws  = ctx.label.workspace_name,
          pkg = ctx.label.package,
          tgt=ctx.label.name,
          msg = "" if not ctx.attr.msg else ": " + ctx.attr.msg
      )
      # progress_message = "ocaml_interface compile {}".format(
      #     # ctx.label.name,
      #     ctx.attr.msg
      #   )
  )

  if debug:
      print("IF OUT: %s" % obj_cmi)

  interface_provider = OcamlInterfaceProvider(
    payload = OcamlInterfacePayload(cmi = obj_cmi, mli = xsrc),
    deps = OcamlDepsetProvider(
      opam  = mydeps.opam,
      nopam = mydeps.nopam
    )
  )

  return [DefaultInfo(files = depset(direct = [obj_cmi])),
          interface_provider]

# (library
#  (name deriving_hello)
#  (libraries base ppxlib)
#  (preprocess (pps ppxlib.metaquot))
#  (kind ppx_deriver))

#############################################
########## DECL:  OCAML_INTERFACE  ################
ocaml_interface = rule(
    implementation = _ocaml_interface_impl,
    doc = """Generates OCaml .cmi (inteface) file. Provides `OcamlInterfaceProvider`.

**CONFIGURABLE DEFAULTS** for rule `ocaml_executable`

In addition to the [OCaml configurable defaults](#configdefs) that apply to all
`ocaml_*` rules, the following apply to this rule:

| Label | Default | `opts` attrib |
| ----- | ------- | ------- |
| @ocaml//interface:linkall | True | `-linkall`, `-no-linkall`|
| @ocaml//interface:threads | True | `-thread`, `-no-thread`|
| @ocaml//interface:warnings | `@1..3@5..28@30..39@43@46..47@49..57@61..62-40`| `-w` plus option value |

**NOTE** These do not support `:enable`, `:disable` syntax.

 See [Configurable Defaults](../ug/configdefs_doc.md) for more information.
    """,
    attrs = dict(
        options_ocaml,
        ## RULE DEFAULTS
        _linkall     = attr.label(default = "@ocaml//interface:linkall"), # FIXME: call it alwayslink?
        _threads     = attr.label(default = "@ocaml//interface:threads"),
        _warnings  = attr.label(default = "@ocaml//interface:warnings"),
        #### end options ####

        ## FIXME: does this make sense for interface files?
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
        ns = attr.label(
            doc = "Label of an `ocaml_ns` target. Used to derive namespace, output name, -open arg, etc.",
        ),
        src = attr.label(
            doc = "A single .mli source file label",
            allow_single_file = OCAML_INTF_FILETYPES
        ),
        ppx  = attr.label(
            doc = "Label of `ppx_executable` target to be used to transform source before compilation.",
            executable = True,
            cfg = "host",
            allow_single_file = True,
            providers = [PpxExecutableProvider]
        ),
        ppx_args  = attr.string_list(
            doc = "Options to pass to PPX executable.",
        ),
        ppx_data  = attr.label_list(
            doc = "PPX runtime dependencies. E.g. a file used by %%import from ppx_optcomp.",
            allow_files = True,
        ),
        ppx_print = attr.label(
            doc = "Format of output of PPX transform, binary (default) or text. Value must be one of '@ppx//print:binary', '@ppx//print:text'.",
            default = "@ppx//print:binary"
        ),
        # ppx_runtime_deps  = attr.label_list(
        #     doc = "PPX dependencies. E.g. a file used by %%import from ppx_optcomp.",
        #     allow_files = True,
        # ),
        # data = attr.label_list(
        # ),
        deps = attr.label_list(
            doc = "List of OCaml dependencies. See [Dependencies](#deps) for details.",
            providers = [[OpamPkgInfo],
                         [OcamlArchiveProvider],
                         [OcamlLibraryProvider],
                         [OcamlNsModuleProvider],
                         [PpxArchiveProvider],
                         [OcamlModuleProvider]]
        ),
        _mode       = attr.label(
            default = "@ocaml//mode",
        ),
        msg = attr.string(
            doc = "Deprecated"
        ),
    ),
    provides = [OcamlInterfaceProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
