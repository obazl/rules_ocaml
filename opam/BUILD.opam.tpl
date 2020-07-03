load("@obazl_rules_ocaml//opam:opam.bzl", "ocamlfind_package")

package(default_visibility = ["//visibility:public"])

exports_files(["opam"])
