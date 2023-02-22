load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "OcamlExecutableMarker",
     )
# load("//ocaml:providers.bzl", "PpxExecutableMarker") #, "PpxPrintSettingMarker")
# load("//ocaml/_functions:utils.bzl",
#      "get_sdkpath")

load(":impl_common.bzl", "tmpdir")

# tmpdir = "_obazl_/"

ppxdir = "__ppx/"

################################################################
def impl_ppx_transform(rule, ctx, srcfile, dst):
    """Apply a PPX to source file.

    Inputs: rule, context, srcfile
    Outputs: struct(intf :: declared File, maybe impl :: declared File)
    """

    debug = False

    if debug:
        print()
        print("impl_ppx_transform: {src} to {dst}".format(
            src = src, dst = dst))

    # To deal with generated runtime data files (ppx_data) we need
    # both the src file and the runtime files in the same dir, so we
    # must symlink both to the workdir. Since the output file will
    # have the same name as the (orignal) input file, we link the
    # latter into the workdir, inserting '.pp.'.

    ## NO - that won't work because some tests will write the name of
    ## the source file into their output, and the expected output
    ## will not have the '.pp.' infix.

    ## So instead ...?

    # Below we will symlink
    # the ppx_data files to the same workdir. (Evidently ppx_optcomp
    # will always look for data files relative to the src file dir.)

    (srcname, srcext) = paths.split_extension(srcfile.basename)

    # src = ctx.actions.declare_file(tmpdir + srcname + ".ppx" + srcext)
    src = ctx.actions.declare_file(ppxdir + srcfile.basename)
    ctx.actions.symlink(output = src, target_file = srcfile)

    # src = srcfile

    outfile = ctx.actions.declare_file(tmpdir + dst)
    outputs = {"impl": outfile}

    # env = {"PATH": get_sdkpath(ctx)}

    verbose = False
    if ctx.attr._verbose[BuildSettingInfo].value:
        if not "-no-verbose" in ctx.attr.opts:
            verbose = True
    elif "-verbose" in ctx.attr.opts:
            verbose = True

    ################################################################
    args = ctx.actions.args()

    # if ctx.attr.ppx: # isn't this always true here?
      # args.add_all(ctx.attr.ppx[PpxExecutableMarker].args)
      # args.add_all(ctx.attr.ppx[OcamlExecutableMarker].args)

    ## FIXME: support -no-dump-ast flag

    if hasattr(ctx.attr, "ppx_print"):
        # rule == ocaml_module, ocaml_signature
        if ctx.attr.ppx_print[BuildSettingInfo].value == "binary":
            if hasattr(ctx.attr, "args"):
                if "-no-dump-ast" in ctx.attr.args:
                    fail("cannot have both text and binary ppx output")
            if "-dump-ast" not in ctx.attr.ppx_args: ## opts: # avoid dup
                args.add("-dump-ast")
        else: # "print:text"
            ## explicit binary option overrides ppx_print attrib
            if "-dump-ast" in ctx.attr.ppx_args:  #  opts:
                args.add("-dump-ast")
    else:
        # rule == ppx_transform, has attr 'print'
        if ctx.attr.print[BuildSettingInfo].value == "binary":
            if "-no-dump-ast" not in ctx.attr.args:
                if "-dump-ast" not in ctx.attr.args: ## avoid dup
                    args.add("-dump-ast")
        else: # "print:text"
            ## explicit binary option overrides ppx_print attrib
            if "-dump-ast" in ctx.attr.args:
                args.add("-dump-ast")
            ## else: default is text output

    if hasattr(ctx.attr, "ppx_args"):
        # rule == ocaml_module, ocaml_signature
        args.add_all(ctx.attr.ppx_args)
    elif hasattr(ctx.attr, "args"):
        cli_args = []
        cli_args.extend(ctx.attr.args)
        if "-no-dump-ast" in ctx.attr.args:
            cli_args.remove("-no-dump-ast")
        args.add_all(cli_args)

    ## ppx does not accept -I
    # args.add("-I", "bazel-out/darwin-fastbuild/bin")

    args.add("-o", outfile.path)

    if src.path.endswith(".mli"):
        args.add("-intf", src.path)
    elif src.path.endswith(".ml"):
        args.add("-impl", src.path)

    action_inputs = [src]

    # if deps contains inline-tests add "-inline-test-lib {{ctx.attr.ppx_tags}}"
    ## OBSOLETE. User must pass these in ppx_args or args attr
    ## FIXME: this makes rules_ocaml dependent on a particular ocaml
    ## lib. Find a better way.
    # if "@opam//pkg:ppx_inline_test" in ctx.files.deps:
    # if hasattr(ctx.attr, "ppx_tags"):
    #     if len(ctx.attr.ppx_tags) > 0:
    #         args.add("--cookie", "library=" + ctx.attr.ppx_tags[0])
    #         args.add("-inline-test-lib", ctx.attr.ppx_tags[0]) # FIXME

    ## OBSOLETE: shell cmd
    ## construct shell command
    # parent = src.dirname
    # RUNTIME_FILES = ""

    ## If file is generated, the ppx won't find it since its in a
    ## bazel subdir, e.g. bazel-out/darwin-fastbuild/bin/... Ppx exe's
    ## do not support -I, so we need to find a way. One way is to
    ## revert to using a shell script to run the ppx, so we can set
    ## its runfiles. To use ctx.actions.run, we need to put the
    ## structfile and the runtime data files in the same dir. Above we
    ## symlinnked structfile foo.ml to __ppx/foo.ml; here, we
    ## symlink the ppx_data files to the same workdir.


    if hasattr(ctx.attr, "ppx_data"):
        if len(ctx.attr.ppx_data) > 0:
            for f in ctx.files.ppx_data:
                tmpfile = ctx.actions.declare_file(ppxdir + f.basename)
                ctx.actions.symlink(output = tmpfile, target_file = f)
                # print("TMPF: %s" % tmpfile.path)
                # fail()
                action_inputs.append(tmpfile) #(f)
    #             fname_len = len(f.basename)
    #             datafile_parent = f.short_path[:-fname_len]
    #             RUNTIME_FILES = RUNTIME_FILES + "\n".join([
    #                     "if [ ! \\( -f {tmpdir}{parent}/{rtf} \\) ]".format(tmpdir=tmpdir,
    #                                                               parent = datafile_parent,
    #                                                               rtf = f.basename),
    #                     "then",
    #                     "    mkdir -p {v} {tmpdir}{parent}".format(v = "-v" if verbose else "",
    #                                                             tmpdir=tmpdir,
    #                                                             parent=datafile_parent),
    #                     "    cp {v} {rtf} {tmpdir}{parent}".format(v = "-v" if verbose else "",
    #                                                             rtf = f.path,
    #                                                             tmpdir=tmpdir,
    #                                                             parent = datafile_parent),
    #                     "fi"
    #                 ])

    # MKDIR = "mkdir -p {v} {tmpdir}{path}".format(v = "-v" if verbose else "",
    #                                           tmpdir=tmpdir,
    #                                           path = parent)
    # COPY = "cp {v} {outfile} {tmpdir}{path}{renamed}".format(
    #     v = "-v" if verbose else "",
    #     outfile = src.path,
    #     tmpdir = tmpdir,
    #     path = parent,
    #     renamed = "/"
    #     # renamed = "/" + to
    # )
    # CHDIR = "cd {tmp}".format(tmp = tmpdir)

    # ppx attrib may be: 1) built by ppx_executable; or 2) imported precompiled exe file
    if ctx.executable.ppx:
        ppx_exe = ctx.executable.ppx
        action_inputs.extend(ctx.attr.ppx[DefaultInfo].default_runfiles.files.to_list())
    else:
        ppx_exe = ctx.file.ppx

    # print("PPX_EXE: %s" % ppx_exe)

    ## FIXME: handle runfiles
    # print("PPX data_runfiles: %s" % ctx.attr.ppx[DefaultInfo].data_runfiles.files)
    # print("PPX default_runfiles: %s" % ctx.attr.ppx[DefaultInfo].default_runfiles.files)
    # for f in ctx.attr.ppx[DefaultInfo].default_runfiles.files.to_list():
    #     print("rf: %s" % f.path)
    # fail("xxxxxxxxxxxxxxxx")

    # if (tmpdir == ""):
    #     command = "\n".join([
    #         RUNTIME_FILES,
    #         "{exe} $@".format(exe = ppx_exe.path) #ctx.executable.ppx.path)
    #     ])
    # else:
    #     command = "\n".join([
    #         "#!/bin/sh",
    #         "set {set}".format(set = "-x" if ctx.attr.ppx_verbose else "+x"),
    #         "{mkdir}".format(mkdir = MKDIR if (tmpdir != "") else ""),
    #         RUNTIME_FILES,
    #         ## copy source to tmp dir for processing. a softlink won't work here.
    #         "{copy}".format(copy = COPY if (tmpdir != "") else ""),
    #         "{chdir}".format(chdir= CHDIR if (tmpdir != "") else ""),
    #         # "ls src/lib_stdlib",
    #         "{exe} $@".format(exe = "../" + ppx_exe.path), # ctx.executable.ppx.path),
    #         "cd .."
    #     ])

    ##FIXME: use same sh script for both files, when module has both
    ##sig and struct files
    # runner = ctx.actions.declare_file(ctx.attr.name + ".{}_ppx.sh".format(
    #     "mli" if src.path.endswith(".mli") else "ml"
    # ))

    # if debug:
    #     print("Writing RUNNER file: %s" % runner)
    #     print("\n%s" % command)

    ctx.actions.run(
        executable = ppx_exe,
        arguments  = [args],
        inputs = action_inputs,
        outputs = [outfile],
        tools = [ppx_exe],
        mnemonic = "OcamlPpxTransform",
        progress_message = "ppx_transform {rule}: {ws}//{pkg}:{tgt}".format(
            ws  = "@" + ctx.label.workspace_name if ctx.label.workspace_name else "", ## ctx.workspace_name,
            pkg = ctx.label.package,
            rule=ctx.attr._rule,
            tgt=ctx.label.name,
        )
    )
    # ctx.actions.write(
    #     output  = runner,
    #     content = command,
    #     is_executable = True,
    # )

    # ctx.actions.run(
    #     # env = env,
    #     executable = runner,
    #     arguments = [args],
    #     inputs = action_inputs,
    #     outputs = [outfile],
    #     tools = [ppx_exe], # [ctx.executable.ppx],
    #     mnemonic = "OCamlPpxTransform",
    #     progress_message = "ppx_transform {rule}: {ws}//{pkg}:{tgt}".format(
    #         ws  = "@" + ctx.label.workspace_name if ctx.label.workspace_name else "", ## ctx.workspace_name,
    #         pkg = ctx.label.package,
    #         rule=ctx.attr._rule,
    #         tgt=ctx.label.name,
    #     )
    # )

    return outfile
