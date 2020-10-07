load("@obazl_rules_ocaml//opam:opam.bzl", "ocamlfind_package")

package(default_visibility = ["//visibility:public"])

constraint_setting(name = "has_pkg")

constraint_value(
    name = "has_bytes",
    constraint_setting = ":has_pkg",
)

# {has_pkg_values}

{ocamlfind_packages}
