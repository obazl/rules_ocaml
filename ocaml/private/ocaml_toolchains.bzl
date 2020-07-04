load("//ocaml/private:common.bzl",
    "OCAML_VERSION")
load("//ocaml/private:providers.bzl",
     "OpamPkgInfo",
     "PpxInfo")
load("//opam:opam.bzl",
     "OPAMROOT")
load("//ocaml/private:utils.bzl",
     "strip_ml_extension",
     "OCAML_FILETYPES"
)

# print("private/ocaml.bzl loading")

# load("//ocaml:repo.bzl", "OPAM_ROOT_DIR", "OCAML_VERSION", "COMPILER_NAME")
_ocaml_tools_attrs = {
  "path": attr.string(),
  "sdk_home": attr.string(),
  "opam_root": attr.string(),
  "_opam": attr.label(
    default = Label("@opam//:opam"),
    executable = True,
    allow_single_file = True,
    # allow_files = True,
        cfg = "host",
  ),
  # "_compiler": attr.string(
  #   default = "ocamlopt",
  #   # executable = True,
  #   # cfg = "host",
  #   ),
  "_ocamlc": attr.label(
    default = Label("@ocaml//:ocamlc"),
    executable = True,
    allow_single_file = True,
    cfg = "host",
  ),
  "_compiler": attr.label(
    default = Label("@ocaml//:ocamlopt"),
    executable = True,
    allow_single_file = True,
    cfg = "host",
  ),
  "_ocamlopt": attr.label(
    default = Label("@ocaml//:ocamlopt"),
    executable = True,
    allow_single_file = True,
    cfg = "host",
  ),
  "_opts": attr.string_list(
    default = [
      "-strict-formats", # Reject invalid formats accepted by legacy implementationsg
      "-short-paths", # use shortest path printing type names in inferred interfaces, error, warning msgs
      "-strict-sequence", # Left-hand part of a sequence must have type unit
      # "-no-alias-deps",
      # "-opaque"
    ]
  ),
  "_ocamlfind": attr.label(
    default = Label("@ocaml//:ocamlfind"),
    executable = True,
    allow_single_file = True,
    cfg = "host",
  ),
  "_ocamlbuild": attr.label(
    default = Label("@ocaml//:ocamlbuild"),
    executable = True,
    allow_single_file = True,
    cfg = "host",
  ),
  "_ocamldep": attr.label(
    default = Label("@ocaml//:ocamldep"),
    executable = True,
    allow_single_file = True,
    cfg = "host",
  ),
  "_objext": attr.string(
    default = ".cmx",
  )
}

def _ocaml_toolchain_impl(ctx):
  # sdk = ctx.attr.sdk[OcamlSDK]
  return [platform_common.ToolchainInfo(
    # Public fields
    name = ctx.label.name,
    path       = ctx.attr.path,
    sdk_home   = ctx.attr.sdk_home,
    opam_root  = ctx.attr.opam_root,
    opam       = ctx.attr._opam.files.to_list()[0],
    compiler   = ctx.attr._compiler.files.to_list()[0],
    ocamlc     = ctx.attr._ocamlc.files.to_list()[0],
    ocamlopt   = ctx.attr._ocamlopt.files.to_list()[0],
    opts      = ctx.attr._opts,
    ocamlbuild = ctx.attr._ocamlbuild.files.to_list()[0],
    ocamlfind  = ctx.attr._ocamlfind.files.to_list()[0],
    ocamldep   = ctx.attr._ocamldep.files.to_list()[0],
    objext   = ctx.attr._objext
    )]

ocaml_toolchain = rule(
  _ocaml_toolchain_impl,
  attrs = _ocaml_tools_attrs,
  doc = "Defines a Ocaml toolchain based on an SDK",
  provides = [platform_common.ToolchainInfo],
)
