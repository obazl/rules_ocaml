def build_opam_bootstrapper(repo_ctx):

    bootstrap_opam = "https://github.com/obazl/bootstrap_opam/archive/refs/heads/main.zip"
    # bootstrap_opam = "https://github.com/obazl/bootstrap_ocaml/archive/aa85ef74ab038fbb1eaafe768814d68193b886ef.zip"

    repo_ctx.download_and_extract(
        bootstrap_opam,
        "bootstrap_opam",
        stripPrefix = "bootstrap_opam-main"
    )

    # if "PATH" in repo_ctx.os.environ:
    #     path = repo_ctx.os.environ["PATH"]
    # if "BINDIR" in repo_ctx.os.environ:
    #     print("BINDIR: %s" % repo_ctx.os.environ["BINDIR"])

    # if "OBAZL_BOOTSTRAP" in repo_ctx.os.environ:
    #     path = str(here) + "/" + repo_ctx.os.environ["OBAZL_BOOTSTRAP"] + ":" + path

    # print("OBAZL path: %s" % path)

    # fail("test")

    # cmd_env["PATH"] = path
    # print("BOOTSTRAPPER: %s" % repo_ctx.attr.bootstrapper)
    # print("BOOTSTRAPPER: %s" % repo_ctx.attr.bootstrapper[DefaultInfo])
    # f = repo_ctx.file(repo_ctx.attr.bootstrapper)
    # print("BOOTSTRAPPER: %s" % f)
    # for x in repo_ctx.file.bootstrapper[DefaultInfo].files.to_list():
    #     print("F: %s" % x)

    ## FIXME: cache bootstrap result

    if "HOME" in repo_ctx.os.environ:
        home = repo_ctx.os.environ["HOME"]
    else:
        fail("HOME not in env.")

    local_bin = home + "/.local/bin"

    cmd = ["make", "-C", "./bootstrap_opam/src", "opam_bootstrap"]

    xr = repo_ctx.execute(cmd) ## , environment=cmd_env)
    if xr.return_code == 0:
        print("make bootstrap_opam stdout: %s" % xr.stdout)
    else:
        print("make bootstrap_opam result: %s" % xr.stdout)
        print("make bootstrap_opam rc: {rc} stderr: {stderr}".format(rc=xr.return_code, stderr=xr.stderr));
        fail("Comand failed: make -C bootstrap_opam")

    cmd = ["cp", "-v", "./bootstrap_opam/src/opam_bootstrap", local_bin]
    xr = repo_ctx.execute(cmd) ## , environment=cmd_env)
    if xr.return_code == 0:
        print("cp src/opam_bootstrap ~/.local/bin succeeded; stdout: %s" % xr.stdout)
    else:
        print("cp src/opam_bootstrap result: %s" % xr.stdout)
        print("cp src/opam_bootstrap rc: {rc} stderr: {stderr}".format(rc=xr.return_code, stderr=xr.stderr));
        fail("Comand failed: %s" % cmd)

################################################################
def build_re2c(repo_ctx):

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
        print("re2c already built")
        return
    elif xr.return_code == 254:
        print("Found $HOME/.local/bin/re2c, vernum {VERNUM} - expected 02003".format(VERNUM = xr.stdout))
    else:
        print("ls re2c rc: {rc}".format(rc=xr.return_code))
        print("ls re2c stderr: {stderr}".format(stderr=xr.stderr))
        print("ls re2c stdout: %s" % xr.stdout)
        print("re2c not found; building")

    repo_ctx.report_progress("... not found.")

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
def build_tools(repo_ctx):

    build_re2c(repo_ctx)

    build_opam_bootstrapper(repo_ctx)

################################################################
def get_xdg(repo_ctx):
    if "HOME" in repo_ctx.os.environ:
        home = repo_ctx.os.environ["HOME"]
        # print("HOME: %s" % home)
    else:
        fail("HOME not in env.")

    if "XDG_CACHE_HOME" in repo_ctx.os.environ:
        xdg_cache_home = repo_ctx.os.environ["XDG_CACHE_HOME"]
    else:
        xdg_cache_home = home + "/.cache"

    if "XDG_CONFIG_HOME" in repo_ctx.os.environ:
        xdg_config_home = repo_ctx.os.environ["XDG_CONFIG_HOME"]
    else:
        xdg_config_home = home + "/.config"

    if "XDG_DATA_HOME" in repo_ctx.os.environ:
        xdg_data_home = repo_ctx.os.environ["XDG_DATA_HOME"]
    else:
        xdg_data_home = home + "/.local/share"

    return home, repo_ctx.path(xdg_cache_home), repo_ctx.path(xdg_config_home), repo_ctx.path(xdg_data_home)

###############################
def impl_opam_configuration(repo_ctx):

    debug = True ## False
    # if (ctx.label.name == "zexe_backend_common"):
    #     debug = True

    if debug:
        print("OPAM_CONFIGURATION TARGET: %s" % repo_ctx.name)
        print("opam deps: %s" % repo_ctx.attr.packages)
        print("custom build_files: %s" % repo_ctx.attr.build_files)

    repo_ctx.file(
        "WORKSPACE.bazel",
        content = """workspace( name = \"opam\" )
        """,
        executable=False
    )

    ## ocaml compilers will not follow -I dirs with symlinks.
    ## we need to provide the real path for the opam lib,
    ## which our rules will use to construct -I args:
    cmd = ["opam", "var", "lib"]
    result = repo_ctx.execute(cmd)
    if result.return_code == 0:
        opam_lib = result.stdout.strip()
    elif result.return_code == 5: # Not found
        fail("OPAM cmd {cmd}' result: not found.".format(cmd = cmd))
    else:
        print("OPAM cmd {cmd} rc    : {rc}".format(cmd=cmd, rc= result.return_code))
        print("OPAM cmd {cmd} stdout: {stdout}".format(cmd=cmd, stdout= result.stdout))
        print("OPAM cmd {cmd} stderr: {stderr}".format(cmd=cmd, stderr= result.stderr))
        fail("OPAM cmd failure.")

    opam_lib = repo_ctx.path(opam_lib)
    repo_ctx.file(
        "BUILD.bazel",
        content = """
load("@bazel_skylib//rules:common_settings.bzl", "string_setting")

exports_files(glob([\".bin/**\"]))
exports_files(glob([\"_lib/**\"]))

filegroup(
    name = "compiler-libs.common",
    srcs = glob([
        "_lib/ocaml/compiler-libs/*.mli",
        "_lib/ocaml/compiler-libs/*.cmi",
    ]),
    visibility = ["//visibility:public"]
)

filegroup(
    name = "compiler-libs.bytecode",
    srcs = glob([
        "_lib/ocaml/compiler-libs/*.cmo",
    ]),
    visibility = ["//visibility:public"]
)

filegroup(
    name = "compiler-libs.native",
    srcs = glob([
        "_lib/ocaml/compiler-libs/*.cmx",
        "_lib/ocaml/compiler-libs/*.o",
   ]),
    visibility = ["//visibility:public"]
)

## realpath
string_setting(
    name = "opam_lib",
    build_setting_default = "{opam_lib}",
    visibility = ["//visibility:public"]
)

        """.format(opam_lib = opam_lib),
        executable=False
    )

    cmd_args = []
    for p in repo_ctx.attr.packages:
        cmd_args.append("-p")
        cmd_args.append(p)

    cmd_env = {}
    # for [k, v] in repo_ctx.attr.build_files.items():
    #     cmd_args.append("-b")
    #     cmd_args.append(v)
    #     cmd_env[v] = str(repo_ctx.path(k))

    # cmd = ["bazel", "info", "--show_make_env"]
    # xr = repo_ctx.execute(cmd)
    # if xr.return_code == 0:
    #     print("bazel info stdout: %s" % xr.stdout)
    #     # print("opam_bootstrap stderr: %s" % xr.stderr)
    # else:
    #     print("build bootstrap result: %s" % xr.stdout)
    #     print("build bootstrap rc: {rc} stderr: {stderr}".format(rc=xr.return_code, stderr=xr.stderr));
    #     fail("Comand failed: %s" % cmd)

    # here = repo_ctx.path(Label("@//:WORKSPACE.bazel")).dirname
    # print("HERE: %s" % here)

    if "PATH" in repo_ctx.os.environ:
        path = repo_ctx.os.environ["PATH"]
    # if "BINDIR" in repo_ctx.os.environ:
    #     print("BINDIR: %s" % repo_ctx.os.environ["BINDIR"])

    # if "OBAZL_BOOTSTRAP" in repo_ctx.os.environ:
    #     path = str(here) + "/" + repo_ctx.os.environ["OBAZL_BOOTSTRAP"] + ":" + path

    # print("OBAZL path: %s" % path)

    # fail("test")

    # XDG: https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
    home, xdg_cache_home, xdg_config_home, xdg_data_home = get_xdg(repo_ctx)
    print("HOME: %s" % home)
    print("XDG_CONFIG_HOME: %s" % xdg_config_home)
    print("XDG_CACHE_HOME: %s" % xdg_cache_home)
    print("XDG_DATA_HOME: %s" % xdg_data_home)

    # systemd file-hierarchy: https://www.freedesktop.org/software/systemd/man/file-hierarchy.html


    ## ~/.local/bin/
    ## Executables that shall appear in the user's $PATH search path. It is recommended not to place executables in this directory that are not useful for invocation from a shell; these should be placed in a subdirectory of ~/.local/lib/ instead. Care should be taken when placing architecture-dependent binaries in this place, which might be problematic if the home directory is shared between multiple hosts with different architectures.

    ## ~/.local/lib
    ## Static, private vendor data that is compatible with all architectures.

    ## ~/.local/lib/arch-id/
    ## Location for placing public dynamic libraries. The architecture identifier to use is defined on Multiarch Architecture Specifiers (Tuples) list.

    ## for now, we're using ~/.local/bin

    ## Find out if opam_bootstrap already installed in ~/.local/bin
    cmd_env = {}
    path = home + "/.local/bin:" + path
    cmd_env["PATH"] = path
    print("PATH: %s" % cmd_env)


    ## FIXME: support option to force rebuild of opam_bootstrap
    print("checking: is opam_bootstrap installed?")
    # cmd = ["./bootstrap_opam/src/opam_bootstrap"]
    # print("cmd_args: %s" % cmd_args)
    cmd = ["opam_bootstrap", "-v"] ## + cmd_args
    print("executing cmd: %s" % cmd)
    xr = repo_ctx.execute(cmd, environment = cmd_env, quiet = False)
    print("return code: %s" % xr.return_code)
    if xr.return_code == 0:
        print("return stdout: '%s'" % xr.stdout.strip())
        if (xr.stdout.strip() == "0.1.0"):
            print("found opam_bootstrap installed, version 0.1.0")
            print("running opam_bootstrap");
            cmd = ["opam_bootstrap"] ## + cmd_args
            xr = repo_ctx.execute(cmd, environment = cmd_env, quiet = False)
            if xr.return_code == 0:
                print("opam_bootstrap ran successfully");
            else:
                print("opam_bootstrap failed, result: %s" % xr.stdout)
                print("opam_bootstrap rc: {rc} stderr: {stderr}".format(rc=xr.return_code, stderr=xr.stderr));
        else:
            ## FIXME: option to upgrade
            print("found opam_bootstrap installed, but wrong version: %s" % xr.stdout.strip())
    else:
        print("opam_bootstrap not installed; building...")
        build_tools(repo_ctx)

        # now try again
        print("running opam_bootstrap")
        cmd = ["opam_bootstrap"] ## + cmd_args
        xr = repo_ctx.execute(cmd, environment = cmd_env)
        if xr.return_code == 0:
            print("2 opam_bootstrap succeeded")
            # print("2 opam_bootstrap stdout: %s" % xr.stdout)
            # print("2 opam_bootstrap stderr: %s" % xr.stderr)
        else:
            print("2 opam_bootstrap result: %s" % xr.stdout)
            print("2 opam_bootstrap rc: {rc} stderr: {stderr}".format(rc=xr.return_code, stderr=xr.stderr));

    # else:
        # print("opam_bootstrap succeeded")
        # print("opam_bootstrap stdout: %s" % xr.stdout)
        # print("opam_bootstrap stderr: %s" % xr.stderr)

#####################
opam_configuration = repository_rule(
    implementation = impl_opam_configuration,
    environ = [
        # "OBAZL_BOOTSTRAP",
        "XDG_CACHE_HOME",
    ],
    configure = True,
    local = True,
    doc = """Configures OPAM installation""",
    attrs = dict(

        switch = attr.string(
        ),

        packages = attr.string_list(
            doc = """List of OPAM package deps.

            """,
        ),

        build_files  = attr.label_keyed_string_dict(
            doc = """Dictionary mapping custom build files to OPAM package names.

            """,
        ),

        download = attr.bool(
            default = False,
        ),

        hermetic = attr.bool(
            default = False,
        ),

        bootstrapper = attr.label(
            executable = True,
            cfg = "host",
            default = "@tools_obazl//bootstrap:opam_bootstrap",
            allow_single_file = True
        ),

        _rule = attr.string( default = "opam_configuration" ),
    ),
)
