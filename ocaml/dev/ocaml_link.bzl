#############################################
#### RULE DECL:  OCAML_LIBRARY_DEV  #########
#############################################
def _ocaml_library_dev_impl(ctx):
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
  outfiles_cmi, outfiles_cmx, outfiles_o = compile_native(
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
  ocaml_ppx_library_link(ctx,
                         env = env,
                         pgm = tc.ocamlopt,
                         # pgm = tc.ocamlfind,
                         args = [args],
                         inputs = outfiles_cmx + outfiles_o,
                         outputs = [outfile_cmxa, outfile_a],
                         tools = [tc.ocamlfind, tc.ocamlc],
                         msg = "_ocaml_ppx_library_impl"
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
ocaml_library_dev = rule(
  implementation = _ocaml_library_dev_impl,
  attrs = dict(
    preprocessor = attr.label(
      providers = [PpxInfo],
      executable = True,
      cfg = "exec",
      # allow_single_file = True
    ),
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
    ## use these to pass additional args
    copts                   = attr.string_list(),
    linkopts                = attr.string_list(),
    warnings                = attr.string(
      default               = "@1..3@5..28@30..39@43@46..47@49..57@61..62-40"
    ),
    #### end options ####
    deps = attr.label_list(),
    mode = attr.string(default = "native"),
    _sdkpath = attr.label(
      default = Label("@ocaml_sdk//:path")
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
