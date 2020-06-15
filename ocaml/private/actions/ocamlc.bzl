  #################################################
  # 3. Compile .cmo
  # cmo_outfiles = compile_cmo(env, ctx, new_srcs)
  # outfile_cmo_name = ctx.label.name + ".cmo"
  # outfile_cmo = ctx.actions.declare_file(outfile_cmo_name)
  # args = ctx.actions.args()
  # args.add("ocamlc")
  # args.add("-w", WARNING_FLAGS)
  # args.add("-strict-sequence")
  # args.add("-strict-formats")
  # args.add("-short-paths")
  # args.add("-keep-locs")
  # args.add("-g")
  # args.add("-linkall")
  # args.add("-bin-annot")

  # # -I stuff:
  # # ocamldeps reports: Ast_builder Base Deriving List Ppxlib
  # # but Ast_builder and deriving are in ppxlib, List is in base
  # # We require user to explicitly list such deps
  # # args.add_all([dep[OpamPkgInfo].pkg for dep in ctx.attr.deps],
  # #              before_each ="-package")
  # for dep in ctx.attr.deps:
  #   if OpamPkgInfo in dep:
  #     args.add("-package", dep[OpamPkgInfo].pkg)
  #   else:
  #     args.add(dep[PpxInfo].cmxa)

  # args.add("-no-alias-deps")
  # args.add("-opaque")

  # args.add("-o", outfile_cmo)
  # args.add("-c")
  # args.add("-impl", outfile_ppml)
  # #################################################

  # print("OUTFILE_PPML:")
  # print(outfile_ppml)

  # ocaml_ppx_library_cmo(ctx,
  #                       env = env,
  #                       pgm = tc.ocamlfind,
  #                       args = [args],
  #                       inputs = [outfile_ppml], # inputs,
  #                       outputs = [outfile_cmo],
  #                       tools = [tc.ocamlfind, tc.ocamlc]
  # )

