load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:types.bzl", "types")

load("//ocaml/_debug:utils.bzl", "debug_report_progress")

################################
def _install_opam_templates(repo_ctx): ## , projroot, opam_switch_prefix):
    repo_ctx.report_progress("installing opam templates")
    print("installing opam templates")

    xr = repo_ctx.execute(["opam_bootstrap"])
    if xr.return_code == 0:
        print("opam_bootstrap result: %s" % xr.stdout)
    else:
        print("opam_bootstrap result: %s" % xr.stdout)
        print("opam_bootstrap rc: {rc} stderr: {stderr}".format(rc=xr.return_code, stderr=xr.stderr));
        fail("Comand failed: opam_bootstrap")

    # repo_ctx.template(
    #     "BUILD.bazel",
    #     Label(ws + "//ocaml/_templates:BUILD.ocaml"),
    #     executable = False,
    #     substitutions = {
    #         "{sdkpath}": opam_switch_prefix,
    #         "{projroot}": str(projroot)
    #     },
    # )

###############################
def _opam_repo_impl(repo_ctx):
    repo_ctx.report_progress("Bootstrapping opam repo")
    # if repo_ctx.attr.debug:
    print("_opam_repo_impl")

    # _install_opam(repo_ctx, projroot, opam_switch_prefix)

    # _install_opam_symlinks(repo_ctx, opam_root, opam_switch_prefix)

    xr = repo_ctx.execute(["opam_bootstrap"])
    # xr = repo_ctx.execute(["time", "opam_bootstrap"])
    if xr.return_code == 0:
        print("opam_bootstrap stdout: %s" % xr.stdout)
        # print("opam_bootstrap stderr: %s" % xr.stderr)
    else:
        print("opam_bootstrap result: %s" % xr.stdout)
        print("opam_bootstrap rc: {rc} stderr: {stderr}".format(rc=xr.return_code, stderr=xr.stderr));
        fail("Comand failed: opam_bootstrap")

#############################
_opam_repo = repository_rule(
    implementation = _opam_repo_impl,
    configure = True,
    local = True,
    environ = [
        "OBAZL_OPAM_VERIFY",
        "OPAMSWITCH",
        "CAML_LD_LIBRARY_PATH"
    ],
    attrs = dict(
        verbose = attr.bool(default = False),
        debug   = attr.bool(default = False)
    )
)

##############################
# def configure(debug = False, opam = None): # , **kwargs):
def opam_configure():
    # is_rules_ocaml = False,
    #                 opam = None):
    """Configure @opam"""

    print("opam_configure")

    _opam_repo(name="opam")

    print("opam_configure done")
