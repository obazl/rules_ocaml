workspace(name = "obazl")

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@obazl//ocaml:deps.bzl", "ocaml_register_toolchains",
     # "ocaml_rules_dependencies"
)

# ocaml_rules_dependencies(is_rules_ocaml = True)

ocaml_register_toolchains()

# Needed for tests
load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()
