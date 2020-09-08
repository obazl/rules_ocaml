def _obazl_repo_impl(repository_ctx):

    repository_ctx.file("WORKSPACE", "", False)
    repository_ctx.template(
        "BUILD.bazel",
        Label("@obazl_rules_ocaml//opam:BUILD.opam.tpl"),
        executable = False,
        # substitutions = { "{ocamlfind_packages}": ocamlfind_pkgs }
    )

    repository_ctx.template(
        "ppxlib/BUILD.bazel",
        Label("@obazl_rules_ocaml//obazl:ppxlib/BUILD.tpl"),
        executable = False,
    )
    repository_ctx.file(
        "ppxlib/ppxlib_driver_standalone_runner.ml",
        content = "(* GENERATED FILE - DO NOT EDIT *)\nlet () = Ppxlib.Driver.standalone ()",
        executable = False,
    )
    repository_ctx.template(
        "ppx/BUILD.bazel",
        Label("@obazl_rules_ocaml//obazl:ppx/BUILD.tpl"),
        executable = False,
    )
    repository_ctx.file(
        "ppx/ppx_inline_test_lib_runtime_exit.ml",
        content = "(* GENERATED FILE - DO NOT EDIT *)\nlet () = Ppx_inline_test_lib.Runtime.exit ();;",
        executable = False,
    )

obazl_repo = repository_rule(
    implementation = _obazl_repo_impl,
    attrs = {}
)
