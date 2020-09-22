load("//ocaml/private:providers.bzl",
    "OpamPkgInfo")
load("//ocaml/private:common.bzl",
    "OCAML_VERSION")

# # The path to the root opam directory within external
# OPAMROOT = "OPAMROOT"

# print("private/ocaml.bzl loading")

# Set up OPAM
def is_ppx_driver(repository_ctx, pkg):
    query_result = repository_ctx.execute(["ocamlfind", "printppx", pkg]).stdout.strip()
    # print("IS PPX DRIVER? {pkg} : {ppx}".format( pkg = pkg, ppx = len(query_result)))
    if len(query_result) == 0:
        return False
    else:
        return True

def _opam_repo_impl(repository_ctx):
    print("_opam_binary_impl")
    opamroot = repository_ctx.execute(["opam", "var", "prefix"]).stdout.strip()
    # print("opamroot: " + opamroot)

    ## TODO: use 'ocamlfind list' to get a list of all installed pkgs
    pkgs = repository_ctx.execute(["ocamlfind", "list"]).stdout.splitlines()
    packages = []
    for pkg in pkgs:
      packages.append(pkg.split(" ")[0])

    ocamlfind_packages = []
    for p in packages:
        ## WARNING: this is slow
        ppx = is_ppx_driver(repository_ctx, p)
        ocamlfind_packages.append(
            "ocamlfind_package(name = \"{pkg}\", ppx_driver={ppx})".format( pkg = p, ppx = ppx )
        )
    # print("ocamlfind pkgs:")
    # for p in ocamlfind_packages:
    #   print(p)
    ocamlfind_pkgs = "\n".join(ocamlfind_packages)

    opambin = repository_ctx.which("opam") # "/usr/local/Cellar/opam/2.0.7/bin"
    # if "OPAM_SWITCH_PREFIX" in repository_ctx.os.environ:
    #     opampath = repository_ctx.os.environ["OPAM_SWITCH_PREFIX"] + "/bin"
    # else:
    #     fail("Env. var OPAM_SWITCH_PREFIX is unset; try running 'opam env'")
    repository_ctx.symlink(opambin, "opam")
    repository_ctx.symlink(opamroot, "sdk")
    repository_ctx.file("WORKSPACE", "", False)
    repository_ctx.template(
        "BUILD.bazel",
        Label("@obazl_rules_ocaml//opam:BUILD.opam.tpl"),
        executable = False,
        # substitutions = { "{ocamlfind_packages}": ocamlfind_pkgs }
    )
    repository_ctx.template(
        "pkg/BUILD.bazel",
        Label("@obazl_rules_ocaml//opam:BUILD.opampkg.tpl"),
        executable = False,
        substitutions = { "{ocamlfind_packages}": ocamlfind_pkgs }
    )
#     repository_ctx.file(
#         "sdk/lib/integers/BUILD.bazel",
#         content = """load("@obazl_rules_ocaml//ocaml:build.bzl", "ocaml_import")

#     # repository_ctx.template(
#     #     "ppx/BUILD.bazel",
#     #     Label("@obazl_rules_ocaml//opam:ppx/BUILD.tpl"),
#     #     executable = False,
#     # )
#     # repository_ctx.file(
#     #     "ppx/ppx_inline_test_lib_runtime_exit.ml",
#     #     content = "(* GENERATED FILE - DO NOT EDIT *)\nlet () = Ppx_inline_test_lib.Runtime.exit ();;",
#     #     executable = False,
#     # )

#     # repository_ctx.template(
#     #     "ppxlib/BUILD.bazel",
#     #     Label("@obazl_rules_ocaml//opam:ppxlib/BUILD.tpl"),
#     #     executable = False,
#     #     # substitutions = { "{ocamlfind_packages}": ocamlfind_pkgs }
#     #     # substitutions = {"{pkg}": "ppxlib.metaquot"}
#     # )
#     # repository_ctx.file(
#     #     "ppxlib/ppxlib_driver_standalone_runner.ml",
#     #     content = "(* GENERATED FILE - DO NOT EDIT *)\nlet () = Ppxlib.Driver.standalone ()",
#     #     executable = False,
#     # )

# ocaml_import(
#     name = \"integers\",
#     cmxa = "integers.cmxa",
#     visibility = [\"//visibility:public\"],
# )
# """,
#         executable = False,
#     )

#     repository_ctx.file(
#         "sdk/lib/ocaml/BUILD.bazel",
#         content = """load("@rules_cc//cc:defs.bzl", "cc_library")

# cc_library(
#     name = \"csdk\",
#     hdrs = glob([\"caml/*.h\"]),
#     visibility = [\"//visibility:public\"],
# )
# """,
#         executable = False,
#     )

#     repository_ctx.file(
#         "sdk/lib/ctypes/BUILD.bazel",
#         content = """load("@rules_cc//cc:defs.bzl", "cc_library")
# load("@obazl_rules_ocaml//ocaml:build.bzl", "ocaml_import")

# cc_library(
#     name = \"cc\",
#     hdrs = glob([\"*.h\"]),
#     visibility = [\"//visibility:public\"],
# )

# ocaml_import(
#     name = \"ctypes\",
#     cmxa = \"ctypes.cmxa",
#     deps = ["@opam//sdk/lib/integers"],
#     visibility = [\"//visibility:public\"],
# )

# ocaml_import(
#     name = \"stubs\",
#     cmxa = \"cstubs.cmxa",
#     deps = [":ctypes"],
#     visibility = [\"//visibility:public\"],
# )
# """,
#         executable = False,
#     )


# def _opam_download_impl(repository_ctx):
#     # print("_opam_download_impl")
#     os_name = repository_ctx.os.name.lower()
#     if os_name.find("windows") != -1:
#         fail("Windows is not supported yet, sorry!")
#     elif os_name.startswith("mac os"):
#         repository_ctx.download(
#             "https://github.com/ocaml/opam/releases/download/2.0.0-beta4/opam-2.0.0-beta4-x86_64-darwin",
#             "opam",
#             "d23c06f4f03de89e34b9d26ebb99229a725059abaf6242ae3b9e9bf946b445e1",
#             executable = True,
#         )
#     else:
#         repository_ctx.download(
#             "https://github.com/ocaml/opam/releases/download/2.0.0-beta4/opam-2.0.0-beta4-x86_64-linux",
#             "opam",
#             "3de4b78a263d4c1e46760c26bdc2b02fdbce980a9fc9141385058c2b0174708c",
#             executable = True,
#         )
#     repository_ctx.file("WORKSPACE", "", False)
#     repository_ctx.file("BUILD.bazel", "exports_files([\"opam\"])", False)

opam_repo = repository_rule(
    implementation = _opam_repo_impl,
    local = True,
    attrs = {}
)

def _ocamlfind_package_impl(ctx):
  ## client should do:
  ## dep[OpamPkgInfo].pkg.to_list()[0].name)
  return [OpamPkgInfo(
      pkg = depset(direct = [ctx.label]),
      ppx_driver = ctx.attr.ppx_driver
  )]

ocamlfind_package = rule(
    implementation = _ocamlfind_package_impl,
    attrs = dict(
        ppx_driver = attr.bool(
            doc = "True if META contains ppx(-ppx_driver...) or ppxopt(-ppx_driver...), indicating that ocamlfind will generate a -ppx/--as-ppx arg if this lib is listed as a dependency.",
            default = False
        )
    ),
    provides = [OpamPkgInfo]
)
