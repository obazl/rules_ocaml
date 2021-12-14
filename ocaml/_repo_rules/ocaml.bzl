load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:types.bzl", "types")

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
def _ocaml_repo_impl(repo_ctx):
    repo_ctx.report_progress("Bootstrapping ocaml repo")

    # repo_ctx.file("BUILD.bazel",
    #               content = "## do not remove")

    rules_ocaml = str(repo_ctx.path("@rules_ocaml"))
    print("rules_ocaml: %s" % rules_ocaml)

    subdir = repo_ctx.path("../rules_ocaml//ocaml_workspace")
    print("subdir: %s" % subdir)
    files = subdir.readdir()
    for file in files:
        print("linking: %s" % file.basename)
        repo_ctx.symlink(file, file.basename)

    print("finished linking @ocaml")
    # repo_ctx.symlink(opam_switch_prefix + "/lib/ocaml", "lib")

    # _install_opam_symlinks(repo_ctx, opam_root, opam_switch_prefix)

#############################
_ocaml_repo = repository_rule(
    implementation = _ocaml_repo_impl,
    configure = True,
    local = True,
    attrs = dict(
    )
)

##############################
def ocaml_repository():
    _ocaml_repo(name="ocaml")
