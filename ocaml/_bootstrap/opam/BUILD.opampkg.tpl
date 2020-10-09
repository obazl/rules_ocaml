load("@obazl_rules_ocaml//opam:rules.bzl", "opam_pkg")

package(default_visibility = ["//visibility:public"])

constraint_setting(name = "has_pkg")

constraint_value(
    name = "has_bytes",
    constraint_setting = ":has_pkg",
)

# {has_pkg_values}

{opam_pkgs}
