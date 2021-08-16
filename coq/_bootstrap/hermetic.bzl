load("@bazel_skylib//lib:collections.bzl", "collections")
# load("//implementation:common.bzl",
#     "OCAML_VERSION")

# 4.07.1 broken on XCode 12:
# https://discuss.ocaml.org/t/ocaml-4-07-1-fails-to-build-with-apple-xcode-12/6441/15
OCAML_VERSION = "4.08.0"
OCAMLBUILD_VERSION = "0.14.0"
OCAMLFIND_VERSION = "1.8.1"
COMPILER_NAME = "ocaml-base-compiler.%s" % OCAML_VERSION
OPAM_ROOT_DIR = ".opam_root_dir"
# Set to false to see debug messages
DEBUG_QUIET = False

# # The path to the root opam directory within external
# OPAMROOT = "OPAMROOT"

def opam_repo_hermetic(repo_ctx):
    repo_ctx.report_progress("Bootstrapping hermetic OPAM...")
    for i in range(10000000): x = i # pause

    repo_ctx.report_progress("Initializing opam and its root directory: {}".format(OPAM_ROOT_DIR))
    for i in range(10000000): x = i # pause

    ## download opam binary
    os_name = repo_ctx.os.name.lower()
    if os_name.find("windows") != -1:
        fail("Windows is not supported yet, sorry!")
    elif os_name.startswith("mac os"):
        repo_ctx.download(
            url = "https://github.com/ocaml/opam/releases/download/2.0.0-beta4/opam-2.0.0-beta4-x86_64-darwin",
            output = "opam",
            sha256 = "d23c06f4f03de89e34b9d26ebb99229a725059abaf6242ae3b9e9bf946b445e1",
            executable = True,
        )
    else:
        repo_ctx.download(
            url = "https://github.com/ocaml/opam/releases/download/2.0.0-beta4/opam-2.0.0-beta4-x86_64-linux",
            output = "opam",
            sha256 = "3de4b78a263d4c1e46760c26bdc2b02fdbce980a9fc9141385058c2b0174708c",
            executable = True,
        )
    repo_ctx.file("WORKSPACE.bazel", "", False)
    repo_ctx.file("BUILD", "exports_files([\"opam\"])", False)

    opam_bin = "opam"
    repo_ctx.report_progress("Initializing opam and its root directory..")
    for i in range(10000000): x = i # pause
    repo_ctx.execute([
        opam_bin,
        "init",
        "-vv",
        "--root", OPAM_ROOT_DIR,
        "--no-setup",
        "--no-opamrc",
        "--compiler", COMPILER_NAME
    ], quiet = DEBUG_QUIET)

    repo_ctx.report_progress("Installing {}".format(COMPILER_NAME))
    for i in range(10000000): x = i # pause
    repo_ctx.execute([
        opam_bin,
        "switch", COMPILER_NAME,
        "--root", OPAM_ROOT_DIR
    ], quiet = DEBUG_QUIET)

    repo_ctx.report_progress("Installing ocamlfind {}".format(OCAMLFIND_VERSION))
    for i in range(10000000): x = i # pause
    repo_ctx.execute([
        opam_bin,
        "install",
        "ocamlfind=%s" % OCAMLFIND_VERSION,
        "--yes",
        "--root", OPAM_ROOT_DIR
    ], quiet = DEBUG_QUIET)

    repo_ctx.report_progress("Installing opam packages..")
    for i in range(10000000): x = i # pause
    [repo_ctx.execute([
        opam_bin,
        "install",
        "%s=%s" % (pkg, version),
        "--yes",
        "--root", OPAM_ROOT_DIR
    ], quiet = DEBUG_QUIET)
     for (pkg, version) in repo_ctx.attr.opam_pkgs.items()]

    # _opam_repo_nonhermetic(repo_ctx)
