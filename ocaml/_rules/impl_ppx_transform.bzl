load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "OcamlExecutableMarker",
     "OcamlVerboseFlagProvider"
     )
# load("//ocaml:providers.bzl", "PpxExecutableMarker") #, "PpxPrintSettingMarker")
# load("//ocaml/_functions:utils.bzl",
#      "get_sdkpath")

load(":impl_common.bzl", "tmpdir")

# tmpdir = "_obazl_/"

################################################################
def impl_ppx_transform(rule, ctx, src, to):
    """Apply a PPX to source file.

    Inputs: rule, context, src
    Outputs: struct(intf :: declared File, maybe impl :: declared File)
    """

    debug = False # True
    # if ctx.label.name == "test":
    #     debug = True

    if debug:
        print()
        print("Start: impl_ppx_transform: {src} to {dst}".format(src = src, dst = to))

    # scope = tmpdir

    outfile = ctx.actions.declare_file(tmpdir + to)
    outputs = {"impl": outfile}

    # env = {"PATH": get_sdkpath(ctx)}

    verbose = False
    if ctx.attr._verbose[OcamlVerboseFlagProvider].value:
        if not "-no-verbose" in ctx.attr.opts:
            verbose = True
    elif "-verbose" in ctx.attr.opts:
            verbose = True

    ################################################################
    args = ctx.actions.args()

    if ctx.attr.ppx: # isn't this always true here?
      # args.add_all(ctx.attr.ppx[PpxExecutableMarker].args)
      # args.add_all(ctx.attr.ppx[OcamlExecutableMarker].args)
      args.add_all(ctx.attr.ppx_args)
      if hasattr(ctx.attr, "ppx_print"):
          if ctx.attr.ppx_print[BuildSettingInfo].value == "binary":
              # binary == '-dump-ast'
              if "-dump-ast" not in ctx.attr.opts: # avoid dup
                  args.add("-dump-ast")
          else: # "print:text"
              ## explicit binary option overrides ppx_print attrib
              if "-dump-ast" in ctx.attr.opts:
                  args.add("-dump-ast")

    ## in our shell script, we cd to _obazl_/ before executing this, so we need "../"
    ## shell script copies src to _obazl_/, cds there, then runs the ppx
    if tmpdir == "":
        args.add("-o", outfile.path)
    else:
        args.add("-o", "../" + outfile.path)
    if src.path.endswith(".mli"):
        args.add("-intf", src.path)
    elif src.path.endswith(".ml"):
        args.add("-impl", src.path)

    dep_graph = [src]

    # if deps contains inline-tests add "-inline-test-lib {{ctx.attr.ppx_tags}}"
    ## FIXME: this makes rules_ocaml dependent on a particular ocaml
    ## lib. Find a better way.
    # if "@opam//pkg:ppx_inline_test" in ctx.files.deps:
    if hasattr(ctx.attr, "ppx_tags"):
        if len(ctx.attr.ppx_tags) > 0:
            args.add("--cookie", "library=" + ctx.attr.ppx_tags[0])
            args.add("-inline-test-lib", ctx.attr.ppx_tags[0]) # FIXME

    ## construct shell command
    parent = src.dirname
    RUNTIME_FILES = ""
    if hasattr(ctx.attr, "ppx_data"):
        if len(ctx.attr.ppx_data) > 0:
            for f in ctx.files.ppx_data:
                dep_graph.append(f)
                fname_len = len(f.basename)
                datafile_parent = f.short_path[:-fname_len]
                RUNTIME_FILES = RUNTIME_FILES + "\n".join([
                        "if [ ! \\( -f {tmpdir}{parent}/{rtf} \\) ]".format(tmpdir=tmpdir,
                                                                  parent = datafile_parent,
                                                                  rtf = f.basename),
                        "then",
                        "    mkdir -p {v} {tmpdir}{parent}".format(v = "-v" if verbose else "",
                                                                tmpdir=tmpdir,
                                                                parent=datafile_parent),
                        "    cp {v} {rtf} {tmpdir}{parent}".format(v = "-v" if verbose else "",
                                                                rtf = f.path,
                                                                tmpdir=tmpdir,
                                                                parent = datafile_parent),
                        "fi"
                    ])

    MKDIR = "mkdir -p {v} {tmpdir}{path}".format(v = "-v" if verbose else "",
                                              tmpdir=tmpdir,
                                              path = parent)
    COPY = "cp {v} {outfile} {tmpdir}{path}{renamed}".format(
        v = "-v" if verbose else "",
        outfile = src.path,
        tmpdir = tmpdir,
        path = parent,
        renamed = "/"
        # renamed = "/" + to
    )
    CHDIR = "cd {tmp}".format(tmp = tmpdir)
    if (tmpdir == ""):
        command = "\n".join([
            RUNTIME_FILES,
            "{exe} $@".format(exe = ctx.executable.ppx.path)
        ])
    else:
        command = "\n".join([
            "#!/bin/sh",
            "set {set}".format(set = "-x" if ctx.attr.ppx_verbose else "+x"),
            "{mkdir}".format(mkdir = MKDIR if (tmpdir != "") else ""),
            RUNTIME_FILES,
            ## copy source to tmp dir for processing. a softlink won't work here.
            "{copy}".format(copy = COPY if (tmpdir != "") else ""),
            "{chdir}".format(chdir= CHDIR if (tmpdir != "") else ""),
            # "ls src/lib_stdlib",
            "{exe} $@".format(exe = "../" + ctx.executable.ppx.path),
            "cd .."
        ])

    runner = ctx.actions.declare_file(ctx.attr.name + "_ppx.sh")

    if debug:
        print("Writing RUNNER file: %s" % runner)
        print("\n%s" % command)

    ctx.actions.write(
        output  = runner,
        content = command,
        is_executable = True,
    )

    ctx.actions.run(
        # env = env,
        executable = runner,
        arguments = [args],
        inputs = dep_graph,
        outputs = [outfile],
        tools = [ctx.executable.ppx],
        mnemonic = "PpxTransformAction",
        progress_message = "ppx_transform {rule}: {ws}//{pkg}:{tgt}".format(
            ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
            pkg = ctx.label.package,
            rule=ctx.attr._rule,
            tgt=ctx.label.name,
        )
    )

    return outfile
