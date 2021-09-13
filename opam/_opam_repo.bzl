################################################################
def _build_re2c(repo_ctx):

    # Have we already built re2c? FIXME: check version
    repo_ctx.report_progress("Checking for cached re2c...")
    repo_ctx.file(
        "re2c.sh",
        content = "\n".join([
            "#!/bin/bash",
            "if [[ -x ${HOME}/.local/bin/re2c ]]; then",
            "    VERNUM=`${HOME}/.local/bin/re2c --vernum`",
            "    if [[ $VERNUM -eq \"020003\" ]]; then",
            "        echo \"re2c already built\"",
            "        exit 0",
            "    else",
            "        echo ${VERNUM}",
            "        exit -2",
            "    fi",
            "fi",
            "exit -1",
        ])
    )

    cmd = ["./re2c.sh"]
    xr = repo_ctx.execute(cmd)
    if xr.return_code == 0:
        # print("re2c already built")
        repo_ctx.report_progress("re2c already built...")
        return
    elif xr.return_code == 254:
        print("Found $HOME/.local/bin/re2c, vernum {VERNUM} - expected 02003".format(VERNUM = xr.stdout))
    # else:
    #     print("ls re2c rc: {rc}".format(rc=xr.return_code))
    #     print("ls re2c stderr: {stderr}".format(stderr=xr.stderr))
    #     print("ls re2c stdout: %s" % xr.stdout)
    #     print("re2c not found; building")

    repo_ctx.report_progress("... not found: building re2c.")

    # fail("test")

    repo_ctx.download_and_extract(
        "https://github.com/skvadrik/re2c/archive/2.0.3.zip",
        "re2c",
        stripPrefix = "re2c-2.0.3",
        sha256 = "8f74163d02b4ce371d69876af1610177b45055b387656d0fb22c3eab131ccbf9",
    )

    repo_ctx.file(
        "re2c.sh",
        content = "\n".join([
            "#!/bin/bash",
            "if [[ -x ${HOME}/.local/bin/re2c ]]; then",
            "    echo \"re2c already built\"",
            "    exit 0",
            "fi",
            "echo \"Buiding re2c...\"",
            "cd re2c",
            "autoreconf -i -W all",
            "echo \".configure...\"",
            "./configure",
            "echo \".make...\"",
            "make",
            "mkdir -p ${HOME}/.local/bin",
            "cp re2c ${HOME}/.local/bin",
            "cd -"
        ])
    )

    repo_ctx.report_progress("Building re2c (may take a while)...")

    cmd = ["./re2c.sh"]
    xr = repo_ctx.execute(cmd)
    if xr.return_code == 0:
        print("re2c autoreconf: %s" % xr.stdout)
    else:
        print("re2c autreconf rc: {rc}".format(rc=xr.return_code))
        print("re2c autoreconf stderr: {stderr}".format(stderr=xr.stderr))
        print("re2c autoreconf stdout: %s" % xr.stdout)
        fail("Comand failed: %s" % cmd)

    repo_ctx.delete("re2c.sh")

################################################################
def _build_opam_bootstrapper_local(repo_ctx):

    if "HOME" in repo_ctx.os.environ:
        home = repo_ctx.os.environ["HOME"]
    else:
        fail("HOME not in env.")

    local_bin = home + "/.local/bin"

    build_sh = repo_ctx.path(Label("@obazl_tools_opam//bootstrap:build.sh"))
    print("BUILD_SH: %s" % build_sh)

    build_dir = build_sh.dirname
    print("BUILD_DIR: %s" % build_dir)

    bootstrapper = build_dir.get_child("opam_bootstrap")
    print("checking for opam bootstrapper: %s" % bootstrapper)
    repo_ctx.report_progress("checking for opam bootstrapper:  %s" % bootstrapper)

    if bootstrapper.exists:
        repo_ctx.report_progress("found opam bootstrapper")
        print("found opam bootstrapper")
    else:
        cmd_env = {}
        cmd_env["SRCDIR"] = "%s" % build_dir
        cmd = [build_sh]

        print("building opam bootstrapper")
        repo_ctx.report_progress("building opam bootstrapper")
        cmd_env["RE2C"] = "{}/.local/bin/re2c".format(home)
        xr = repo_ctx.execute(cmd, environment=cmd_env)
        # if xr.return_code == 0:
            # print("make bootstrap_opam stdout: %s" % xr.stdout)
        if not xr.return_code == 0:
            print("make bootstrap_opam result: %s" % xr.stdout)
            print("make bootstrap_opam rc: {rc} stderr: {stderr}".format(rc=xr.return_code, stderr=xr.stderr));
            fail("Comand failed: make -C bootstrap_opam")

    if bootstrapper.exists:
        repo_ctx.report_progress("found opam bootstrapper")
    else:
        fail("Could not find opam_bootstrap executable")

    repo_ctx.report_progress("running opam bootstrapper")
    print("running opam_bootstrap")
    # bootstrapper = repo_ctx.path(Label("@obazl_tools_opam//bootstrap:opam_bootstrap"))
    print("BOOTSTRAP CMD: %s" % bootstrapper)

    # bootstrapper_dir = bootstrapper.dirname
    # print("BOOTSTRAPPER_DIR: %s" % bootstrapper_dir)

    # cmd_env = {}
    # cmd_env["SRCDIR"] = "%s" % build_dir
    cmd = [bootstrapper, "CFLAGS=-03"]

    xr = repo_ctx.execute(cmd) ## , environment=cmd_env)
    if xr.return_code == 0:
        if repo_ctx.attr.bootstrap_debug:
            # print("2 opam_bootstrap succeeded")
            print("opam_bootstrap stdout: %s\n" % xr.stdout)
            print("opam_bootstrap stderr: %s\n" % xr.stderr)
    elif xr.return_code != 0:
        print("ERROR: opam_bootstrap rc: %s" % xr.return_code)
        print("opam_bootstrap stdout: %s\n" % xr.stdout)
        print("opam_bootstrap stderr: %s\n" % xr.stderr)
        fail("opam_bootstrap failure")

    print("completed: build_opam_bootstrapper_local")
    repo_ctx.report_progress("Completed: build_opam_bootstrapper_local")

###################################
def _install_build_templates(repo_ctx):

    # repo_ctx.template(
    #     "BUILD.bazel",
    #     Label("//opam/_templates:BUILD.opam"),
    #     executable = False,
    # )

    ## FIXME: rename opam_config or similar
    repo_ctx.template(
        "cfg/BUILD.bazel",
        Label("//opam/_templates:BUILD.opam.cfg"),
        executable = False,
    )

    # repo_ctx.template(
    #     "cfg/mt/BUILD.bazel",
    #     Label("//opam/_templates:BUILD.opam.cfg.mt"),
    #     executable = False,
    # )

    # repo_ctx.template(
    #     "cfg/mt/posix/BUILD.bazel",
    #     Label("//opam/_templates:BUILD.opam.cfg.mt.posix"),
    #     executable = False,
    # )

    ## FIXME: ppx config rules - mv to @ppx
    repo_ctx.template(
        "ppx/BUILD.bazel",
        Label("//opam/_templates:BUILD.opam.ppx"),
        executable = False,
    )

    ## Special Cases. These are hacks, to get around the "virtual
    ## modules" problem until we find the time to handle them in the
    ## bootstrapper.

    repo_ctx.template(
        "lib/digestif/BUILD.bazel",
        Label("//opam/_templates/hacks:BUILD.opam.lib.digestif"),
        executable = False,
    )

    repo_ctx.template(
        "lib/digestif/c/BUILD.bazel",
        Label("//opam/_templates/hacks:BUILD.opam.lib.digestif_c"),
        executable = False,
    )

    repo_ctx.template(
        "lib/digestif/rakia/BUILD.bazel",
        Label("//opam/_templates/hacks:BUILD.opam.lib.digestif_rakia"),
        executable = False,
    )

    repo_ctx.template(
        "lib/bls12-381/BUILD.bazel",
        Label("//opam/_templates/hacks:BUILD.opam.lib.bls12-381"),
        executable = False,
    )

    ## these hacks are not related to virtual modules:
    repo_ctx.template(
        "lib/ptime/clock/os/BUILD.bazel",
        Label("//opam/_templates/hacks:BUILD.opam.lib.ptime.clock.os"),
        executable = False,
    )

    repo_ctx.template(
        "lib/threads/BUILD.bazel",
        Label("//opam/_templates/hacks:BUILD.opam.lib.threads"),
        executable = False,
    )

    repo_ctx.template(
        "lib/threads/posix/BUILD.bazel",
        Label("//opam/_templates/hacks:BUILD.opam.lib.threads.posix"),
        executable = False,
    )

################################################################
def install(repo_ctx):

    # _build_re2c(repo_ctx)

    _build_opam_bootstrapper_local(repo_ctx)

    _install_build_templates(repo_ctx)
