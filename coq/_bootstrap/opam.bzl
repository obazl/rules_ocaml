# load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
# load("@bazel_skylib//lib:collections.bzl", "collections")
load("@bazel_skylib//lib:types.bzl", "types")

# load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository") # buildifier: disable=load
# load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load
load("@obazl_tools_bazel//tools/functions:strings.bzl", "tokenize")

load(":switch.bzl", "opam_set_switch")
load("//opam/_functions:opam_queries.bzl", "opam_predicate", "opam_property")
load(":opam_pinning.bzl",
     "opam_pin_pkg_path",
     "opam_repin_pkg_path")

load(":hermetic.bzl", "opam_repo_hermetic")

load("//opam/_functions:ppx.bzl", "is_ppx_driver")
load("//opam/_debug:utils.bzl", "DEBUG", "debug_report_progress")

# 4.07.1 broken on XCode 12:
# https://discuss.ocaml.org/t/ocaml-4-07-1-fails-to-build-with-apple-xcode-12/6441/15
# OCAML_VERSION = "4.08.0"
# OCAMLBUILD_VERSION = "0.14.0"
# OCAMLFIND_VERSION = "1.8.1"
# COMPILER_NAME = "ocaml-base-compiler.%s" % OCAML_VERSION
# OPAM_ROOT_DIR = ".opam_root_dir"
# # Set to false to see debug messages
# DEBUG_QUIET = False

################################################################
def _config_opam_pkgs(repo_ctx):
    repo_ctx.report_progress("configuring OPAM pkgs...")
    # print("configuring OPAM pkgs...")

    ## FIXME: packages distibuted with the compiler can be hardcoded?
    ## e.g. compiler-libs.common
    ## but then we would have to keep a list for each compiler version...

    # print("Switch name: %s" % repo_ctx.attr.switch_name)
    # print("Switch compiler: %s" % repo_ctx.attr.switch_compiler)

    # fetch and parse list of installed opam pkgs
    opam_pkg_list = repo_ctx.execute(["opam", "list"]).stdout
    # print("OPAM_PKG_LIST: %s" % opam_pkg_list)

    ## WARNING: because Bazel parallelizes actions, there is no
    ## guarantee that the following pin list action will occur before
    ## pinning actions below. So it does not necessarily tell us what
    ## was pinned before we started.
    # opam_pin_list = repo_ctx.execute(["opam", "pin", "list"]).stdout
    # print("OPAM_PIN_LIST: %s" % opam_pin_list)

    opam_pkg_list = opam_pkg_list.splitlines()
    opam_pkgs     = {}
    missing       = {}
    bad_version   = {}

    for pkg_desc in opam_pkg_list:
        if not pkg_desc.startswith("#"):
            tokens = tokenize(pkg_desc)
            # print("PKG DESC TOKENS: %s" % tokens)
            pkg = tokens[0].strip()
            version = tokens[1].strip()

            # [pkg, sep, rest] = pkg_desc.partition(" ")
            # pkg = pkg.strip(" ")
            # rest = rest.strip(" ")
            # [version, sep, rest] = rest.partition(" ")
            # version = version.strip(" ")

            opam_pkgs[pkg] = version

    opam_pkg_rules = []
    repo_ctx.report_progress("constructing OPAM pkg rules...")
    for [pkg, version] in repo_ctx.attr.opam_pkgs.items():
        # print("Pkg: {p} {v}".format(p=pkg, v=version))

        # repo_ctx.report_progress("Verifying {pkg} pinned to version {v}".format(pkg=pkg, v=version))
        opam_version = opam_pkgs.get(pkg)
        if opam_version == None:
            # print("Pkg {p} not found".format(p=pkg))
            missing[pkg] = version
        else:
            ## FIXME: verify pinning: opam config var pkg:pinned, opam config var pkg:version
            # print("opam_version: %s" % opam_version)
            if ((opam_version == version) or (version == "")):
                result = repo_ctx.execute(["opam", "config", "var", pkg + ":pinned"])
                if result.return_code == 0:
                    # debug_report_progress(repo_ctx, "DBUG cmd: 'opam config var {p}:pinned' RC: {rc}, STDOUT: {stdout}, STDERR: {stderr}".format(
                    #     p=pkg, v=version, rc = result.return_code,
                    #     stdout = result.stdout, stderr = result.stderr
                    # ))
                    # print("cmd: 'opam config var {p}:pinned' RC: {rc}, STDOUT: {stdout}, STDERR: {stderr}".format(
                    #     p=pkg, v=version, rc = result.return_code,
                    #     stdout = result.stdout, stderr = result.stderr
                    # ))
                    if result.stdout.strip() == "true":
                        repo_ctx.report_progress("Verified {p} pinned to {v}".format(p=pkg, v=version))
                        # print("pinned {p} {v}".format(p=pkg, v=version))
                        ppx = is_ppx_driver(repo_ctx, pkg)
                        opam_pkg_rules.append(
                            "opam_pkg(name = \"{pkg}\", ppx_driver={ppx})".format( pkg = pkg, ppx = ppx )
                        )
                    elif version != "":
                        repo_ctx.report_progress("Pinning {p} to {v}".format(p=pkg, v=version))
                        result = repo_ctx.execute(["opam", "pin", "-y", "add", pkg, version])
                        if result.return_code == 0:
                            ppx = is_ppx_driver(repo_ctx, pkg)
                            opam_pkg_rules.append(
                                "opam_pkg(name = \"{pkg}\", ppx_driver={ppx})".format( pkg = pkg, ppx = ppx )
                            )
                        else:
                            fail("OPAM ERROR cmd: 'opam pin -y add {p} {v}' RC: {rc}, STDOUT: {stdout}, STDERR: {stderr}".format(
                                p=pkg, v=version, rc = result.return_code,
                                stdout = result.stdout, stderr = result.stderr
                            ))
                else:
                    fail("OPAM ERROR cmd: 'opam config var {p}:pinned' RC: {rc}, STDOUT: {stdout}, STDERR: {stderr}".format(
                        p=pkg, v=version, rc = result.return_code,
                        stdout = result.stdout, stderr = result.stderr
                    ))

                # ppx = is_ppx_driver(repo_ctx, pkg)
                # opam_pkg_rules.append(
                #     "opam_pkg(name = \"{pkg}\", ppx_driver={ppx})".format( pkg = pkg, ppx = ppx )
                # )
                # findlib_pkg_rules.append(
                #     "findlib_pkg(name = \"{pkg}\", ppx_driver={ppx})".format( pkg = pkg, ppx = ppx )
                # )
            else:
                bad_version[pkg] = version
                # fail("Bad version for pkg {p}. Wanted {v}, found installed: opam {ov}.".format(
                #     p=pkg, v=version, ov=opam_version))

    if len(missing) > 0:
        repo_ctx.report_progress("Missing packages: %s" % missing)
        # print("Missing packages: %s" % missing)
        if (repo_ctx.attr.install or ("OBAZL_OPAM_PIN" in repo_ctx.os.environ)):
            for [pkg, version] in missing.items():
                if version == "":
                    print("WARNING: missing version string for %s; installing latest." % pkg)
                else:
                    repo_ctx.report_progress("Installing missing pkg {p} {v}".format(p=pkg, v=version))
                # print("installing {p} {v}".format(p=pkg, v=version))
                # result = opam_pin_version(pkg, version)
                v = "." + version if version != "" else ""
                result = repo_ctx.execute(["opam", "install", "-y", pkg + v ]) ## "." + version])
                if result.return_code == 0:
                    repo_ctx.report_progress("Installed {p} {v}; pinning...".format(p=pkg, v=version))
                    # print("installed {p} {v}".format(p=pkg, v=version))
                    if repo_ctx.attr.pin:
                        result = repo_ctx.execute(["opam", "pin", "-y", "add", pkg, version])
                        if result.return_code == 0:
                            repo_ctx.report_progress("Pinned {p} {v}".format(p=pkg, v=version))
                            # print("pinned {p} {v}".format(p=pkg, v=version))
                            ppx = is_ppx_driver(repo_ctx, pkg)
                            opam_pkg_rules.append(
                                "opam_pkg(name = \"{pkg}\", ppx_driver={ppx})".format( pkg = pkg, ppx = ppx )
                            )
                        else:
                            fail("OPAM ERROR cmd: 'opam pin -y add {p} {v}' RC: {rc}, STDOUT: {stdout}, STDERR: {stderr}".format(
                                p=pkg, v=version, rc = result.return_code,
                                stdout = result.stdout, stderr = result.stderr
                            ))
                            # print("PIN ERROR RC: %s" % result.return_code)
                            # print("PIN STDERR: %s" % result.stderr)
                            # print("PIN STDOUT: %s" % result.stdout)
                            return
                else:
                    fail("OPAM ERROR cmd: 'opam install -y {p}.{v}' RC: {rc}, STDOUT: {stdout}, STDERR: {stderr}".format(
                        p=pkg, v=version, rc = result.return_code,
                        stdout = result.stdout, stderr = result.stderr
                    ))
                    # print("ERROR: OPAM INSTALL {p} RC: {rc}".format(p=pkg, rc=result.return_code))
                    # print("STDERR: %s" % result.stderr)
                    # print("STDOUT: %s" % result.stdout)
                    return

    if len(bad_version) > 0:
        repo_ctx.report_progress("Bad version packages: %s" % bad_version)
        print("Bad_Version packages: %s" % bad_version)
        if (repo_ctx.attr.install or ("OBAZL_OPAM_PIN" in repo_ctx.os.environ)):
            for [pkg, version] in bad_version.items():
                repo_ctx.report_progress("Removing {p}".format(p=pkg))
                print("removing {p}".format(p=pkg))
                result = repo_ctx.execute(["opam", "remove", "-y", pkg])
                if result.return_code == 0:
                    repo_ctx.report_progress("Removed {p}".format(p=pkg))
                    print("removed {p}".format(p=pkg))
                else:
                    fail("ERROR: cmd 'opam remove -y {p} RC: {rc}, STDOUT: {stdout}, STDERR: {stderr}".format(
                        p=pkg,
                        rc = result.return_code,
                        stdout = result.stdout,
                        stderr =result.stderr
                    ))

                repo_ctx.report_progress("Installing correct version: {p} {v}".format(p=pkg, v=version))
                # print("installing {p} {v}".format(p=pkg, v=version))
                v = "." + version if version != "" else ""
                result = repo_ctx.execute(["opam", "install", "-y", pkg + v]) # "." + version])
                if result.return_code == 0:
                    repo_ctx.report_progress("Installed {p} {v}; pinning...".format(p=pkg, v=version))
                    # print("installed {p} {v}".format(p=pkg, v=version))
                    v = "." + version if version != "" else ""
                    result = repo_ctx.execute(["opam", "pin", "-y", "add", pkg, v])
                    if result.return_code == 0:
                        repo_ctx.report_progress("Pinned {p} {v}".format(p=pkg, v=version))
                        # print("pinned {p} {v}".format(p=pkg, v=version))
                        ppx = is_ppx_driver(repo_ctx, pkg)
                        opam_pkg_rules.append(
                            "opam_pkg(name = \"{pkg}\", ppx_driver={ppx})".format( pkg = pkg, ppx = ppx )
                        )
                    else:
                        fail("'opam pin -y add {p} {v}' RC: {rc}, STDOUT: {stdout}, STDERR: {stderr}".format(
                            p=pkg, v=version, rc = result.return_code,
                            stdout = result.stdout, stderr = result.stderr
                        ))
                else:
                    fail("'opam install -y {p}.{v}' RC: {rc}, STDOUT: {stdout}, STDERR: {stderr}".format(
                        p=pkg, v=version, rc = result.return_code,
                        stdout = result.stdout, stderr = result.stderr
                    ))

    opam_pkgs = "\n".join(opam_pkg_rules)
    return opam_pkgs

###################################
def _config_findlib_pkgs(repo_ctx):
    repo_ctx.report_progress("configuring FINDLIB pkgs...")
    # print("configuring FINDLIB pkgs...")

    ## FIXME: packages distibuted with the compiler can be hardcoded?
    ## e.g. compiler-libs.common
    ## but then we would have to keep a list for each compiler version...

    findlib_pkg_list = repo_ctx.execute(["ocamlfind", "list"]).stdout.splitlines()
    findlib_pkgs = {}
    for pkg_desc in findlib_pkg_list:
        [pkg, version] = pkg_desc.split("(version: ")
        pkg = pkg.strip(" ")
        version = version.strip(" ").rstrip(")")
        findlib_pkgs[pkg] = version

    findlib_pkg_rules = []
    repo_ctx.report_progress("constructing FINDLIB pkg rules...")
    ## FIXME: uniqify?
    # for [pkg, version] in repo_ctx.attr.findlib_pkgs.items():
    for pkg in repo_ctx.attr.findlib_pkgs:
        # version is controlled by opam pkgs
        # findlib_version = findlib_pkgs.get(pkg)
        # if findlib_version == version:
        #     ppx = is_ppx_driver(repo_ctx, pkg)
        findlib_pkg_rules.append(
            "opam_pkg(name = \"{pkg}\", ppx_driver={ppx})".format( pkg = pkg, ppx = "False" )
        )
            # findlib_pkg_rules.append(
            #     "findlib_pkg(name = \"{pkg}\", ppx_driver={ppx})".format( pkg = pkg, ppx = ppx )
            # )
        # else:
        #     opam_version = opam_pkgs.get(pkg)
        #     if opam_version == version:
        #         ppx = is_ppx_driver(repo_ctx, pkg)
        #         opam_pkg_rules.append(
        #             "opam_pkg(name = \"{pkg}\", ppx_driver={ppx})".format( pkg = pkg, ppx = ppx )
        #         )
        #         findlib_pkg_rules.append(
        #             "findlib_pkg(name = \"{pkg}\", ppx_driver={ppx})".format( pkg = pkg, ppx = ppx )
        #         )
        # else:
        #     fail("Bad version for pkg {p}. Wanted {v}, found installed: opam {ov}, findlib {fv}.".format(
        #         p=pkg, v=version, fv=findlib_version))

    findlib_pkg_rules = "\n".join(findlib_pkg_rules)

    return findlib_pkg_rules

#########################
def _pin_paths(repo_ctx):
    repo_ctx.report_progress("pinning OPAM pkgs to paths...")
    # print("_PIN_PATHS")

    pin = True
    pinned_versions = []
    pinned_pkg_rules = []

    # if len(repo_ctx.attr.pin_paths) > 0:
    rootpath = str(repo_ctx.path(Label("@//:WORKSPACE.bazel")))[:-16]
    # print("ROOT DIR: %s" % rootpath)

    ## we need to run this in order to get the pinned paths for verification
    ## "opam config" does not show pinned paths
    pinlist = repo_ctx.execute(["opam", "pin", "list"]).stdout.splitlines()

    pinned_paths = {}
    for pin in pinlist:
        tokens = tokenize(pin)
        # print("TOKENS: %s" % tokens)
        if len(tokens) == 3:
            [name, kind, spec] = tokens
        elif len(tokens) == 4:
            [name, status, kind, spec] = tokens
        else:
            fail("Unexpected result from tokenize: %s" % pin)

        # if kind == "version":
        #     pinned_versions.append(name)   # NB: name = name + "." + version
        # else:
        if kind != "version": # git, rsync, etc
            pinned_paths[name] = [kind.strip(), spec.strip()]
    # for [name, spec] in pinned_paths.items():
    #     print("PINNED PATH: {n} {s}".format(
    #         n=name.strip(),
    #         s=spec
    #     ))

    # is it installed?  opam config var pkg:installed
    # is it pinned?  opam config var pkg:pinned
    # is it the right version?  opam config var pkg:version
    # is pin kind version? opam config var pkg:dev == false
    #    hypothesis: "dev" var is true if pinned to path/git/etc, false if pinned to version

    # for [pkg, [kind, version]] in repo_ctx.attr.pin_specs.items():
    for [pkg, spec] in repo_ctx.attr.pin_specs.items():
        repo_ctx.report_progress("Verifying: '{pkg}.{version}' pinned to {path}".format(
            pkg=pkg, version = spec[0], path=spec[1]
        ))
        # print("Verifying: '{pkg}.{version}' pinned to {path}".format(
        #     pkg=pkg, version = spec[0], path=spec[1]
        # ))
        # is_registered     = opam_is_registered(repo_ctx, pkg)
        is_registered     = opam_property(repo_ctx, pkg, "name", pkg)
        if is_registered:
            # is_installed = opam_is_installed(repo_ctx, pkg)
            is_installed = opam_predicate(repo_ctx, pkg, "installed")
            if is_installed:
                # is_pinned = opam_is_pinned(repo_ctx, pkg)
                is_pinned = opam_predicate(repo_ctx, pkg, "pinned")
                if is_pinned:
                    # version_matches = opam_version_match(repo_ctx, pkg, spec[0])
                    version_matches = opam_property(repo_ctx, pkg, "version", spec[0])
                    if version_matches:
                        is_dev_pkg = opam_predicate(repo_ctx, pkg, "dev")
                        # is_dev_pkg = opam_is_dev_pkg(repo_ctx, pkg)
                        if is_dev_pkg:
                            [kind, pinned_path] = pinned_paths.get(str(pkg + "." + spec[0]), [None, None])
                            if pinned_path == None:
                                print("UNEXPECTED: pinned dev pkg {p} has no matching entry in `opam pin list`")
                                fail("UNEXPECTED: pinned dev pkg {p} has no matching entry in `opam pin list`")
                            else:
                                repo_ctx.report_progress("Verified: '{pkg}.{version}' pinned to {path}".format(
                                    pkg=pkg, version = spec[0], path=spec[1]
                                ))
                            # if paths_match:
                                # print("ALREADY PINNED: %s" % pkg + "." + spec[0] + " " + spec[1])
                                # already_pinned = True
                                ppx = is_ppx_driver(repo_ctx, pkg)
                                pinned_pkg_rules.append(
                                    "opam_pkg(name = \"{pkg}\", ppx_driver={ppx})".format(pkg=pkg, ppx=ppx)
                                )
                            # else:
                            #     print("path mismatch")
                        else:
                            # SHOULD NOT HAPPEN! this routine only handles pinned paths, not pinned versions
                            fail("Unexpected: {pkg}.{version} is pinned but is not a dev pkg".format(
                                pkg = pkg, version = spec[0]
                            ))
                    else:
                        print("WARNING: pinned pkg '{pkg}' version does not match required version '{v}'.".format(
                            pkg=pkg, v=spec[0]
                        ))
                        if repo_ctx.attr.force:
                            print("Repinning '{pkg}' to version {v} at path {path}.".format(
                                pkg=pkg, v=spec[0], path=spec[1]
                            ))
                            opam_rule = opam_repin_pkg_path(repo_ctx, rootpath, pkg, spec[0], spec[1])
                            pinned_pkg_rules.append(opam_rule)
                else:
                    print("WARNING: installed pkg '{pkg}' version does not match required version '{v}'.".format(
                        pkg=pkg, v=spec[0]
                    ))
                    print("Repinning '{pkg}' to version {v} at path {path}.".format(
                        pkg=pkg, v=spec[0], path=spec[1]
                    ))
                    opam_rule = opam_repin_pkg_path(repo_ctx, rootpath, pkg, spec[0], spec[1])
                    print("PINNED %s" % opam_rule)
                    pinned_pkg_rules.append(opam_rule)
            else:
                print("Not installed: pkg {pkg}, version {v}, path {path}".format(
                    pkg=pkg, v=spec[0], path = spec[1]
                ))
                opam_rule = opam_pin_pkg_path(repo_ctx, rootpath, pkg, spec[0], spec[1])
                print("PINNED %s" % opam_rule)
                pinned_pkg_rules.append(opam_rule)
        else:
            print("not registered (opam config var foo:name => not found")

        # if already_pinned:
        #     ppx = is_ppx_driver(repo_ctx, pkg)
        #     pinned_pkg_rules.append(
        #         "opam_pkg(name = \"{pkg}\", ppx_driver={ppx})".format( pkg = pkg, ppx = "False" )
        #     )
        # else:
            # name = pkg + "." + spec[0]
            # if name in pinned_versions:
            #     # print("MATCHED NAME+VERSION")
            #     ppx = is_ppx_driver(repo_ctx, pkg)
            #     pinned_pkg_rules.append(
            #         "opam_pkg(name = \"{pkg}\", ppx_driver={ppx})".format( pkg = pkg, ppx = "False" )
            #     )
            # elif name in pinned_paths:
            #     opam_pkg = _opam_pkg_for_pin_path(repo_ctx, rootpath, pinned_paths, name, pkg, spec)
            #     print("VERIFIED %s" % opam_pkg)
            #     pinned_pkg_rules.append(opam_pkg)
            # else:
            #     # case: pkg is pinned but to different version so name (=name+"."+version) mismatch
            #     # case: same pkg name pinned simultaneously to different versions
            #     #  this is possible because pins are keyed by name + version
            #     opam_pkg = opam_pin_new_path(repo_ctx, rootpath, name, pkg, spec)
            #     print("NEW %s" % opam_pkg)
            #     pinned_pkg_rules.append(opam_pkg)

    return "\n".join(pinned_pkg_rules)

    # if len(repo_ctx.attr.pin_versions) > 0:
    #     repo_ctx.report_progress("pinning OPAM pkgs to versions...")
    #     if len(pinned_versions) == 0:
    #         pinned_versions = repo_ctx.execute(["opam", "pin", "list", "-s"]).stdout.splitlines()
    #     for [pkg, version] in repo_ctx.attr.pin_versions.items():
    #         if not pkg in pinned_versions:
    #             repo_ctx.report_progress("Pinning {pkg} to {v} (may take a while)...".format(
    #                 pkg = pkg, v = version))
    #             pinout = repo_ctx.execute(["opam", "pin", "-v", "-y", "add", pkg, version])
    #             if pinout.return_code != 0:
    #                 print("ERROR opam pin rc: %s" % pinout.return_code)
    #                 print("ERROR stdout: %s" % pinout.stdout)
    #                 print("ERROR stderr: %s" % pinout.stderr)
    #                 fail("OPAM pin add cmd failed")

###################################
def _opam_init_no_verify(repo_ctx):
    repo_ctx.report_progress("OPAM init without pkg verification.")

    opam_pkg_rules = []
    repo_ctx.report_progress("Constructing OPAM pkg rules without verification")
    for [pkg, version] in repo_ctx.attr.opam_pkgs.items():
        ppx = is_ppx_driver(repo_ctx, pkg)
        opam_pkg_rules.append(
            "opam_pkg(name = \"{pkg}\", ppx_driver={ppx})".format( pkg = pkg, ppx = ppx )
        )

    findlib_pkg_rules = []
    repo_ctx.report_progress("Constructing findlib pkg rules without verification")
    for pkg in repo_ctx.attr.findlib_pkgs:
        ppx = is_ppx_driver(repo_ctx, pkg)
        findlib_pkg_rules.append(
            "opam_pkg(name = \"{pkg}\", ppx_driver={ppx})".format( pkg = pkg, ppx = ppx )
        )

    pinned_pkg_rules = []
    repo_ctx.report_progress("Constructing OPAM pinned path pkg rules without verification")
    for [pkg, spec] in repo_ctx.attr.pin_specs.items():
        ppx = is_ppx_driver(repo_ctx, pkg)
        pinned_pkg_rules.append(
            "opam_pkg(name = \"{pkg}\", ppx_driver={ppx})".format(pkg=pkg, ppx=ppx)
        )

    opam_pkgs = "\n".join(opam_pkg_rules + findlib_pkg_rules + pinned_pkg_rules)
    return opam_pkgs

################################
def _opam_init_verify(repo_ctx):
    repo_ctx.report_progress("OPAM init with pkg verification.")

    opam_pkgs    = ""
    findlib_pkgs = ""
    pinned_paths = ""

    if len(repo_ctx.attr.opam_pkgs) > 0:
        opam_pkgs = _config_opam_pkgs(repo_ctx)

    print("OPAMPKGS: %s" % opam_pkgs)

    if len(repo_ctx.attr.findlib_pkgs) > 0:
        findlib_pkgs = _config_findlib_pkgs(repo_ctx)

    print("FINDLIB PKGS: %s" % findlib_pkgs)

    ## WARNING: path pinning must come after version pinning.
    ## Otherwise, e.g. rpc_parallel path pin will fail on missing
    ## ctypes lib.
    if len(repo_ctx.attr.pin_specs) > 0:
        pinned_paths = _pin_paths(repo_ctx)

    print("PINNED PATHS: %s" % pinned_paths)

    opam_pkgs = opam_pkgs + "\n" + findlib_pkgs + "\n" + pinned_paths
    print("PKGS:\n%s" % opam_pkgs)

    return opam_pkgs

##############################
def _opam_repo_impl(repo_ctx):
    debug_report_progress(repo_ctx, "Bootstrapping opam repo")

    if DEBUG:
        if "OPAMSWITCH" in repo_ctx.os.environ:
            print("OPAMSWITCH: %s" % repo_ctx.os.environ["OPAMSWITCH"])

    opam_set_switch(repo_ctx)

    if "OBAZL_OPAM_VERIFY" in repo_ctx.os.environ:
        opam_pkgs = _opam_init_verify(repo_ctx)
    else:
        if repo_ctx.attr.verify:
            opam_pkgs = _opam_init_verify(repo_ctx)
        else:
            opam_pkgs = _opam_init_no_verify(repo_ctx)

        # # verify = repo_ctx.os.environ["OBAZL_OPAM_NOVERIFY"]
        # # print("OBAZL_OPAM_NOVERIFY = %s" % verify)
        # opam_pkgs = _opam_init_no_verify(repo_ctx)

    if DEBUG:
        print("OPAM_PKGS:\n%s" % opam_pkgs)

    # bootstrap @opam with ocaml_import rules
    #     _opam_repo_localhost_imports(repo_ctx)  ## uses bazel rules with ocaml_import

#############################
_opam_repo = repository_rule(
    implementation = _opam_repo_impl,
    configure = True,
    # local = True,
    environ = [
        "OBAZL_OPAM_VERIFY",
        "OPAMSWITCH",
        "CAML_LD_LIBRARY_PATH"
    ],
    attrs = dict(
        hermetic        = attr.bool( default = True ),
        verify          = attr.bool( default = True ),
        install         = attr.bool( default = True ),
        force           = attr.bool( default = False),
        pin             = attr.bool( default = True ),
        switch          = attr.label(default = "@opam_switch//:switch"),

        switch_name     = attr.string(),
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
        debug = attr.bool(default = False)
    )
)

################################################################
def _opam_repo_hidden_impl(repo_ctx):
    repo_ctx.report_progress("Bootstrapping hidden _opam repo...")

    repo_ctx.file("WORKSPACE.bazel", "workspace = ( \"_opam\" )", False)

    opamroot = repo_ctx.execute(["opam", "var", "prefix"]).stdout.strip()
    # print("opamroot: " + opamroot)

    repo_ctx.symlink(opamroot + "/lib", "lib")

    repo_ctx.file(
        "BUILD.bazel",
        content = "exports_files(glob([\"lib/**/*\"]))",
        executable = False,
    )

####################################
_opam_repo_hidden = repository_rule(
    # exposes everything in opam via globbing, for use by ocaml_import rules in ~/.local/share/obazl/opam
    implementation = _opam_repo_hidden_impl,
    local = True,
    # attrs = dict(
    #     hermetic = attr.bool(
    #         default = True
    #     ),
    #     opam_pkgs = attr.string_dict(
    #         doc = "List of OPAM packages to install."
    #     )
    # )
)

################################################################
#     OPAM config structure:
#     opam_version := string
#     switches    := dict(name string, switch struct
# Switch struct:
#     compiler := version string
#     packages := dict(name string, pkg spec)
# Pkg spec:
#     pkg name: ["version_string"]
#               | ["version_string", ["sublib_a", "sublib_b"]]
#               | "path/to/pin"
#  First form pins version, second pins version plus findlib subpackages, third pins path
#     Example:

# PACKAGES = {
#     "base": ["v0.12.0"],
#     "ocaml-compiler-libs": ["v0.11.0", ["compiler-libs.common"]],
#     "ppx_expect": ["v0.12.0", ["ppx_expect.collector"]],
#     "ppx_inline_test": ["v0.12.0", ["ppx_inline_test.runtime-lib"]],
#     "ppxlib": ["0.8.1"],
#     "stdio": ["v0.12.0"],
# }

# opam = struct(
#     version = "2.0",
#     switches = {
#         "mina-0.1.0": struct(    # first entry is default
#             compiler = "4.07.1",  # compiler version
#             packages = PACKAGES
#         ),
#         "4.07.1": struct(
#             name     = "4.07.1",
#             compiler = "4.07.1",  # compiler version
#             packages = PACKAGES
#         )
#     }
# )


def configure(
        opam = None,
        switch   = None,
        # default  = False,
        hermetic = False,
        verify   = False,
        install  = False,
        pin      = False,
        force    = False,
        debug    = False
):
    """Bootstraps and configures OPAM switch and workspaces needed for OPAM support. Returns: configured switch name (string).

    **WARNING** Support for verify/pin/install is not yet fully implemented. Currently verification implies `install=True` and `pin=True`.  Verification with `install=False` and/or `pin=False`, when implemented, will instead emit warnings for missing or misconfigured packages.

    Env vars:

      - OPAMSWITCH: if defined, overrides `switch` attribute and configured default switch
      - OBAZL_OPAM_VERIFY: if defined, overrides `verify=False`
      - OBAZL_OPAM_PIN: if defined, overrides `pin=False`

    Args:
      opam: an [OpamConfig](#provider-opamconfig) provider
      switch: name of OPAM switch to use for builds. Must match a switch defined in [OpamConfig](#provider-opamconfig) specified in `opam` attribute. If omitted, switch configured as `default` in `opam` struct is used.
      hermetic: Currently only `hermetic=False` is supported: the rules use the local opam installation.
      verify: Verify that 1) switch contains required OPAM packages, and 2) they are pinned to required versions
      install: Install missing OPAM packages
      pin:  Pin OPAM packages to required versions
      force:  Force pinning: if installed version does not match required version, remove and install/pin required version
      debug: enable debugging

    """

    if opam == None:
        fail("ERROR: config arg 'opam' is required")

    if hermetic:
        if not opam:
            fail("Hermetic builds require a list of OPAM deps.")

    default_switch = None
    if hasattr(opam, "switches"):
        if (not types.is_dict(opam.switches)):
                fail("opam.switches must be a dict")
        for [k,v] in opam.switches.items():
            if hasattr(v, "default"):
                if v.default:
                    if default_switch == None:
                        default_switch = k
                    else:
                        fail("Only one switch may be marked with 'default = True'")
        if default_switch == None:
            print("One switch must be marked with 'default = True'")
            fail("One switch must be marked with 'default = True'")
            return
    else:
        fail("Config arg 'opam' is missing field 'switches'")

    # if not hasattr(opam, "switches"):
    #     fail("Config arg 'opam' is missing field 'switches'")
    # else:
    #     if (not types.is_dict(opam.switches)):
    #             fail("opam.switches must be a dict")

    if switch == None:
        #     for [k,v] in opam.switches.items():
        #         if hasattr(v, "default"):
        #             if v.default:
        #                 if switch == None:
        #                     switch = k
        #                 else:
        #                     fail("Only one switch may be marked with 'default = True'")
        #     if switch == None:
        #         print("One switch must be marked with 'default = True'")
        #         fail("One switch must be marked with 'default = True'")
        #         return
        #     # print("USING DEFAULT SWITCH: %s" % switch)
        #     force = True
        # else:
        #     force = False
        switch_name = default_switch
    else:
        switch_name = switch

    switch_struct = opam.switches[switch_name]

    if switch_struct == None:
        fail("ERROR: config for switch {s} not defined in config file".format(s=switch_name))
        return

        # if hasattr(switch, "name"):
        #     switch_name = switch.name
        # else:
        #     print("ERROR: opam switch must have name field")
        #     return
        # if hasattr(switch, "version"):
        #     switch_version = switch.version
        # else:
        #     print("ERROR: opam switch must have version field")
        #     return
    if hasattr(switch_struct, "compiler"):
        switch_compiler = switch_struct.compiler
    else:
        fail("ERROR: opam switch must have compiler version field")
        return

    ## if local opam/obazl preconfigured, just use local_repository to point to it
    ## no need to bootstrap a repo in that case
    ## only use this to dynamically construct the ocaml_import rules
    ## not feasible until we can parse the META files in starlark or we have
    ## a fast tool we can call to do it
    # _opam_repo_hidden(name="_opam")

    opam_pkgs    = {}
    findlib_pkgs = []
    pin_specs = {}

    if switch_struct.packages:
        if (not types.is_dict(switch_struct.packages)):
            fail("switch.packages must be a dict")
        for [pkg, spec] in switch_struct.packages.items():
            # print("PKG: {p} SPEC: {s}".format(p=pkg, s=spec))
            if types.is_list(spec):
                if len(spec) == 0: # comes with compiler, or a findlib subpkg?
                    findlib_pkgs.append(pkg)
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
                        fail("switch.packages value entries 2nd element must be list of sublibs")
                else:
                    fail("switch.packages value must be a list of length zero, one or two")
            # elif types.is_string(spec): # path/to/pin
            #     pin_paths[pkg] = spec
            #     # print("PIN PATH: {p} {s}".format(p=pkg, s=pin_paths[pkg]))
            else:
                fail("switch.packages value entries must be list or string")

    # print("OPAM_PKGS: %s" % opam_pkgs)
    # print("FINDLIB_PKGS: %s" % findlib_pkgs)

    # pin_versions = {}
    # pins_install = False
    # if opam != None:
    #     if hasattr(opam, "pins"):
    #         if hasattr(opam.pins, "paths"):
    #             pin_paths = opam.pins.paths
    #         if hasattr(opam.pins, "versions"):
    #             pin_versions = opam.pins.versions
    #         if hasattr(opam.pins, "install"):
    #             pins_install = opam.pins.install

    # maybe(
    #     git_repository,
    #     name = "obazl_tools_bazel",
    #     remote = "https://github.com/obazl/tools_bazel",
    #     branch = "main",
    # )
    # print("PIN_SPECS: %s" % pin_specs)

    # _opam_switch_repo(name = "opam_switch")

    _opam_repo(name="opam",
               hermetic = hermetic,
               verify   = verify,
               install  = install,
               force    = force,
               pin      = pin,
               switch_name = switch_name,
               switch_compiler = switch_compiler,
               opam_pkgs = opam_pkgs,
               findlib_pkgs = findlib_pkgs,
               pin_specs = pin_specs,
               debug = debug)

    return switch_name
