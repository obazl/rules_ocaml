load("@obazl_rules_ocaml//opam:opam.bzl", "ocamlfind_package")

package(default_visibility = ["//visibility:public"])

# filegroup(
#     name = "migrate_parsetree",
#     srcs = ["//sdk/lib/ocaml-migrate-parsetree/driver-main/migrate_parsetree_driver_main.ml"],
# )

{ocamlfind_packages}
