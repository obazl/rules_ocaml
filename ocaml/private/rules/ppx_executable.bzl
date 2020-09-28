load("//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OpamPkgInfo",
     "OcamlArchiveProvider",
     "OcamlModuleProvider",
     "PpxBinaryProvider",
     "PpxModuleProvider")
load("//ocaml/private/actions:ppx.bzl",
     "apply_ppx",
     "ocaml_ppx_compile",
     # "ocaml_ppx_apply",
     "ocaml_ppx_library_gendeps",
     "ocaml_ppx_library_cmo",
     "ocaml_ppx_library_compile",
     "ocaml_ppx_library_link")
load("//ocaml/private:deps.bzl", "get_all_deps")
load("//ocaml/private:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

#############################################
####  PPX_EXECUTABLE IMPLEMENTATION
def _ppx_executable_impl(ctx):

  debug = False
  # if (ctx.label.name == "vector_ffi_bindings.cm_"):
  # if (ctx.label.name == "ppx_exe"):
  # # if (ctx.label.name == "ppxlib_metaquot"):
  #     debug = True

  if debug:
      print("\n\n\tPPX_EXECUTABLE TARGET: %s\n\n" % ctx.label.name)

 #   dep_labels = [dep.label for dep in ctx.attr.deps]
#   if Label("@opam//pkg:ppxlib.runner") in dep_labels:
#     if not "-predicates" in ctx.attr.opts:
#       print("""\n\nWARNING: target '{target}' depends on
# '@opam//pkg:ppxlib.runner' but lacks -predicates option. PPX binaries that depend on this
# usually pass \"-predicates\", \"ppx_driver\" to opts. Without this option, the binary may
# compile but may not work as intended.\n\n""".format(target = ctx.label.name))
#   else:
#     print("""\n\nWARNING: ppx_executable target '{target}'
# does not have a driver dependency.  Such targets usually depend on '@opam//pkg:ppxlib.runner'
# or a similar PPX driver. Without a driver, the target may compile but not work as intended.\n\n""".format(target = ctx.label.name))

  # print("PPX BINARY: %s" % ctx.label.name)
  # for src in ctx.attr.srcs:
    # print("PPX BIN SRC: %s" % src)
    # print("PPX BIN SRC type: %s" % type(src))
    # if PpxModuleProvider in src:
      # print("PPX MODULE PROVIDER: %s" % src[PpxModuleProvider])

  mydeps = get_all_deps("ppx_executable", ctx)
  dep_graph = []

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  outfilename = ctx.label.name
  outbinary = ctx.actions.declare_file(outfilename)

  args = ctx.actions.args()
  args.add("ocamlopt")
  options = tc.opts + ctx.attr.opts
  if "-predicates" not in options:
      print("\n\n\tWARNING: did you forget a -predicates option for your ppx_executable?\n\n")
  if "-linkall" not in options:
      print("\n\n\tWARNING: did you forget the -linkall option for your ppx_executable?\n\n")

  args.add_all(options)

  args.add("-o", outbinary)

  build_deps = []
  includes = []

  # print("NOPAMS: %s" % mydeps.nopam)
  # we need to add the archive components to inputs, the archive is not enough
  # without these we get "implementation not found"
  for dep in mydeps.nopam.to_list():
    if debug:
        # print("DEPGRAPH:  %s" % dep_graph)
        print("DEP:  %s" % dep)
    if dep.extension == "cmx":
      dep_graph.append(dep)
      includes.append(dep.dirname)
      build_deps.append(dep)
    if dep.extension == "o":
      dep_graph.append(dep)
      includes.append(dep.dirname)
    if dep.extension == "cmi":
      dep_graph.append(dep)
      includes.append(dep.dirname)
    if dep.extension == "mli":
      dep_graph.append(dep)
      includes.append(dep.dirname)
    if dep.extension == "cmxa":
      dep_graph.append(dep)
      includes.append(dep.dirname)
      build_deps.append(dep)
    if dep.extension == "a":
      dep_graph.append(dep)
      includes.append(dep.dirname)
  # for dep in ctx.attr.build_deps:
  #   for g in dep[DefaultInfo].files.to_list():
  #     if g.path.endswith(".cmx"):
  #       build_deps.append(g)
  #       includes.append(g.dirname)
  #     if g.path.endswith(".cmxa"):
  #       build_deps.append(g)
  #       includes.append(g.dirname)

  args.add_all(includes, before_each="-I", uniquify = True)

  opam_deps = mydeps.opam.to_list()
  if len(opam_deps) > 0:
    # print("Linking OPAM deps for {target}".format(target=ctx.label.name))
    args.add("-linkpkg")
    for dep in opam_deps:
        args.add("-package", dep.pkg.to_list()[0].name)
        # args.add_all([dep.to_list()[0].name for dep in opam_deps], before_each="-package")

  # WARNING: don't add build_deps to command line.  For namespaced
  # modules, they may contain both a .cmx and a .cmxa with the same
  # name, which define the same module, which will make the compiler
  # barf.
  # OTOH, if we do not list them, they will not be found when the ppx is used.

    # if not dep.ppx_driver:
    #   if dep.pkg.to_list()[0].name == "async":
    #     if async:
    #       args.add("-package", dep.pkg.to_list()[0].name)
    #   else:
    #       args.add("-package", dep.pkg.to_list()[0].name)
  # print("\n\nTarget: {target}\nOPAM deps: {deps}\n\n".format(target=ctx.label.name, deps=opam_deps))

  # opam_labels = [dep.to_list()[0].name for dep in opam_deps]
  # opam_labels = [dep.pkg.to_list()[0].name for dep in opam_deps]
  # if len(opam_deps) > 0:
  #   # print("Linking OPAM deps for {target}".format(target=ctx.label.name))
  #   args.add("-linkpkg")
  #   for dep in opam_deps:
  #     # print("OPAM DEP: %s" % dep.pkg.to_list()[0].name)
  #     # if (dep.pkg.to_list()[0].name != "ppx_deriving.api"):
  #     #   if (dep.pkg.to_list()[0].name != "ppx_deriving.eq"):
  #     args.add("-package", dep.pkg.to_list()[0].name)
  #     args.add_all([dep.to_list()[0].name for dep in opam_deps], before_each="-package")
  # print("OPAM LABELS: %s" % opam_labels)

  # args.add("-absname")

  # non-ocamlfind-enabled deps:
 # for dep in build_deps:
  #   print("BUILD DEP: %s" % dep)

  if debug:
      print("DEP_GRAPH:")
      print(dep_graph)

  entailing_opam_deps = []
  entailing_nopam_deps = []
  entailed_deps = []
  for x_dep in ctx.attr.x_deps:
    if debug:
        print("DEP X_DEP: %s" % x_dep)
        # ed = ctx.attr.deps[key]
        # if OpamPkgInfo in ed:
        #     if debug:
        #         print("is OPAM")
        #     output_dep = ed[OpamPkgInfo].pkg.to_list()[0]
        #     entailed_deps.append(output_dep)
        # # else:
        # #     entailed_deps.append(ctx.attr.deps[key].name)
    if OpamPkgInfo in x_dep:
        if debug:
            print("is OPAM: %s" % x_dep)
        entailed_deps.append(x_dep)
        # output_dep = x_dep[OpamPkgInfo].pkg.to_list()[0]
        # entailing_opam_deps.append(output_dep.name)
    # else:
    #     if debug:
    #         print("is NOPAM: %s" % key)
    #     if OcamlArchiveProvider in key:
    #         archive = key[OcamlArchiveProvider]
    #         if debug:
    #             print("OCAML ARCHIVE: %s" % archive)
    #             print(" PAYLOAD: %s" % archive.payload)
    #         # build_deps.append(archive.payload.cmxa)
    #         # build_deps.append(archive.payload.a)
    #         dep_graph.append(archive.payload.cmxa)
    #         dep_graph.append(archive.payload.a)
    #         for dep in archive.deps.opam.to_list():
    #             if debug:
    #                 print("OCAML A OPAM DEP: %s" % dep)
    #             # entailing_opam_deps.append(dep)
    #         for dep in archive.deps.nopam.to_list():
    #             if debug:
    #                 print("OCAML A NOPAM DEP: %s" % dep)
    #     elif OcamlModuleProvider in key:
    #         dep = key[OcamlModuleProvider]
    #         if debug:
    #             print("OCAML MODULE: %s" % dep)
    #     for f in key.files.to_list():
    #         print("XXXXXXXXXXXXXXXX UNKOWN PROVIDER: %s" % key)

  # if len(entailing_opam_deps) > 0:
  #     args.add("-linkpkg")
  #     for dep in entailing_opam_deps:
  #         args.add("-package", dep)

  args.add_all(build_deps)
  # driver shim source must come after lib deps!
  for src in ctx.files.srcs:
      if src.extension == "cmx":
          args.add(src)
      elif src.extension == "ml":
          args.add(src)

  dep_graph.extend(build_deps)
  dep_graph.extend(ctx.files.srcs)

        ## opam deps are just strings, we feed them to ocamlfind, which finds the file.
        ## this means we cannot add them to the dep_graph.
        ## this makes sense, the exe we build does not depend on these,
        ## it's the subsequent transform that depends on them.
    # else:
    #     dep_graph.append(dep)
    #FIXME: also support non-opam transform deps

  # print("DEP_GRAPH: %s" % dep_graph)
  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = dep_graph,
    outputs = [outbinary],
    tools = [tc.opam, tc.ocamlfind, tc.ocamlopt],
    mnemonic = "OcamlPPXBinary",
    progress_message = "ppx_executable({}), {}".format(
      ctx.label.name, ctx.attr.message
      )
  )


  # print("PPX_EXECUTABLE TRANSFORM: %s" % entailed_deps)

  return [DefaultInfo(executable=outbinary,
                      files = depset(direct = [outbinary])),
          PpxBinaryProvider(
            payload=outbinary,
            args = depset(direct = ctx.attr.args),
            deps = struct(
                opam = mydeps.opam,
                nopam = mydeps.nopam,
                ## FIXME: support both opam and nopam x_deps
                x = depset(direct = entailed_deps)
            )
          )]

# (library
#  (name deriving_hello)
#  (libraries base ppxlib)
#  (preprocess (pps ppxlib.metaquot))
#  (kind ppx_deriver))

#############################################
########## DECL:  PPX_EXECUTABLE  ################
ppx_executable = rule(
  implementation = _ppx_executable_impl,
  # implementation = _ppx_executable_compile_test,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    # IMPLICIT: args = string list = runtime args, passed whenever the binary is used
    srcs = attr.label_list(
      allow_files = OCAML_IMPL_FILETYPES
    ),
    ppx_bin  = attr.label(
      doc = "PPX binary (executable).",
      providers = [PpxBinaryProvider]
    ),
    ppx  = attr.label(
      doc = "PPX binary (executable).",
      providers = [PpxBinaryProvider],
      mandatory = False,
    ),
    opts = attr.string_list(),
    linkopts = attr.string_list(),
    linkall = attr.bool(default = True),
    deps = attr.label_list(
      doc = "Deps needed to build this ppx executable.",
      providers = [[DefaultInfo], [PpxModuleProvider]]
    ),
    x_deps = attr.label_list(
      doc = """(Entailed) eXtension Dependencies.""",
      # providers = [[DefaultInfo], [PpxModuleProvider]]
    ),
    mode = attr.string(default = "native"),
    message = attr.string()
  ),
  provides = [DefaultInfo, PpxBinaryProvider],
  executable = True,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
