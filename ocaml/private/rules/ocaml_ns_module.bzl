load("@bazel_skylib//lib:paths.bzl", "paths")

load("@obazl//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OpamPkgInfo",
     "OcamlModuleProvider")
load("@obazl//ocaml/private:actions/ppx.bzl",
     "apply_ppx",
     "ocaml_ppx_compile",
     # "ocaml_ppx_apply",
     "ocaml_ppx_library_gendeps",
     "ocaml_ppx_library_cmo",
     "ocaml_ppx_library_compile",
     "ocaml_ppx_library_link")
load("@obazl//ocaml/private:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)
# testing
load("@obazl//ocaml/private:actions/ocamlopt.bzl",
     "compile_native_with_ppx",
     "link_native")

# print("private/ocaml.bzl loading")


########## RULE:  OCAML_NS_MODULE  ################
## Generate a namespacing module, containing module aliases for the
## namespaced submodules listed as sources.

def _ocaml_ns_module_impl(ctx):
  tc = ctx.toolchains["@obazl//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  ## generate content: one alias per submodule
  aliases = []
  pfx = capitalize_initial_char(ctx.attr.ns)
  for sm in ctx.files.submodules:
        alias = "module {sm} = {pfx}{sm}".format(
          sm=capitalize_initial_char(paths.split_extension(sm.basename)[0]),
          pfx = pfx
        )
        aliases.append(alias)
  print("ALIASES: %s" % aliases)

  ## declare ns module file, as input to compile action
  module_fname = (ctx.attr.module_name if ctx.attr.module_name else ctx.label.name) + ".ml"
  module_src = ctx.actions.declare_file(module_fname)
  print("NS MODULE SRC: %s" % module_src)

  ## action: generate ns module file with alias content
  ctx.actions.write(
    output = module_src,
    content = "\n".join(aliases) + "\n"
  )

  ## now declare compilation outputs. compiling always produces 3 files:
  obj_cmi_fname = (ctx.attr.module_name if ctx.attr.module_name else ctx.label.name) + ".cmi"
  obj_cmi = ctx.actions.declare_file(obj_cmi_fname)
  obj_cmx_fname = (ctx.attr.module_name if ctx.attr.module_name else ctx.label.name) + ".cmx"
  obj_cmx = ctx.actions.declare_file(obj_cmx_fname)
  obj_o_fname = (ctx.attr.module_name if ctx.attr.module_name else ctx.label.name) + ".o"
  obj_o = ctx.actions.declare_file(obj_o_fname)

  ## action: compile ns module
  args = ctx.actions.args()
  args.add("ocamlopt")
  args.add_all(ctx.attr.opts)
  args.add("-c")
  args.add("-o", obj_cmx)
  args.add(module_src.path)
  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = [module_src],
    outputs = [obj_cmx, obj_o, obj_cmi],
    tools = [tc.opam, tc.ocamlfind, tc.ocamlopt],
    mnemonic = "OcamlNsModule",
    progress_message = "ocaml_ns_module({}), {}".format(
      ctx.label.name, ctx.attr.message
      )
  )

  return [
    DefaultInfo(files = depset(direct = [obj_cmx, obj_cmi, obj_o])),
    OcamlModuleProvider(
      module = struct(
        cmi = obj_cmi,
        cmx = obj_cmx,
        o   = obj_o
      ),
      deps = struct(
        opam  = depset(),
        nopam = depset()
      )
    )
  ]
# OutputGroupInfo(bin = depset([bin_output]))]

# (library
#  (name deriving_hello)
#  (libraries base ppxlib)
#  (preprocess (pps ppxlib.metaquot))
#  (kind ppx_deriver))

#############################################
########## DECL:  OCAML_MODULE  ################
ocaml_ns_module = rule(
  implementation = _ocaml_ns_module_impl,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    module_name = attr.string(),
    ns = attr.string(),
    submodules = attr.label_list(
      allow_files = OCAML_FILETYPES
    ),
    opts = attr.string_list(
      default = [
        "-w", "-49", # ignore Warning 49: no cmi file was found in path for module x
        "-no-alias-deps", # lazy linking
        "-opaque"         #  do not generate cross-module optimization information
      ]
    ),
    linkopts = attr.string_list(),
    linkall = attr.bool(default = True),
    # impl = attr.label(
    #   allow_single_file = OCAML_IMPL_FILETYPES
    # ),
    # deps = attr.label_list(
    #   # providers = [OpamPkgInfo]
    # ),
    mode = attr.string(default = "native"),
    message = attr.string()
  ),
  provides = [DefaultInfo, OcamlModuleProvider],
  executable = False,
  toolchains = ["@obazl//ocaml:toolchain"],
)
