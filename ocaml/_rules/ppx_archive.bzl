load("@bazel_skylib//lib:collections.bzl", "collections")

load("//ppx/_config:transitions.bzl", "ppx_mode_transition")

# load("//ocaml/_providers:ocaml.bzl", "OcamlSDK")
load("@obazl_rules_opam//opam/_providers:opam.bzl", "OpamPkgInfo")
load("//ocaml/_providers:ocaml.bzl", "OcamlArchivePayload")
load("//ppx:_providers.bzl",
     "PpxArchiveProvider",
     "PpxDepsetProvider",
     "PpxCompilationModeSettingProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")

load("//ocaml/_deps:depsets.bzl", "get_all_deps")
load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     # "get_src_root",
     # "split_srcs",
     # "strip_ml_extension",
     # "OCAML_FILETYPES",
     # "OCAML_IMPL_FILETYPES",
     # "OCAML_INTF_FILETYPES",
     # "WARNING_FLAGS"
)
load("//ocaml/_actions:utils.bzl", "get_options")
load(":options_ppx.bzl", "options_ppx")

# print("implementation/ocaml.bzl loading")

tmpdir = "_obazl_/"

################################################################
#### Compile/link without preprocessing.
#### WARNING: this impl is sequential; it passes all source files to
#### one action, which will compile them (presumably in sequence) and
#### then link.
def _ppx_archive_impl(ctx):

  debug = False
  if ctx.label.name == "ppx":
      if ctx.label.package == "src/lib/logproc_lib":
          print("DEBUGGING %s" % ctx.label)
          debug = True


  mydeps = get_all_deps("ppx_archive", ctx)

  # print("PPX ARCHIVE MYDEPS")
  # print(mydeps.opam)

  # opam_lazy_deps = []
  # nopam_lazy_deps = []
  # for dep in ctx.attr.lazy_deps:
  #   if OpamPkgInfo in dep:
  #       opam_lazy_deps.append(dep)
  #   else:
  #       nopam_lazy_deps.append(dep)

  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

  # lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  mode = ctx.attr._mode[0][PpxCompilationModeSettingProvider].value
  ext = ".cmxa" if mode == "native" else ".cma"

  ## declare outputs
  # obj_files = []

  if "-linkpkg" in ctx.attr.opts:
    fail("-linkpkg option not supported for ppx_archive rule")

  obj = {}
  if ctx.attr.archive_name:
    if ctx.attr.linkshared:
      obj["cmxs"] = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ".cmxs")
    else:
      obj["cm_a"] = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ext)
      if mode == "native":
          obj["a"]    = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ".a")
  else:
    if ctx.attr.linkshared:
      obj["cmxs"] = ctx.actions.declare_file(tmpdir + ctx.label.name + ".cmxs")
    else:
      obj["cm_a"] = ctx.actions.declare_file(tmpdir + ctx.label.name + ext)
      if mode == "native":
          obj["a"]    = ctx.actions.declare_file(tmpdir + ctx.label.name + ".a")

  # print("PPX_ARCHIVE OBJS: %s" % obj)
  # obj_cm_a = ctx.actions.declare_file(outfile_cm_a_name)
  # obj_a    = ctx.actions.declare_file(outfile_a_name)

  ################################################################
  args = ctx.actions.args()

  if mode == "native":
      args.add(tc.ocamlopt.basename)
  else:
      args.add(tc.ocamlc.basename)

  options = get_options(rule, ctx)
  args.add_all(options)

  # NOTE: we do not put .a on the command line, since putting -o
  # foo.cmxa or -o foo.cmxs will automatically produce foo.a.
  # But we do add it to the Bazel outputs.

  ## We insert -I for each non-opam dep; since this would usually
  ## result in duplicates, we accumulate them first, then dedup.
  includes = []
  for dep in ctx.attr.deps:
    if not OpamPkgInfo in dep:
      for g in dep[DefaultInfo].files.to_list():
        if g.path.endswith(".cmx"):
          includes.append(g.dirname)
        if g.path.endswith(".cmo"):
          includes.append(g.dirname)
        if g.path.endswith(".cmxa"):
          includes.append(g.dirname)
        if g.path.endswith(".cma"):
          includes.append(g.dirname)

  args.add_all(includes, before_each="-I", uniquify = True)

  #### WARNING!!! ####
  # For linking with redirector modules (module aliases), it is not
  # enough to add libs to the command line (by adding to args). They
  # must also be added to the 'inputs' parameter of the Bazel action;
  # if we don't do this, Bazel will not make them accessible, and we
  # will get 'Error: Unbound module'.  We use dep_graph to accum them.
  build_deps = []
  dep_graph  = []
  includes   = []

  # for dep in ctx.files.deps:
  #     print("DIRECT DEP: %s" % dep)
  #     if dep.extension != "cmi":
  #         includes.append(dep.dirname)
  #         dep_graph.append(dep)
  #         build_deps.append(dep)

  ## depset for archives omits direct deps, since they are bundled into the payload
  for dep in mydeps.nopam.to_list():
    if debug:
          print("NOPAM DEP:\n\t%s\n" % dep)
    if dep.extension == "cmx":
        includes.append(dep.dirname)
        dep_graph.append(dep)
        build_deps.append(dep)
    elif dep.extension == "cmo":
        includes.append(dep.dirname)
        dep_graph.append(dep)
        build_deps.append(dep)
    elif dep.extension == "cmi":
        dep_graph.append(dep)
        includes.append(dep.dirname)
    elif dep.extension == "mli":
        dep_graph.append(dep)
        includes.append(dep.dirname)
    elif dep.extension == "o":
        # build_deps.append(dep)
        dep_graph.append(dep)
        includes.append(dep.dirname)
    elif dep.extension == "cmxa":
        dep_graph.append(dep)
        includes.append(dep.dirname)
        ## "Option -a cannot be used with .cmxa input files."
        # build_deps.append(dep)
    elif dep.extension == "cma":
        dep_graph.append(dep)
        includes.append(dep.dirname)
        # build_deps.append(dep)
    elif dep.extension == "a":
        dep_graph.append(dep)
        build_deps.append(dep)
    elif dep.extension == "so":
        if debug:
            print("NOPAM .so DEP: %s" % dep)
        dep_graph.append(dep)
        libname = dep.basename[:-3]
        libname = libname[3:]
        if debug:
          print("LIBNAME: %s" % libname)
        args.add("-ccopt", "-L" + dep.dirname)
        args.add("-cclib", "-l" + libname)
        # dso_deps.append(dep)
    elif dep.extension == "dylib":
        if debug:
            print("NOPAM .dylib DEP: %s" % dep)
        dep_graph.append(dep)
        libname = dep.basename[:-6]
        libname = libname[3:]
        if debug:
          print("LIBNAME: %s" % libname)
        args.add("-ccopt", "-L" + dep.dirname)
        args.add("-cclib", "-l" + libname)
        # includes.append(dep.dirname)
        # dso_deps.append(dep)
    else:
        if debug:
            print("NOMAP DEP not .cmx, cmo, cmxa, cma, .o, .lo, .so, .dylib: %s" % dep.path)

  # for dep in ctx.attr.deps:
  #   if OpamPkgInfo in dep:
  #     args.add("-package", dep[OpamPkgInfo].pkg.to_list()[0].name)
  #   else:
  #     for g in dep[DefaultInfo].files.to_list():
  #       # if g.path.endswith(".cmi"):
  #       #   build_deps.append(g)
  #       if g.path.endswith(".cmx"):
  #         includes.append(g.dirname)
  #         # build_deps.append(g)
  #         dep_graph.append(g)
  #       if g.path.endswith(".cmi"):
  #         includes.append(g.dirname)
  #         dep_graph.append(g)
  #       if g.path.endswith(".o"):
  #         includes.append(g.dirname)
  #         dep_graph.append(g)
  #       if g.path.endswith(".cmxa"):
  #         includes.append(g.dirname)
  #         ## cannot pass a cmxa dep when using -a
  #         # build_deps.append(g)
  #         dep_graph.append(g)

  # for an archive we need all deps on the command line:
  args.add_all(build_deps)

  # print("DEPS")
  # print(build_deps)

  args.add_all(includes, before_each="-I", uniquify = True)

  # args.add_all(ctx.files.srcs)

  # inputs_arg = ctx.files.srcs + build_deps
  # dep_graph.extend(ctx.files.srcs)

  if ctx.attr.linkshared:
    args.add("-shared")
    args.add("-o", obj["cmxs"])
  else:
    args.add("-a")
    args.add("-o", obj["cm_a"])

  # print("INPUT_ARGS:")
  # print(inputs_arg)

  # print("OUTPUTS_ARG:")
  # print(outputs_arg)
  ctx.actions.run(
      env = env,
      executable = tc.ocamlfind,
      arguments = [args],
      inputs = dep_graph,
      outputs = obj.values(), # outputs_arg,
      tools = [tc.ocamlfind, tc.ocamlopt],
      mnemonic = "PpxArchive",
      progress_message = "{mode} compiling ppx_archive: @{ws}//{pkg}:{tgt}{msg}".format(
          mode = mode,
          ws  = ctx.label.workspace_name,
          pkg = ctx.label.package,
          tgt=ctx.label.name,
          msg = "" if not ctx.attr.msg else ": " + ctx.attr.msg
      )
      # progress_message = "{mode} compiling ppx_archive({}): {}".format(
      #   ctx.label.name, ctx.attr.msg
      # )
  )

  if mode == "native":
      payload = OcamlArchivePayload(
          archive = ctx.label.name,
          cmxa = obj["cmxa"] if "cmxa" in obj else None,
          cmxs = obj["cmxs"] if "cmxs" in obj else None,
          a    = obj["a"] if "a" in obj else None
          # cmi  : .cmi file produced by the target
          # cm   : .cmx or .cmo file produced by the target
          # o    : .o file produced by the target
      )
  else:
      payload = OcamlArchivePayload(
          archive = ctx.label.name,
          cma = obj["cm_a"] if "cm_a" in obj else None,
          cmxs = obj["cmxs"] if "cmxs" in obj else None,
          # cmi  : .cmi file produced by the target
          # cm   : .cmx or .cmo file produced by the target
          # o    : .o file produced by the target
      )

  ppx_provider = PpxArchiveProvider(
      payload = payload,
      deps = PpxDepsetProvider(
          opam  = mydeps.opam,
          opam_lazy = mydeps.opam_lazy,
          nopam = mydeps.nopam,
          nopam_lazy = mydeps.nopam_lazy
      )
  )

  defaultInfo = DefaultInfo(
      files = depset(direct = obj.values()) # [obj_cmxa, obj_a])
  )

  result = [defaultInfo, ppx_provider]
  if debug:
      print("PpxArchiveProvider RESULT:")
      print(result)

  return result

#############################################
#### RULE DECL:  PPX_ARCHIVE  #########
ppx_archive = rule(
    implementation = _ppx_archive_impl,
    attrs = dict(
        options_ppx,
        archive_name = attr.string(),
        preprocessor = attr.label(
            providers = [PpxExecutableProvider],
            executable = True,
            cfg = "exec",
            # allow_single_file = True
        ),
        msg = attr.string(),
        dump_ast = attr.bool(default = True),
        # srcs = attr.label_list(
        #   allow_files = OCAML_FILETYPES
        # ),
        linkshared = attr.bool(default = False),
        _linkall     = attr.label(default = "@ppx//archive:linkall"),
        _threads     = attr.label(default = "@ppx//archive:threads"),
        _warnings  = attr.label(default = "@ppx//archive:warnings"),
        #### end options ####
        deps = attr.label_list(
            providers = [[DefaultInfo], [PpxModuleProvider]]
        ),
        lazy_deps = attr.label_list(
            providers = [[DefaultInfo], [PpxModuleProvider]]
        ),
        _mode = attr.label(
            default = "@ppx//mode",
            cfg     = ppx_mode_transition
        ),
        _allowlist_function_transition = attr.label(
            ## required for transition fn of attribute _mode
        default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        ## FIXME: add cc_* options?
    ),
    provides = [DefaultInfo, PpxArchiveProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
    # Attaching at rule transitions the configuration of this target and all its dependencies
    # (until it gets overwritten again, for example...)
    # cfg     = ppx_mode_transition
)
