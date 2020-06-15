load("@obazl//ocaml/private:common.bzl",
    "OCAML_VERSION")
load("@obazl//ocaml/private:providers.bzl",
     "OpamPkgInfo",
     "PpxInfo")
load("@obazl//opam:opam.bzl",
     "OPAMROOT")
load("@obazl//ocaml/private:utils.bzl",
     "strip_ml_extension",
     "OCAML_FILETYPES"
)

# print("private/ocaml.bzl loading")

# load("//ocaml:repo.bzl", "OPAM_ROOT_DIR", "OCAML_VERSION", "COMPILER_NAME")
_ocaml_tools_attrs = {
    "_opam": attr.label(
        default = Label("@opam//:opam"),
        executable = True,
        allow_single_file = True,
        # allow_files = True,
        cfg = "host",
    ),
    "_ocamlc": attr.label(
        default = Label("@ocaml_sdk//:ocamlc"),
        executable = True,
        allow_single_file = True,
        # allow_files = True,
        cfg = "host",
    ),
    "_ocamlopt": attr.label(
        default = Label("@ocaml_sdk//:ocamlopt"),
        executable = True,
        allow_single_file = True,
        # allow_files = True,
        cfg = "host",
    ),
    "_ocamlfind": attr.label(
        default = Label("@ocaml_sdk//:ocamlfind"),
        executable = True,
        allow_single_file = True,
        # allow_files = True,
        cfg = "host",
    ),
    "_ocamlbuild": attr.label(
        default = Label("@ocaml_sdk//:ocamlbuild"),
        executable = True,
        allow_single_file = True,
        # allow_files = True,
        cfg = "host",
    ),
    "_ocamldep": attr.label(
        default = Label("@ocaml_sdk//:ocamldep"),
        executable = True,
        allow_single_file = True,
        cfg = "host",
    )
}

def _ocaml_toolchain_impl(ctx):
  # sdk = ctx.attr.sdk[OcamlSDK]
  return [platform_common.ToolchainInfo(
    # Public fields
    name = ctx.label.name,
    opam       = ctx.attr._opam.files.to_list()[0],
    ocamlbuild = ctx.attr._ocamlbuild.files.to_list()[0],
    ocamlfind  = ctx.attr._ocamlfind.files.to_list()[0],
    ocamlc     = ctx.attr._ocamlc.files.to_list()[0],
    ocamlopt   = ctx.attr._ocamlopt.files.to_list()[0],
    ocamldep   = ctx.attr._ocamldep.files.to_list()[0]
    )]

ocaml_toolchain = rule(
  _ocaml_toolchain_impl,
  attrs = _ocaml_tools_attrs,
  doc = "Defines a Ocaml toolchain based on an SDK",
  provides = [platform_common.ToolchainInfo],
)
