# load("@obazl_rules_ocaml//opam:rules.bzl", "opam_pkg")

# package(default_visibility = ["//visibility:public"])

exports_files(["opam"])

exports_files(glob(["bin/*"]))

exports_files(glob(["lib/**"]))
