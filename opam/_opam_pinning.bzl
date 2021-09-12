load("//opam/_functions:ppx.bzl", "is_ppx_driver")

#####################
def _opam_unpin(repo_ctx, pkg):
    repo_ctx.report_progress("Unpinning {pkg}".format(pkg=pkg))
    result = repo_ctx.execute(["opam", "unpin", "-y", pkg])

    if result.return_code == 0:
        repo_ctx.report_progress("Unpinned {pkg}.".format(pkg=pkg))
        return True
    else:
        print("ERROR cmd 'opam unpin {pkg}".format( pkg=pkg ))
        print("ERROR RC: %s" % result.return_code)
        print("ERROR STDOUT: %s" % result.stdout)
        print("ERROR STDERR: %s" % result.stderr)
        fail("OPAM unpin failed")

#####################
def _opam_remove(repo_ctx, pkg):
    repo_ctx.report_progress("Removing {pkg}".format(pkg=pkg))
    result = repo_ctx.execute(["opam", "remove", "-y", pkg])

    if result.return_code == 0:
        repo_ctx.report_progress("Removed {pkg}.".format(pkg=pkg))
        return True
    else:
        print("ERROR cmd 'opam remove {pkg}".format( pkg=pkg ))
        print("ERROR RC: %s" % result.return_code)
        print("ERROR STDOUT: %s" % result.stdout)
        print("ERROR STDERR: %s" % result.stderr)
        fail("OPAM remove failed")

#######################################
def opam_pin_pkg_path(repo_ctx, rootpath, pkg, version, path):
    print("PIN_NEW_PATH: {pkg}.{version} : {path}".format(
        pkg = pkg, version=version, path=path
    ))

    if path.startswith("https://"):
        path = path
    elif path.startswith("http://"):
        path = path
    else:
        path = rootpath + "/" + path

    install_name = pkg + "." + version
    repo_ctx.report_progress("Pinning {name} to {path} (may take a while)...".format(
        name = install_name,
        path = path
    ))
    ## FIXME: add --switch
    pinout = repo_ctx.execute(["opam", "pin", "-v", "-y",
                               "add", install_name, path])

    if pinout.return_code == 0:
        repo_ctx.report_progress("Pinned {path}.".format(path = path))
        is_ppx = is_ppx_driver(repo_ctx, pkg)
        result = "opam_pkg(name = \"{pkg}\", ppx_driver={ppx})".format( pkg = pkg, ppx = is_ppx )
    else:
        print("ERROR cmd 'opam pin -v -y add {name} {path}".format(
            name = install_name, path = path
        ))
        print("ERROR RC: %s" % pinout.return_code)
        print("ERROR STDOUT: %s" % pinout.stdout)
        print("ERROR STDERR: %s" % pinout.stderr)
        fail("ERROR cmd 'opam pin -v -y add {name} {path}' RC: {rc}. STDOUT: {stdout} STDERR: {stderr}".format(
            name = install_name, path = path, rc = pinout.return_code,
            stdout = pinout.stdout, stderr = pinout.stderr
        ))

    return result

#######################################
def opam_repin_pkg_path(repo_ctx, rootpath, pkg, version, path):
    repo_ctx.report_progress("Repinning {pkg} to version '{version}', path '{path}'".format(
        pkg = pkg, version=version, path=path
    ))
    # if path.startswith("https://"):
    #     path = path
    # elif path.startswith("http://"):
    #     path = path
    # else:
    #     path = rootpath + "/" + path

    # install_name = pkg + "." + version
    _opam_unpin(repo_ctx, pkg)
    _opam_remove(repo_ctx, pkg) ## FIXME: is this necessary?

    return opam_pin_pkg_path(repo_ctx, rootpath, pkg, version, path)

#####################################################
# def opam_repin_version_path(repo_ctx, rootpath, pkg, version, path):
#     repo_ctx.report_progress("Repinning {pkg} to version '{v}', path '{path}'".format(
#         pkg=pkg, v=version, path=path))
#     _opam_unpin(repo_ctx, pkg)
#     _opam_remove(repo_ctx, pkg) ## FIXME: is this necessary?
#     return opam_pin_pkg_path(repo_ctx, rootpath, pkg, version, path)

