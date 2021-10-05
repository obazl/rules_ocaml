load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:types.bzl", "types")

load("//ppx/_bootstrap:ppx.bzl", "ppx_repo")

# load("//coq/_toolchains:coq_toolchains.bzl", "coq_register_toolchains")

load("//ocaml/_toolchains:ocaml_toolchains.bzl", "ocaml_register_toolchains")

load("//ocaml/_debug:utils.bzl", "debug_report_progress")


load("//ocaml/_repo_rules:new_local_pkg_repository.bzl",
     "new_local_pkg_repository")

load("//opam:_opam_repo.bzl", opam_install = "install")

rules_ocaml_ws = "@obazl_rules_ocaml"

################
def install_new_local_pkg_repos():

    # path attr: relative to OPAM_SWITCH_PREFIX

    new_local_pkg_repository(
        name = "ocaml.compiler-libs",
        # path = OPAM_SWITCH_PREFIX + "/lib/ocaml/compiler-libs",
        path = "ocaml/compiler-libs",
        build_file = "@obazl_rules_ocaml//ocaml/_templates:ocaml.compiler-libs.REPO"
    )

    new_local_pkg_repository(
        name = "ocaml.ffi",
        path = "ocaml/caml",
        build_file = "@obazl_rules_ocaml//ocaml/_templates:ocaml.ffi.REPO"
    )

    new_local_pkg_repository(
        name = "ocaml.dynlink",
        path = "ocaml",
        build_file = "@obazl_rules_ocaml//ocaml/_templates:ocaml.dynlink.REPO"
    )

    new_local_pkg_repository(
        name = "ocaml.threads",
        path = "ocaml/threads",
        build_file = "@obazl_rules_ocaml//ocaml/_templates:ocaml.threads.REPO"
    )

##################################
def _throw_opam_cmd_error(cmd, r):
    print("OPAM cmd {cmd} rc    : {rc}".format(cmd=cmd, rc= r.return_code))
    print("OPAM cmd {cmd} stdout: {stdout}".format(cmd=cmd, stdout= r.stdout))
    print("OPAM cmd {cmd} stderr: {stderr}".format(cmd=cmd, stderr= r.stderr))
    fail("OPAM cmd failure.")

#######################################
def _opam_set_switch(repo_ctx, switch):

    cmd = ["opam", "switch", switch, "--dry-run"]

    result = repo_ctx.execute(cmd)
    if result.return_code == 0:
        result = result.stdout.strip()
        print("_opam_set_switch result ok: %s" % result)
    elif result.return_code == 5: # Not found
        fail("OPAM cmd {cmd} result: not found.".format(cmd = cmd))
    else:
        _throw_opam_cmd_error(cmd, result)

    return result

#################################
def _get_opam_var(repo_ctx, var, switch=None):

    if switch == None:
        cmd = ["opam", "var", var]
    else:
        cmd = ["opam", "var", "--switch=" + switch, var]
    result = repo_ctx.execute(cmd)
    if result.return_code == 0:
        result = result.stdout.strip()
    elif result.return_code == 5: # Not found
        fail("OPAM var cmd {cmd} result: not found.".format(cmd = cmd))
    else:
        print("OPAM cmd {cmd} rc    : {rc}".format(cmd=cmd, rc= result.return_code))
        print("OPAM cmd {cmd} stdout: {stdout}".format(cmd=cmd, stdout= result.stdout))
        print("OPAM cmd {cmd} stderr: {stderr}".format(cmd=cmd, stderr= result.stderr))
        fail("OPAM cmd failure.")

    return result

##############################
def _discover_switch(repo_ctx):
    "Configures the opam switch."

    ## We only use OPAM for discovery, not for access.

    ## cases:
    ## 0.  null - user passes neither opam nor build nor switch - configure()
    ##     - use current switch
    ##     - args verbose ($OBAZL_VERBOSE) and/or debug ($OBAZL_DEBUG) allowed
    ## 1.  switch only
    ##     - use designated switch
    ## 2.  opam only
    ##     - use default build config from OpamConfig
    ##     a.  
    ## 3.  opam with build
    ##     - use designated build config from OpamConfig

    ##     1.  user also passes an OpamConfig struct (in BUILD.bzl)
    ##         a.  the switch is listed in OpamConfig.switches
    ##             i.  the switch exists in the local system
    ##                 continue - goto  verify/install logic for compiler version, pkgs
    ##                 relativize cmds and data to requested switch:
    ##                    OPAM_SWITCH_PREFIX, CAML_LD_LIBRARY_PATH, OCAML_TOPLEVEL_PATH, and PATH,
    ##             i.  the switch does not exist in the local system
    ##                 continue - goto  newSwitch logic
    ##         b.  the switch is not listed in the OpamConfig.switches
    ##             - throw exception. cannot install without a recipe in OpamConfig
    ##     2. user does NOT pass an OpamConfig struct
    ##         a.  the switch exists in the local system
    ##             i. continue using the requested switch without verification
    ##         b.  the switch does NOT exist in the local system
    ##             - throw exception. cannot install without a recipe in OpamConfig
    ## C.  no switch param
    ##     1. user passes an OpamConfig struct
    ##         a.  continue using
    ##             - the default switch from OpamConfig
    ##             - install/verify flags (params or OpamConfig)
    ##     2. user does NOT pass an OpamConfig struct
    ##         a.  continue using the current switch without intall/verify


    ## we can't run 'eval $(opam env)', since it sets env vars.
    ## but we don't need to; all it does is set
    ## OPAM_SWITCH_PREFIX, CAML_LD_LIBRARY_PATH, OCAML_TOPLEVEL_PATH, and PATH,
    ## which we do not need, since we can configure the equivalent.

    if repo_ctx.attr.debug:
        print("_discover_switch")

    case = None
    if "OPAMSWITCH" in repo_ctx.os.environ:
        case = 1
        opam_switch = repo_ctx.os.environ["OPAMSWITCH"]
        if repo_ctx.attr.verbose:
            print("  Case: %s" % repo_ctx.attr.case)
            print("  Using $OPAMSWITCH: '{s}'".format(s = opam_switch))
    elif repo_ctx.attr.switch_name:
        # this only happens for case 1, switch is the only arg
        opam_switch = repo_ctx.attr.switch_name
        if repo_ctx.attr.verbose:
            print("  Case: %s" % repo_ctx.attr.case)
            print("  Using switch: '{s}'".format(s = opam_switch))
    else:
        # only happens for case 0, no args, no $OPAMSWITCH
        opam_switch = _get_opam_var(repo_ctx, "switch")
        if repo_ctx.attr.verbose:
            print("  Case: %s" % repo_ctx.attr.case)
            print("  Using current switch ({s})".format(s = opam_switch) )

    ## now configure/verify the requested switch
    # r = _opam_set_switch(repo_ctx, opam_switch)

    ## opam constructs the prefix, whether it exists or not
    opam_prefix = _get_opam_var(repo_ctx, "prefix", switch=opam_switch)
    switch_path = repo_ctx.path(opam_prefix)
    if  not switch_path.exists:
        #     print("Found switch prefix: %s" % switch_path)
        # else:
        fail("Switch '{s}' at {pfx} not found.".format(
            s = repo_ctx.attr.switch_name,
            pfx = opam_prefix
        ))

    opam_root = _get_opam_var(repo_ctx, "root")

    return opam_root, opam_switch, opam_prefix

################################
def _install_ocaml_core_pkgs(repo_ctx, projroot, opam_switch_prefix):
    repo_ctx.report_progress("installing ocaml core pkg templates")

    ws = rules_ocaml_ws

    repo_ctx.template(
        "compiler-libs/BUILD.bazel",
        Label(ws + "//ocaml/_templates/ocaml_REPO:compiler-libs.BUILD"),
        executable = False,
    )

    repo_ctx.template(
        "compiler-libs/common/BUILD.bazel",
        Label(ws + "//ocaml/_templates/ocaml_REPO:compiler-libs.common.BUILD"),
        executable = False,
    )

    repo_ctx.template(
        "dynlink/BUILD.bazel",
        Label(ws + "//ocaml/_templates/ocaml_REPO:dynlink.BUILD"),
        executable = False,
    )

    repo_ctx.template(
        "ffi/BUILD.bazel",
        Label(ws + "//ocaml/_templates/ocaml_REPO:ffi.BUILD"),
        executable = False,
    )

    repo_ctx.template(
        "threads/BUILD.bazel",
        Label(ws + "//ocaml/_templates/ocaml_REPO:threads.BUILD"),
        executable = False,
    )

    repo_ctx.template(
        "threads/posix/BUILD.bazel",
        Label(ws + "//ocaml/_templates/ocaml_REPO:threads.posix.BUILD"),
        executable = False,
    )

    repo_ctx.template(
        "lib/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.stdlib"),
        executable = False,
    )

################################
def _install_ocaml_templates(repo_ctx, projroot, opam_switch_prefix):
    repo_ctx.report_progress("installing templates")

    ws = "@obazl_rules_ocaml"

    repo_ctx.template(
        "BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml"),
        executable = False,
        substitutions = {
            "{sdkpath}": opam_switch_prefix,
            "{projroot}": str(projroot)
        },
    )

    _install_ocaml_core_pkgs(repo_ctx, projroot, opam_switch_prefix)

    repo_ctx.template(
        "toolchain/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.toolchain"),
        executable = False,
    )

    repo_ctx.template(
        "tools/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.tools"),
        executable = False,
    )

    ## FIXME: call this ffi instead of csdk?
    # repo_ctx.template(
    #     "csdk/BUILD.bazel",
    #     Label(ws + "//ocaml/_templates:BUILD.ocaml.csdk"),
    #     executable = False,
    #     # substitutions = {
    #     #     "{sdkpath}": opam_switch_prefix
    #     # },
    # )

    ## No, ctypes is not part of std ffi
    # repo_ctx.template(
    #     "csdk/ctypes/BUILD.bazel",
    #     Label(ws + "//ocaml/_templates:BUILD.ocaml.csdk.ctypes"),
    #     executable = False,
    #     # substitutions = {
    #     #     "{sdkpath}": opam_switch_prefix
    #     # },
    # )

    ## TEMPORARY HACK
    #### ASPECTS ####
    repo_ctx.template(
        "aspects/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.aspects"),
        executable = False,
    )
    repo_ctx.template(
        "aspects/debug.bzl",
        Label("@obazl_rules_ocaml//ocaml/_aspects:debug.bzl"),
        executable = False,
    )
    repo_ctx.template(
        "aspects/ppx.bzl",
        Label("@obazl_rules_ocaml//ocaml/_aspects:ppx.bzl"),
        executable = False,
    )
    repo_ctx.template(
        "aspects/depsets.bzl",
        Label("@obazl_rules_ocaml//ocaml/_aspects:depsets.bzl"),
        executable = False,
    )

    # #### BUILD CONFIG FLAGS ####
    repo_ctx.template(
        "cc_deps/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.cc_deps"),
        executable = False,
    )
    repo_ctx.template(
        "cmt/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.cmt"),
        executable = False,
    )
    repo_ctx.template(
        "debug/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.debug"),
        executable = False,
    )
    repo_ctx.template(
        "keep-locs/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.keep_locs"),
        executable = False,
    )
    repo_ctx.template(
        "linkmode/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.linkmode"),
        executable = False,
    )
    repo_ctx.template(
        "mode/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.mode"),
        executable = False,
    )
    repo_ctx.template(
        "noassert/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.noassert"),
        executable = False,
    )
    repo_ctx.template(
        "opaque/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.opaque"),
        executable = False,
    )
    repo_ctx.template(
        "short-paths/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.short_paths"),
        executable = False,
    )
    repo_ctx.template(
        "strict-formats/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.strict_formats"),
        executable = False,
    )
    repo_ctx.template(
        "strict-sequence/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.strict_sequence"),
        executable = False,
    )

    ## rule types
    repo_ctx.template(
        "archive/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.archive"),
        executable = False,
    )
    repo_ctx.template(
        "archive/linkall/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.archive.linkall"),
        executable = False,
    )
    repo_ctx.template(
        "archive/threads/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.archive.threads"),
        executable = False,
    )
    ##################
    repo_ctx.template(
        "executable/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.executable"),
        executable = False,
    )
    repo_ctx.template(
        "executable/linkall/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.executable.linkall"),
        executable = False,
    )
    repo_ctx.template(
        "executable/threads/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.executable.threads"),
        executable = False,
    )
    ##################
    repo_ctx.template(
        "library/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.library"),
        executable = False,
    )
    repo_ctx.template(
        "library/linkall/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.library.linkall"),
        executable = False,
    )
    repo_ctx.template(
        "library/threads/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.library.threads"),
        executable = False,
    )
    ##################
    repo_ctx.template(
        "module/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.module"),
        executable = False,
    )
    repo_ctx.template(
        "module/linkall/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.module.linkall"),
        executable = False,
    )
    repo_ctx.template(
        "module/threads/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.module.threads"),
        executable = False,
    )
    ##################
    repo_ctx.template(
        "ns_archive/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.ns_archive"),
        executable = False,
    )
    repo_ctx.template(
        "ns_archive/linkall/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.ns_archive.linkall"),
        executable = False,
    )
    # # do we need -threads for archives?
    # repo_ctx.template(
    #     "ns_archive/threads/BUILD.bazel",
    #     Label(ws + "//ocaml/_templates:BUILD.ocaml.ns_archive.threads"),
    #     executable = False,
    # )
    ##################
    repo_ctx.template(
        "ns/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.ns"),
        executable = False,
    )
    ##################
    repo_ctx.template(
        "ns_library/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.ns_library"),
        executable = False,
    )
    repo_ctx.template(
        "ns_library/linkall/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.ns_library.linkall"),
        executable = False,
    )
    ##################
    repo_ctx.template(
        "signature/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.signature"),
        executable = False,
    )
    repo_ctx.template(
        "signature/linkall/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.signature.linkall"),
        executable = False,
    )
    repo_ctx.template(
        "signature/threads/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.signature.threads"),
        executable = False,
    )
    ##################
    repo_ctx.template(
        "verbose/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.verbose"),
        executable = False,
    )

    # ##################
    ocaml_version = repo_ctx.execute(["ocaml", "-vnum"]).stdout.strip()
    [ocaml_major, sep, rest] = ocaml_version.partition(".")
    [ocaml_minor, sep, rest] = rest.partition(".")
    [ocaml_patch, sep, rest] = rest.partition(".")

    repo_ctx.template(
        "version/BUILD.bazel",
        Label(ws + "//ocaml/_templates:BUILD.ocaml.version"),
        executable = False,
        substitutions = {
            "{VERSION}": ocaml_version,
            "{MAJOR}": ocaml_major,
            "{MINOR}": ocaml_minor,
            "{PATCH}":  ocaml_patch
        },
    )

    # repo_ctx.template(
    #     "coq/BUILD.bazel",
    #     Label("//coq/_templates:BUILD.coq_sdk.toolchains"),
    #     executable = False,
    #     substitutions = {
    #         "{sdkpath}": "foo",
    #         "{projroot}": "projroot" # str(projroot)
    #     },
    # )

######################################################
# def _install_coq_symlinks(repo_ctx, coq_sdk):

#     for tool in ["topbin/coqc"]:
#         tool_path = repo_ctx.path(coq_sdk + tool)
#         if tool_path.exists:
#             repo_ctx.symlink(tool_path + tool)
#         else:
#             if repo_ctx.attr.verbose:
#                 print(
#                     "WARNING: could not find {tool} at {path}".format(
#                         tool = tool,
#                         path = tool_path
#                     )
#                 )

#####################################
def _install_opam_symlinks(repo_ctx, opam_root, opam_switch_prefix):
    if repo_ctx.attr.verbose:
        repo_ctx.report_progress("creating OPAM symlinks")

    repo_ctx.file("bin/BUILD.bazel",
                  content = """exports_files(glob([\"**\"]))""")

    bindir = opam_switch_prefix + "/bin"
    binpath = repo_ctx.path(bindir)
    binfiles = binpath.readdir()
    for file in binfiles:
        repo_ctx.symlink(file, "bin/" + file.basename)

###############################
def _is_pkg_installed(repo_ctx, pkg, opam_switch):
    repo_ctx.report_progress("_is_pkg_installed: %s" % pkg)
    cmd = ["opam", "var", pkg + ":installed", "--switch=" + opam_switch]
    result = repo_ctx.execute(cmd)
    if result.return_code == 0:
        if result.stdout.strip() == "false":
            return False
        else:
            return True
    else:
        _throw_opam_cmd_error(cmd, result)

####################################
def _get_pkg_version(repo_ctx, pkg, opam_switch):
    repo_ctx.report_progress("_get_pkg_version: %s" % pkg)
    if _is_pkg_installed(repo_ctx, pkg, opam_switch):
        cmd = ["opam", "config", "var", pkg + ":version", "--switch=" + opam_switch]
        result = repo_ctx.execute(cmd)
        if result.return_code == 0:
            return result.stdout.strip()
        else:
            _throw_opam_cmd_error(cmd, result)
    else:
        fail("pkg '{pkg}' not installed.".format(pkg=pkg))

#########################################################################
def _verify_opam_pkgs(repo_ctx, opam_switch):
    repo_ctx.report_progress("Verifying OPAM package installation.")

    if repo_ctx.attr.debug:
        print("_verify_opam_pkgs for build config: %s" % repo_ctx.attr.build_name)
        print(repo_ctx.attr.opam_pkgs)

    for [pkg, version] in repo_ctx.attr.opam_pkgs.items():
        # print("verifying {pkg}, version: '{v}'".format(
        #     pkg = pkg, v = version
        #     ))
        if version == '':  ## accept any installed version
            installed = _is_pkg_installed(repo_ctx, pkg, opam_switch)
            if not installed:
            #     print("pkg {pkg} installed? {yn}".format(pkg=pkg, yn=installed))
            # else:
                fail("ERROR: pkg '{pkg}' not installed.".format(pkg=pkg))
            continue

        installed_version = _get_pkg_version(repo_ctx, pkg, opam_switch)
        # if install_version == "NOTFOUND":
        #     fail("pkg '{pkg}', version{v} not found.".format(pkg=pkg, ))
        # print("{pkg} installed version: {v}".format(pkg=pkg, v=installed_version))
        if installed_version != version:
            fail("ERROR: pkg '{pkg}' installed version {iv} does not match requested version {rv}.".format(
                pkg=pkg, iv=installed_version, rv=version
            ))

#########################################################################
def _configure_current_switch(repo_ctx, opam_switch, opam_switch_prefix):
    ## nothing to do?
    if repo_ctx.attr.debug:
        print("_configure_current_switch")

###########################################################################
def _configure_requested_switch(repo_ctx, opam_switch, opam_switch_prefix):
    repo_ctx.report_progress("_configure_requested_switch")
    if repo_ctx.attr.debug:
        print("_configure_requested_switch")
        print("  build name     : %s" % repo_ctx.attr.build_name)
        print("  switch name    : %s" % repo_ctx.attr.switch_name)
        print("  switch compiler: %s" % repo_ctx.attr.switch_compiler)

    if repo_ctx.attr.pin:
        print("  Pinning")
        # result = repo_ctx.execute(["opam", "config", "var", pkg + ":pinned"])
    elif repo_ctx.attr.verify:
        repo_ctx.report_progress("XXXXXXXXXXXXXXXX")
        _verify_opam_pkgs(repo_ctx, opam_switch)

#########################################################################
def _configure_default_switch(repo_ctx, opam_switch, opam_switch_prefix):
    if repo_ctx.attr.debug:
        print("_configure_default_switch")
        print("  build name     : %s" % repo_ctx.attr.build_name)
        print("  switch name    : %s" % repo_ctx.attr.switch_name)
        print("  switch compiler: %s" % repo_ctx.attr.switch_compiler)
        # verify switch is installed

###############################
def _ocaml_repo_impl(repo_ctx):
    repo_ctx.report_progress("Bootstrapping ocaml repo")
    if repo_ctx.attr.debug:
        print("_ocaml_repo_impl")

    ## we can only get env vars within a repo_ctx, so we do this here:
    if "OPAMSWITCH" in repo_ctx.os.environ:
        if repo_ctx.attr.build_name:
            fail("ocaml_configure: $OPAMSWITCH not compatible with 'build' arg")


    projroot = str(repo_ctx.path("@").dirname.dirname.dirname) + "/execroot"
    # print("PROJROOT: %s" % projroot)

    opam_root, opam_switch, opam_switch_prefix = _discover_switch(repo_ctx)

    # repo_ctx.report_progress("opam_root: %s" % opam_root)
    # repo_ctx.report_progress("opam_switch: %s" % opam_switch)
    # repo_ctx.report_progress("opam_switch_prefix: %s" % opam_switch_prefix)

    ## hack - see opam/_opam_repo.bzl
    ## symlinks before templates
    repo_ctx.symlink(opam_switch_prefix + "/lib/ocaml", "lib")

    _install_opam_symlinks(repo_ctx, opam_root, opam_switch_prefix)

    ## WARNING: install the templates BEFORE configuring (verifying) the opam switch, otherwise
    ## we get tons of restarts.
    _install_ocaml_templates(repo_ctx, projroot, opam_switch_prefix)

    # opam_install(repo_ctx) #, bootstrap_debug=repo_ctx.attr.bootstrap_debug)

    # _install_coq_symlinks(repo_ctx, ".") # coq_sdk

    ## now verify/install the opam switch
    if repo_ctx.attr.case == 0:   ## null
        _configure_current_switch(repo_ctx, opam_switch, opam_switch_prefix)
    elif repo_ctx.attr.case == 1:  ## switch only
        _configure_default_switch(repo_ctx, opam_switch, opam_switch_prefix)
    else:
        _configure_requested_switch(repo_ctx, opam_switch, opam_switch_prefix)

#############################
_ocaml_repo = repository_rule(
    implementation = _ocaml_repo_impl,
    configure = True,
    # local = True,
    environ = [
        # "OBAZL_OPAM_VERIFY",
        "OPAM_SWITCH_PREFIX",
        # "CAML_LD_LIBRARY_PATH"
    ],
    attrs = dict(
        hermetic        = attr.bool( default = False ),
        verify          = attr.bool( default = False ),
        verify_pinning  = attr.bool( default = False ),
        install         = attr.bool( default = False ),
        force           = attr.bool( default = False),
        pin             = attr.bool( default = False ),
        # switch          = attr.string(), #default = "@opam_switch//:switch"),

        case           = attr.int(),

        build_name     = attr.string(),
        switch_name    = attr.string(),
        switch_compiler = attr.string(),
        opam_pkgs = attr.string_dict(
            doc = "Dictionary of OPAM packages (name: version) to install.",
            # default = {"foo": "bar"}
        ),
        findlib_pkgs = attr.string_list(
            doc = "List of findlib packages to install.",
            # default = []
        ),
        # pins_install = attr.bool(default = True),
        pin_specs = attr.string_list_dict(
            doc = "Dictionariy of pkgs to pin. Key: pkg, Val: [version, path]"
        ),
        # pin_versions = attr.string_dict(
        #     doc = "Dictionariy of pkgs to pin (name: path)"
        # ),
        # _switch = attr.string(default = "default")
        verbose = attr.bool(default = False),
        debug   = attr.bool(default = False),
        bootstrap_debug   = attr.bool(default = False)
    )
)

############################
def _unpack_build_struct(build_name, build_struct):

    opam_pkgs    = {}
    findlib_pkgs = []
    pin_specs = {}

    if build_struct.packages:
        if (not types.is_dict(build_struct.packages)):
            fail("build.packages must be a dict")
        for [pkg, spec] in build_struct.packages.items():
            # print("PKG: {p} SPEC: {s}".format(p=pkg, s=spec))
            if types.is_string(spec): # version
                opam_pkgs[pkg] =  spec
                # pin_paths[pkg] = spec
                # print("PIN PATH: {p} {s}".format(p=pkg, s=pin_paths[pkg]))
            elif types.is_list(spec):
                if len(spec) == 0: # comes with compiler, or a findlib subpkg?
                    opam_pkgs[pkg] =  ''
                    # findlib_pkgs.append(pkg)
                elif len(spec) == 1: # version string
                    opam_pkgs[pkg] =  spec[0]
                elif len(spec) == 2: # tuple of sublibs
                    if types.is_list(spec[1]):
                        opam_pkgs[pkg] =  spec[0]
                        ## FIXME: verify second element is list of strings
                        findlib_pkgs.extend(spec[1])
                    elif types.is_string(spec[1]): # pin path
                        pin_specs[pkg] = [spec[0], spec[1]]
                        # print("PIN SPEC: {p} : {s}".format(p=pkg, s=pin_specs[pkg]))
                    else:
                        fail("build.packages value entries 2nd element must be list of sublibs")
                else:
                    fail("build.packages value must be a list of length zero, one or two")
            else:
                fail("build.packages value entries must be list or string")
    else:
        ## no point in having a build struct without a packages field
        fail("opam struct for build {s} must contain a 'packages' dict.".format(
            s = build_name
            ))

    return opam_pkgs, findlib_pkgs, pin_specs

##############################
def config_opam(
        opam = None,
        build   = None,
        # default  = False,
        # hermetic = False,
        # verify   = False,
        # install  = False,
        # pin      = False,
        force    = False,
        verbose  = False,
        debug    = False,
        bootstrap_debug = False
):
    if debug:
        print("config_opam")

    ## We cannot pass a struct to a repo rule, so we have to parse the opam struct
    ## here, to determine which build is requested.
    ## This complicates configuration "case" handling (see _configure_build for the case logic),
    ## which is why we are passing a 'case' parameter. Mainly to aid debugging.

    case = None

    ## opam arg must be OpamConfig, but the language does not typecheck so we have to do it by hand

    default_build = None
    if hasattr(opam, "builds"):
        if (not types.is_dict(opam.builds)):
                fail("opam.builds must be a dict")
        for [k,v] in opam.builds.items():
            if hasattr(v, "default"):
                if v.default:
                    if default_build == None:
                        default_build = k
                    else:
                        fail("Only one build may be marked with 'default = True'")
        if default_build == None:
            # print("opam config: one build must be marked with 'default = True'")
            fail("opam config: one build must be marked with 'default = True'")
            return
    else:
        fail("opam config struct is missing field 'builds'")

    if build == None:
        build_name = default_build
        case = 2
    else:
        build_name = build
        case = 3

    if verbose:
        print("  build name: %s" % build_name)

    build_struct = opam.builds[build_name]

    if build_struct == None:
        fail("ERROR: opam config for build {s} not defined in config file".format(s=build_name))
        return

    if hasattr(build_struct, "switch"):
        switch_name = build_struct.switch
    else:
        print("build_struct.compiler: %s" % build_struct.compiler)
        print("build_name: %s" % build_name)
        if build_struct.compiler == build_name:
            switch_name = build_name
        else:
            fail("ERROR: OpamConfig.OpamSwitch build struct '{s}' must have 'switch' field.".format(
                s = build_name
            ))
            return

    if verbose:
        print("  switch_name: %s" % switch_name)

    if hasattr(build_struct, "compiler"):
        switch_compiler = build_struct.compiler
    else:
        fail("ERROR: OpamConfig struct, OpamSwitch must have 'compiler' field with compiler version.")
        return

    if verbose:
        print("  switch_compiler: %s" % switch_compiler)

    if hasattr(build_struct, "hermetic"):
        hermetic = True
    else:
        hermetic = False;
    if hasattr(build_struct, "verify"):
        verify = True
    else:
        verify = False
    if hasattr(build_struct, "verify_pinning"):
        verify_pinning = True
    else:
        verify_pinning = False
    if hasattr(build_struct, "install"):
        install = True
    else:
        install = False
    if hasattr(build_struct, "pin"):
        pin = True
    else:
        pin = False

    opam_pkgs    = {}
    findlib_pkgs = []
    pin_specs = {}

    ## We cannot pass a struct to a repo rule, so we have to unpack the build struct.
    [opam_pkgs, findlib_pkgs, pin_specs] = _unpack_build_struct(build_name, build_struct)

    _ocaml_repo(name="ocaml",
                hermetic = hermetic,
                verify   = verify,
                verify_pinning = verify_pinning,
                install  = install,
                force    = force,
                pin      = pin,

                case = case,

                build_name      = build_name,
                switch_name     = switch_name,
                switch_compiler = switch_compiler,

                opam_pkgs = opam_pkgs,
                findlib_pkgs = findlib_pkgs,
                pin_specs = pin_specs,
                verbose = verbose,
                debug = debug,
                bootstrap_debug = bootstrap_debug)

##############################
# def configure(debug = False, opam = None): # , **kwargs):
def ocaml_configure(
        opam     = None,
        build    = None,
        switch   = None,
        # hermetic = False,
        # verify   = False,
        # install  = False,
        # pin      = False,
        # force    = False,
        debug    = False,
        bootstrap_debug = False,
        verbose  = False):
    # is_rules_ocaml = False,
    #                 opam = None):
    """Declares workspaces (repositories) the Ocaml rules depend on.

    Args:
      opam: an [OpamConfig](#provider-opamconfig) provider
      debug: enable debugging
    """
    # print("ocaml.configure")

    if switch and (build or opam):
        fail("ocaml_configure: param 'switch' cannot be combined with 'build' or 'opam'.")

    if build and not opam:
        fail("configure param 'build' must be used with param 'opam'.")

    if build and switch:
        fail("configure params 'build' and 'switch' incompatible, pass one or the other.")

    ppx_repo(name="ppx")

    # obazl_repo(name="obazl")

    # opam_configure()

    default_build = None
    if opam:
        config_opam(
            opam,
            build,
            # hermetic,
            # verify,
            # install,
            # pin,
            # force,
            verbose = verbose,
            debug = debug,
            bootstrap_debug = bootstrap_debug,
        )
    else:
        # print("no opam")
        _ocaml_repo(name="ocaml",
                    # hermetic = hermetic,
                    # verify   = verify,
                    # install  = install,
                    # force    = force,
                    # pin      = pin,
                    case     = 1 if switch else 0,
                    switch_name = switch if switch else "",
                    build_name = build,
                    # build_compiler = None,
                    # opam_pkgs = None,
                    # findlib_pkgs = None,
                    # pin_specs = None,
                    verbose = verbose,
                    debug = debug,
                    bootstrap_debug = bootstrap_debug)

    install_new_local_pkg_repos()

    ocaml_register_toolchains(installation="host")
    # coq_register_toolchains(installation="host")

    # print("ocaml_configure done")

# See documentation for _filter_transition_label in
# ocaml/_rules/transition.bzl.
# """,
# )

# print("private/repositories.bzl loaded")
