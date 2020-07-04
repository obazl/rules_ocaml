load("//ocaml/private:utils.bzl",
     "WARNING_FLAGS"
)
load("//ocaml/private/actions:ocaml.bzl",
     "ocaml_compile")
load("//ocaml/private:providers.bzl",
     # "OcamlSDK",
     # "OpamPkgInfo",
     "PpxInfo")

def ocaml_ppx_compile(ctx, env, pgm, args, inputs, outputs, tools,
                      msg):
  ctx.actions.run(
      env = env,
      executable = pgm,
      arguments = args,
      inputs = inputs,
      outputs = outputs,
      # tools = tools,
      # use_default_shell_env = True,
      mnemonic = "OcamlPPXCompile",
      progress_message = "ocaml_ppx_compile {}: {}".format(
        msg, ctx.label.name
      )
  )

# Running[3]: (cd _build/default && .ppx/0224ad3443a846e54f1637fccb074e7d/ppx.exe --cookie 'library-name="deriving_hello"' -o deriving-hello/src/deriving_hello.pp.ml --impl deriving-hello/src/deriving_hello.ml --dump-ast)

def ocaml_ppx_apply(ctx, env, pgm, args, inputs, outputs, tools,
                    progress_message):
  """Apply a ppx executable to source files."""
  ctx.actions.run(
      env = env,
      executable = pgm,
      arguments = args,
      inputs = inputs,
      outputs = outputs,
      tools = tools,
      use_default_shell_env = True,
      mnemonic = "OcamlPPXDeriverPpml",
      progress_message = "ocaml_ppx_apply {}: {}".format(
        progress_message, ctx.label.name),
  )

  # 2. Generate deps.  The ocamldep command scans a set of OCaml
  # source files (.ml and .mli files) for references to external
  # compilation units, and outputs dependency lines.
  # ocamldep.opt -modules -impl <in>.pp.ml) > <out>.pp.ml.d
def ocaml_ppx_library_gendeps(ctx, env, cmd, args, inputs, outputs, tools):
  ctx.actions.run_shell(
    env = env,
    inputs = inputs,
    tools = tools,
    outputs = outputs,
    command = cmd,
    arguments = args,
    mnemonic = "OcamlPpxDeriverGenDeps",
    progress_message = "ocaml_ppx_library_gendeps: %s" % ctx.label.name,
  )

################################################################
# Step 3: build *.cmo
# /Users/gar/.opam/4.07.1/bin/ocamlc.opt
# -w @1..3@5..28@30..39@43@46..47@49..57@61..62-40
# -strict-sequence
# -strict-formats
# -short-paths
# -keep-locs
# -g
# -bin-annot
# -I
# -no-alias-deps
# -opaque
# -o deriving-hello/src/.deriving_hello.objs/byte/deriving_hello.cmo
# -c
# -impl deriving-hello/src/deriving_hello.pp.ml

def ocaml_ppx_library_cmo(ctx, env, pgm, args, inputs, outputs, tools):
  ctx.actions.run(
      env = env,
      executable = pgm,
      arguments = args,
      inputs = inputs,
      outputs = outputs,
      tools = tools,
      mnemonic = "OcamlPPXCompileCmo",
      progress_message = "ocaml_ppx_library_cmo: %s" % ctx.label.name,
  )


def ocaml_ppx_library_compile(ctx, env, pgm, args, inputs, outputs, tools,
                              msg):
  ctx.actions.run(
      env = env,
      executable = pgm,
      arguments = args,
      inputs = inputs,
      outputs = outputs,
      tools = tools,
      mnemonic = "OcamlPPXLibraryCompile",
      progress_message = "ocaml_ppx_library_compile {}: {}".format(
        msg, ctx.label.name
      )
  )

################################################################
# Step 5: build *.cmxa
# ocamlopt.opt
# -w @1..3@5..28@30..39@43@46..47@49..57@61..62-40
# -strict-sequence
# -strict-formats
# -short-paths
# -keep-locs
# -g
# -a
# -o deriving-hello/src/deriving_hello.cmxa
# -linkall
# deriving-hello/src/.deriving_hello.objs/native/deriving_hello.cmx)

def ocaml_ppx_library_link(ctx, env, pgm, args, inputs, outputs, tools,
                           msg):
  ctx.actions.run(
      env = env,
      executable = pgm,
      arguments = args,
      inputs = inputs,
      outputs = outputs,
      tools = tools,
      mnemonic = "OcamlPPXCompileCmxa",
      progress_message = "ocaml_ppx_library_link {}: {}".format(
        msg, ctx.label.name
      )
  )

################################################################
################################################################
def apply_ppx(ctx, env):
  ppx = ctx.attr.preprocessor[PpxInfo].ppx
  interfaces = []
  implementations = []
  for f in ctx.files.srcs:

    ## NOTE: we do not need to change the name of the output file -
    ## the output directory of this action is the sandbox, not the
    ## source tree, so declaring a file of the same name does not clash.
    # outfile = ctx.actions.declare_file("ppx6376cb09/" + f.basename)
    outfile = ctx.actions.declare_file(f.basename)
    args = ctx.actions.args()
    args.add("--cookie", "library-name={}".format(ctx.label.name))
    args.add("-o", outfile)
    if f.extension == "ml":
      args.add("--impl", f)
      implementations.append(outfile)
    if f.extension == "mli":
      args.add("--intf", f)
      interfaces.append(outfile)
    # if ctx.attr.dump_ast:
    # args.add("--dump-ast")

    ocaml_ppx_apply(ctx,
                    env = env,
                    pgm = ppx,
                    args = [args],
                    inputs = [f],
                    outputs = [outfile],
                    tools = [ppx],
                    progress_message = "apply_ppx"
    )
  return interfaces, implementations

################################################################
def compile_new_srcs(ctx, env, toolchain, new_intfs, new_impls):
  print("COMPILE_NEW_SRCS")
  # Called after apply_ppx, to compile the transformed sources.
# Dune:
# ocamlopt.opt
# -w @1..3@5..28@30..39@43@46..47@49..57@61..62-40
# -strict-sequence -strict-formats -short-paths -keep-locs -g
# -I deriving-hello/test/.hello_world_test.eobjs/byte
# -I deriving-hello/test/.hello_world_test.eobjs/native
# -intf-suffix .ml
# -no-alias-deps
# -opaque
# -o deriving-hello/test/.hello_world_test.eobjs/native/hello_world_test.cmx
# -c
# -impl deriving-hello/test/hello_world_test.pp.ml)

  # Compile each source file separately (?)
  intf_outfiles = []
  impl_outfiles = []

  for f in new_intfs:
    args = ctx.actions.args()
    args.add("ocamlopt")
    args.add("-w", WARNING_FLAGS)
    args.add_all(["-strict-sequence", "-strict-formats", "-short-paths",
                  # "-keep-locs",
                  "-g", "-bin-annot"])


    # args.add("-intf-suffix", ".ml")
    # args.add("-no-alias-deps")
    args.add("-opaque")

    # if f.extension == "ml":
    #   outfile_name = f.dirname + "/" + f.basename.rstrip("ml") + "cmx"
    #   outfile = ctx.actions.declare_file(outfile_name)
    #   print("COMPILING PP INTERFACE FILE: " + outfile.path)
    #   args.add("-o", outfile.short_path)
    #   print("OUTFILE (CMX)")
    #   print(outfile)
    #   impl_outfiles.append(outfile)
    #   args.add("-c")
    #   args.add("-impl", f)
    if f.extension == "mli":
      outfile_name = f.basename.rstrip("mli") + "cmi"
      outfile = ctx.actions.declare_file(outfile_name)
      args.add("-I", f.dirname)
      args.add("-o", outfile)
      print("OUTFILE (CMI)")
      print(outfile)
      args.add("-c")
      args.add("-intf", f)
      intf_outfiles.append(outfile)

    ocaml_compile(ctx,
                  env = env,
                  pgm = toolchain.ocamlfind,
                  args = [args],
                  inputs = [f], # new_intfs + new_impls,
                  outputs = [outfile],
                  tools = [toolchain.ocamlopt],
                  progress_message = "compile_new_srcs (intfs)"
    )

  outfile = None
  for g in new_impls:
    print("COMPILING PP IMPLEMENTATION FILE: " + g.path)
    args = ctx.actions.args()
    args.add("ocamlopt")
    args.add("-w", WARNING_FLAGS)
    args.add_all(["-strict-sequence", "-strict-formats", "-short-paths",
                  # "-keep-locs",
                  "-g"])

    args.add("-I", g.dirname)

    args.add("-intf-suffix", ".ml")
    # args.add("-no-alias-deps")
    args.add("-opaque")
    # args.add_all(["-no-alias-deps", "-opaque"])

    if g.extension == ("ml"):
      outfile_name = g.basename.rstrip("ml") + "cmx"
      # outfile_name = g.dirname + "/" + g.basename.strip("ml") + "cmx"
      outfile = ctx.actions.declare_file(outfile_name)
      outfile_o = ctx.actions.declare_file(g.basename.rstrip("ml") + "o")
      args.add("-o", outfile)
      print("OUTFILE (CMX)")
      print(outfile)
      impl_outfiles.append(outfile)
      impl_outfiles.append(outfile_o)
      args.add("-c")
      args.add("-impl", g)
    # if g.path.endswith("mli"):
    #   outfile_name = g.path + ".cmi"
    #   outfile = ctx.actions.declare_file(outfile_name)
    #   args.add("-o", outfile)
    #   print("OUTFILE (CMI)")
    #   print(outfile)
    #   args.add("-c")
    #   args.add("--impl", g)
    #   intf_outfiles.append(outfile)

    ocaml_compile(ctx,
                  env = env,
                  pgm = toolchain.ocamlfind,
                  args = [args],
                  inputs = [g] + intf_outfiles,
                  outputs = [outfile, outfile_o],
                  tools = [toolchain.ocamlopt],
                  progress_message = "compile_new_srcs (impls)"
    )

  return intf_outfiles, impl_outfiles
