load("//ocaml/_providers:opam.bzl", "OpamPkgInfo")

################################################################
def _opam_pkg_impl(ctx):
  ## client should do:
  ## dep[OpamPkgInfo].pkg.to_list()[0].name)
  return [OpamPkgInfo(
      pkg = depset(direct = [ctx.label]),
      ppx_driver = ctx.attr.ppx_driver
  )]

opam_pkg = rule(
    implementation = _opam_pkg_impl,
    attrs = dict(
        ppx_driver = attr.bool(
            doc = "True if META contains ppx(-ppx_driver...) or ppxopt(-ppx_driver...), indicating that ocamlfind will generate a -ppx/--as-ppx arg if this lib is listed as a dependency.",
            default = False
        )
    ),
    provides = [OpamPkgInfo]
)
