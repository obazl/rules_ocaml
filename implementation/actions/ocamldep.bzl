  # 2. Run ocampldep on <outfile>.pp.ml, generating <outfile>.depends
  #    Uses ctx.actions.run_shell
  # cmd = "ocamldep" + " -modules -impl $1 > $2"
  # outfile_ppml_deps_name = ctx.label.name + ".depends"

  ## NOTE: WE DO NOT NEED THIS. ocamlbuild etc. use ocamldep to
  ## automate dep discovery; we require users to explicitly list deps.
  ## But we keep this around, later we can write a deps rule of some kind.

  # outfile_ppml_deps = ctx.actions.declare_file(outfile_ppml_deps_name)
  # args = ctx.actions.args()
  # args.add(outfile_ppml.path)
  # args.add(outfile_ppml_deps.path)

  # ocaml_ppx_library_gendeps(ctx,
  #                           env,
  #                           cmd,
  #                           [args],
  #                           [outfile_ppml], # inputs,
  #                           [outfile_ppml_deps], # ctx.outputs.executable], # outputs
  #                           [tc.ocamldep]
  # )

