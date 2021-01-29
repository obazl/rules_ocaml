load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/_providers:ocaml.bzl",
     "CompilationModeSettingProvider",
     "OcamlArchiveProvider",
     "OcamlDepsetProvider",
     "OcamlInterfaceProvider",
     "OcamlInterfacePayload",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider")

load("@obazl_rules_opam//opam/_providers:opam.bzl", "OpamPkgInfo")

load("//ppx:_providers.bzl",
     "PpxArchiveProvider",
     "PpxExecutableProvider",
     "PpxNsModuleProvider")

load("//ocaml/_rules/utils:rename.bzl", "rename_module")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_deps:depsets.bzl", "get_all_deps")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "file_to_lib_name",
     "get_opamroot",
     "get_sdkpath",
)

OCAML_INTF_FILETYPES = [
    ".mli", ".cmi"
]

########## RULE:  OCAML_INTERFACE  ################
def _ocaml_yacc_impl(ctx):

  debug = False
  # if (ctx.label.name == "_Impl"):
  #     debug = True

  if debug:
      print("OCAML YACC TARGET: %s" % ctx.label.name)

  mode = ctx.attr._mode[CompilationModeSettingProvider].value

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  yaccer_fname = paths.replace_extension(ctx.file.src.basename, ".ml")
  yacceri_fname = paths.replace_extension(ctx.file.src.basename, ".mli")

  tmpdir = "_obazl_/"

  yaccer = ctx.actions.declare_file(tmpdir + yaccer_fname)
  yacceri = ctx.actions.declare_file(tmpdir + yacceri_fname)

  # if debug:
  #     print("yaccer: %s" % yaccer)

  ################################################################
  # args = ctx.actions.args()

  # args.add_all(ctx.attr.opts)

  # args.add(ctx.file.src)

  ctx.actions.run_shell(
      inputs  = [ctx.file.src],
      outputs = [yaccer, yacceri],
      tools   = [tc.ocamlyacc],
      command = "\n".join([
          ## ocamlyacc is inflexible, it writes to cwd, that's it.
          ## so we copy source to output dir, cd here, and run ocamlyacc
          "cp {src} {dest}".format(src = ctx.file.src.path, dest=yaccer.dirname),
          "cd {dest} && {tool} {src}".format(
              dest=yaccer.dirname,
              tool = tc.ocamlyacc.basename,
              src=ctx.file.src.basename,
          ),

      ])
      # env = env,
      # executable = tc.ocamlyacc,
      # arguments = [args],
      # inputs = [ctx.file.src],
      # outputs = [yaccer],
      # tools = [tc.ocamlyacc],
      # mnemonic = "OcamlYacc",
      # progress_message = "{mode} ocaml_yacc: @{ws}//{pkg}:{tgt}".format(
      #     mode = mode,
      #     ws  = ctx.label.workspace_name,
      #     pkg = ctx.label.package,
      #     tgt=ctx.label.name
      # )
  )

  return [DefaultInfo(files = depset(direct = [yaccer]))]

#################
ocaml_yacc = rule(
    implementation = _ocaml_yacc_impl,
    doc = """Generates an OCaml source file from an ocamlyacc source file.
    """,
    attrs = dict(
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        src = attr.label(
            doc = "A single .mly ocamlyacc source file label",
            allow_single_file = [".mly"]
        ),
        opts = attr.string_list(
            doc = "Options"
        ),
        _mode       = attr.label(
            default = "@ocaml//mode",
        ),
        _rule = attr.string( default = "ocaml_yacc" )
    ),
    # provides = [],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
