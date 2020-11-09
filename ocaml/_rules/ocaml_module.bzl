load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/_providers:ocaml.bzl",
     "OcamlSDK",
     "OcamlArchiveProvider",
     "OcamlImportProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlNsModuleProvider",
     "OcamlModuleProvider")
load("//ocaml/_providers:opam.bzl", "OpamPkgInfo")
load("//ocaml/_providers:ppx.bzl",
     "PpxArchiveProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")
load("//ocaml/_actions:module.bzl", "compile_module")

load("//ocaml/_utils:deps.bzl", "get_all_deps")

load("//implementation:utils.bzl",
     # "capitalize_initial_char",
     # "get_opamroot",
     # "get_sdkpath",
     # "get_src_root",
     # "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

tmpdir = "_obazl_/"

################################################################
########## RULE:  OCAML_MODULE  ################
def _ocaml_module_impl(ctx):

  debug = False
  # if ctx.label.name == "structured_log_events":
  #     debug = True

  # x = ["STAMPFILES %s" % f.path for f in (ctx.info_file, ctx.version_file)]
  # print(x)

  if debug:
      print("MODULE TARGET: %s" % ctx.label.name)

  if len(ctx.attr.ppx_tags) > 1:
      fail("Only one ppx_tag allowed currently.")

  mydeps = get_all_deps("ocaml_module", ctx)
  # if debug:
  #     print("ALL DEPS for target %s:" % ctx.label.name)
  #     print(mydeps)

  result = compile_module("ocaml_module", ctx, mydeps)

  if debug:
      print("OCAML_MODULE COMPILE RESULT:")
      print(result)

  module_provider = OcamlModuleProvider(
      payload = struct(
          # if we have an incoming cmi, its in the nopam deps
          # otherwise, we create it so it goes here(?)
          # what about the mli?
          cmi = result.cmi,  # ctx.file.intf if ctx.file.intf else None,
          mli = result.mli,
          cm  = result.cm,
          cmt = result.cmt,
          o   = result.o
      ),
    deps = struct(
      opam = result.opam,
      nopam = result.nopam
    )
  )

  directs = [result.cm, result.o, result.cmi]
  if result.mli: directs.append(result.mli)
  if result.cmt: directs.append(result.cmt)
  defaultInfo = DefaultInfo(
    # payload
      files = depset(
          order = "postorder",
          direct = directs
        # transitive = depset(mydeps.nopam.to_list())
      )
  )

  result = [
      defaultInfo,
      module_provider
  ]

  if debug:
      print("OcamlModuleProvider RESULT:")
      print(result)

  return result

#############################################
########## DECL:  OCAML_MODULE  ################
ocaml_module = rule(
  implementation = _ocaml_module_impl,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    doc = attr.string(
        doc = "Docstring for module"
    ),
    module_name   = attr.string(
      doc = "Module name."
    ),
    # ns   = attr.string(
    #   doc = "Namespace string; will be used as module name prefix."
    # ),
    ns_sep = attr.string(
      doc = "Namespace separator.  Default: '__'",
      default = "__"
    ),
    ns = attr.label(
        doc = "Label of an ocaml_ns target. Used to derive namespace, output name, -open arg, etc.",
        default = None
    ),
    src = attr.label(
      mandatory = True,
      doc = "A single .ml source file label.",
      allow_single_file = OCAML_IMPL_FILETYPES
    ),
    intf = attr.label(
      doc = "Single label of a target providing a single .cmi or .mli file. Optional. Currently only supports .cmi input.",
      allow_single_file = [".cmi", ".mli"],
      # providers = [[DefaultInfo], [OcamlInterfaceProvider]],
    ),
    alwayslink = attr.bool(
      doc = "If true, use OCaml -linkall switch. Default: False",
      default = False,
    ),
    ppx  = attr.label(
        doc = "PPX binary (executable).",
        executable = True,
        cfg = "exec",
        allow_single_file = True,
        providers = [PpxExecutableProvider]
    ),
    ppx_args  = attr.string_list(
      doc = "Options to pass to PPX binary.",
    ),
    ppx_tags  = attr.string_list(
      doc = "List of tags.  Used to set e.g. -inline-test-libs, --cookies. Currently only one tag allowed."
    ),
    ppx_data  = attr.label_list(
        doc = "PPX dependencies. E.g. a file used by %%import from ppx_optcomp.",
        allow_files = True,
    ),
    # lazy_deps  = attr.label_list(
    ppx_output_format = attr.string(
      doc = "Format of output of PPX transform, binary (default) or text",
      values = ["binary", "text"],
      default = "binary"
    ),
    ##FIXME: ppx => ppx_libs
    # ppx = attr.label_keyed_string_dict(
    #   doc = """Dictionary of one entry. Key is a ppx target, val string is arguments."""
    # ),
    opts = attr.string_list(),
    linkopts = attr.string_list(),
    # data = attr.label_list(
    # ),
    deps = attr.label_list(
      providers = [[OpamPkgInfo],
                   [OcamlArchiveProvider],
                   [OcamlInterfaceProvider],
                   [OcamlImportProvider],
                   [OcamlLibraryProvider],
                   [OcamlModuleProvider],
                   [PpxArchiveProvider],
                   [PpxModuleProvider],
                   [CcInfo]],
    ),
    cc_deps = attr.label_keyed_string_dict(
      doc = "C/C++ library dependencies",
      providers = [[CcInfo]]
    ),
    cc_opts = attr.string_list(
      doc = "C/C++ options",
    ),
    ## FIXME: call this cc_deps_default_type or some such
    cc_linkstatic = attr.bool(
      doc     = "Control linkage of C/C++ dependencies. True: link to .a file; False: link to shared object file (.so or .dylib)",
      default = True # False  ## false on macos, true on linux?
    ),
    mode = attr.string(default = "native"),
    msg = attr.string(),
  ),
  provides = [OcamlModuleProvider],
  # provides = [DefaultInfo, OutputGroupInfo, PpxInfo],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
