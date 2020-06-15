package(default_visibility = ["//visibility:public"])

filegroup(
    name = "all_files",
    testonly = True,
    srcs = glob(["**"]) + [
        "//ocaml/config:all_files",
        "//ocaml/platform:all_files",
        "//ocaml/toolchain:all_files",
        "//ocaml/tools:all_files",
        "//ocaml/private:all_files",
    ],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "all_rules",
    srcs = glob(["*.bzl"]) + [
        "//ocaml/platform:all_rules",
        "//ocaml/private:all_rules",
        "//ocaml/toolchain:all_rules",
    ],
    visibility = ["//visibility:public"],
)

toolchain_type(
    name = "toolchain",
    visibility = ["//visibility:public"],
)

# config_setting(
#     name = "darwin",
#     values = {"host_cpu": "darwin"},
# )

# config_setting(
#     name = "k8",
#     values = {"host_cpu": "k8"},
# )
