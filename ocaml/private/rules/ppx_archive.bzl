load("@obazl//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OpamPkgInfo",
     "PpxInfo")
load("@obazl//ocaml/private:actions/ocamlopt.bzl",
     "compile_native_with_ppx",
     "link_native")
load("@obazl//ocaml/private:actions/ppx.bzl",
     "apply_ppx",
     # "ocaml_ppx_compile",
     # # "ocaml_ppx_apply",
     # "ocaml_ppx_library_gendeps",
     # "ocaml_ppx_library_cmo",
     # "ocaml_ppx_library_link"
)
load("@obazl//ocaml/private:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "split_srcs",
     "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

# print("private/ocaml.bzl loading")

################################################################
#### compile after preprocessing:
def _ocaml_ppx_library_with_ppx_impl(ctx):
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  if ctx.attr.preprocessor:
    if PpxInfo in ctx.attr.preprocessor:
      new_intf_srcs, new_impl_srcs = apply_ppx(ctx, env)
  else:
    new_intf_srcs, new_impl_srcs = split_srcs(ctx.files.srcs)

  tc = ctx.toolchains["@obazl//ocaml:toolchain"]

  lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  #################################################
  outfiles_cmi, outfiles_cmx, outfiles_o = compile_native_with_ppx(
    ctx, env, tc, new_intf_srcs, new_impl_srcs
  )

  # #################################################
  # ## 5. Link .cmxa
  # outfiles_cmi, outfiles_cmx, outfiles_o = link_native(
  #   ctx, env, tc, new_intf_srcs, new_impl_srcs
  # )

  outfile_cmxa_name = ctx.label.name + ".cmxa"
  outfile_cmxa = ctx.actions.declare_file(outfile_cmxa_name)
  outfile_a_name = ctx.label.name + ".a"
  outfile_a = ctx.actions.declare_file(outfile_a_name)
  args = ctx.actions.args()
  # args.add("ocamlopt")
  args.add("-w", WARNING_FLAGS)
  args.add("-strict-sequence")
  args.add("-strict-formats")
  args.add("-short-paths")
  args.add("-keep-locs")
  args.add("-g")
  args.add("-a")

  # args.add("-linkpkg")
  # args.add_all([dep[OpamPkgInfo].pkg for dep in ctx.attr.deps],
  #              before_each ="-package")
  # for dep in ctx.attr.deps:
  #   if OpamPkgInfo in dep:
  #     args.add("-package", dep[OpamPkgInfo].pkg)
  #   else:
  #     args.add(dep[PpxInfo].cmx)

  args.add("-o", outfile_cmxa)

  args.add("-linkall")
  args.add_all(outfiles_cmx)
  # args.add_all(outfiles_o)
  #################################################
  # ocaml_ppx_library_link(ctx,
  #                        env = env,
  #                        pgm = tc.ocamlopt,
  #                        # pgm = tc.ocamlfind,
  #                        args = [args],
  #                        inputs = outfiles_cmx + outfiles_o,
  #                        outputs = [outfile_cmxa, outfile_a],
  #                        tools = [tc.ocamlfind, tc.ocamlc],
  #                        msg = ctx.attr.message
  # )
  ctx.actions.run(
    env = env,
    executable = tc.ocamlopt,
    arguments = [args],
    inputs = outfiles_cmx + outfiles_o,
    outputs = [outfile_cmxa, outfile_a],
    tools = [tc.ocamlfind, tc.ocamlc],
    mnemonic = "OcamlPPXLibrary",
    progress_message = "ocaml_ppx_library({}): {}".format(
      ctx.label.name,
      ctx.attr.message,
      )
  )

  return [
    DefaultInfo(
    files = depset(direct = [#outfile_ppml,
                             #outfile_cmo,
                             # outfile_o,
                             # outfile_cmx,
                             outfile_a,
                             outfile_cmxa
    ])),
    PpxInfo(ppx=outfile_cmxa,
            # cmo=outfile_cmo,
            # cmx=outfile_cmx,
            cmxa=outfile_cmxa,
            a=outfile_a
    )]

################################################################
#### Compile/link without preprocessing.
#### WARNING: this impl is sequential; it passes all source files to
#### one action, which will compile them (presumably in sequence) and
#### then link.
def _ocaml_ppx_archive_impl(ctx):
  ## this is essentially the same as ocaml_library, but it returns a
  ## ppx provider. should unify them?

  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  tc = ctx.toolchains["@obazl//ocaml:toolchain"]

  lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  ## declare outputs
  # obj_files = []

  if "-linkpkg" in ctx.attr.opts:
    fail("-linkpkg option not supported for ocaml_ppx_archive rule")

  if ctx.attr.archive_name:
    outfile_cmxa_name = ctx.attr.archive_name + ".cmxa"
  else:
    outfile_cmxa_name = ctx.label.name + ".cmxa"

  obj_cmxa = ctx.actions.declare_file(outfile_cmxa_name)

  args = ctx.actions.args()
  args.add("ocamlopt")
  args.add_all(ctx.attr.flags)
  args.add_all(ctx.attr.opts)

  if ctx.attr.linkall:
    args.add("-linkall")

  # a ppx_archive is always cmxa
  args.add("-a")
  # if "-a" in ctx.attr.opts:
    # args.add("-open")
    # args.add("Ppx_snarky__Wrapper")
  args.add("-o", obj_cmxa)

  ## We insert -I for each non-opam dep; since this would usually
  ## result in duplicates, we accumulate them first, then dedup.
  includes = []
  for dep in ctx.attr.deps:
    if not OpamPkgInfo in dep:
      for g in dep[DefaultInfo].files.to_list():
        if g.path.endswith(".cmx"):
          includes.append(g.dirname)
        if g.path.endswith(".cmxa"):
          includes.append(g.dirname)

  args.add_all(includes, before_each="-I", uniquify = True)

  #### WARNING!!! ####
  # For linking with redirector modules (module aliases), it is not
  # enough to add libs to the command line (by adding to args). They
  # must also be added to the 'inputs' parameter of the Bazel action;
  # if we don't do this, Bazel will not make them accessible, and we
  # will get 'Error: Unbound module'. So we accumulate them in
  # build_deps, then add them to inputs_arg we pass to the run action.
  build_deps = []

  for dep in ctx.attr.deps:
    if OpamPkgInfo in dep:
      args.add("-package", dep[OpamPkgInfo].pkg)
    else:
      for g in dep[DefaultInfo].files.to_list():
        # if g.path.endswith(".cmi"):
        #   build_deps.append(g)
        if g.path.endswith(".cmx"):
          # args.add("-I", g.dirname)
          args.add(g)
          build_deps.append(g)
        if g.path.endswith(".cmxa"):
          # args.add("-I", g.dirname)
          args.add(g)
          build_deps.append(g)
        # if g.path.endswith(".o"):
        #   build_deps.append(g)
        # if g.path.endswith(".cmxa"):
        #   build_deps.append(g)
        #   args.add(g) # dep[DefaultInfo].files)
        # else:
        #   args.add(g) # dep[DefaultInfo].files)

  # args.add_all(build_deps)

  # print("DEPS")
  # print(build_deps)

  args.add_all(ctx.files.srcs)

  inputs_arg = ctx.files.srcs + build_deps

  # print("INPUT_ARGS:")
  # print(inputs_arg)

  outputs_arg = [obj_cmxa]
  # print("OUTPUTS_ARG:")
  # print(outputs_arg)

  # print("ARGS: ")
  # print(args)

  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = inputs_arg,
    outputs = outputs_arg,
    tools = [tc.ocamlfind, tc.ocamlopt],
    mnemonic = "OcamlPpxLibrary",
    progress_message = "ocaml_ppx_archive({}): {}".format(
        ctx.label.name, ctx.attr.message
      )
  )

  return [
    DefaultInfo(
    files = depset(direct = [obj_cmxa]
    )),
    PpxInfo(ppx=obj_cmxa,
            # cmo=outfile_cmo,
            # cmx=outfile_cmx,
            # cmxa=obj_cmxa,
            # a=obj_a
    )]

#############################################
#### RULE DECL:  OCAML_PPX_ARCHIVE  #########
ocaml_ppx_archive = rule(
  implementation = _ocaml_ppx_archive_impl,
  attrs = dict(
    archive_name = attr.string(),
    preprocessor = attr.label(
      providers = [PpxInfo],
      executable = True,
      cfg = "exec",
      # allow_single_file = True
    ),
    message = attr.string(),
    dump_ast = attr.bool(default = True),
    srcs = attr.label_list(
      allow_files = OCAML_FILETYPES
    ),
    # src_root = attr.label(
    #   allow_single_file = True,
    #   mandatory = True,
    # ),
    ####  OPTIONS  ####
    ##Flags. We set some flags by default; these params
    ## allow user to override.
    flags = attr.string_list(
      default = [
        "-strict-sequence",
        "-strict-formats",
        "-short-paths",
        "-keep-locs",
        "-g",
        "-no-alias-deps",
        "-opaque"
  ]
    ),
    ## Problem is, this target registers two actions,
    ## compile and link, and each has its own params.
    ## for now, these affect the compile action:
    strict_sequence         = attr.bool(default = True),
    compile_strict_sequence = attr.bool(default = True),
    link_strict_sequence    = attr.bool(default = True),
    strict_formats          = attr.bool(default = True),
    short_paths             = attr.bool(default = True),
    keep_locs               = attr.bool(default = True),
    opaque                  = attr.bool(default = True),
    no_alias_deps           = attr.bool(default = True),
    debug                   = attr.bool(default = True),
    linkall                 = attr.bool(default = False),
    ## use these to pass additional args
    opts                   = attr.string_list(),
    linkopts                = attr.string_list(),
    warnings                = attr.string(
      default               = "@1..3@5..28@30..39@43@46..47@49..57@61..62-40"
    ),
    #### end options ####
    deps = attr.label_list(),
    mode = attr.string(default = "native"),
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    # outputs = attr.output_list(
    #   # default = ["%{name}.pp.ml",
    #   #           "%{name}.pp.ml.d"],
    # )
  ),
  # provides = [DefaultInfo, OutputGroupInfo, PpxInfo],
  executable = False,
  toolchains = ["@obazl//ocaml:toolchain"],
  # outputs = { "build_dir": "_build_%{name}" },
)
