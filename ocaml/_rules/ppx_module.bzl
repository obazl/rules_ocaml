load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/_providers:ocaml.bzl",
     "OcamlSDK",
     "OcamlInterfaceProvider")
load("//ocaml/_providers:opam.bzl", "OpamPkgInfo")
load("//ocaml/_providers:ppx.bzl",
     "PpxExecutableProvider",
     "PpxModuleProvider")
load("//ocaml/_actions:batch.bzl", "copy_srcs_to_tmp")
# load("//ocaml/_actions:ns_module.bzl", "ns_module_compile")
load("//ocaml/_actions:module.bzl", "compile_module")
load("//ocaml/_actions:ppx_transform.bzl", "ppx_transform_action")
load("//ocaml/_utils:deps.bzl", "get_all_deps")
load("//implementation:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "get_target_file",
     "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

#############################################
####  OCAML_PPX_MODULE IMPLEMENTATION
def _ppx_module_impl(ctx):

  debug = False
  # if ctx.label.name == "Register_event":
  #     debug = True

  mydeps = get_all_deps("ppx_module", ctx)

  result = compile_module("ppx_module", ctx, mydeps)

  if debug:
      print("PPX_MODULE COMPILE RESULT:")
      print(result)

  ppx_provider = PpxModuleProvider(
      payload = struct(
          cmi = result.cmi,  #obj["cmi"] if "cmi" in obj else None,
          mli = result.mli,
          cm  = result.cm,
          cmt = result.cmt,
          o   = result.o
      ),
      deps = struct(
          opam  = result.opam,
          opam_lazy = mydeps.opam_lazy,
          # opam_lazy = depset(order = "postorder",
          #                    direct = opam_lazy_deps),
          nopam = result.nopam,
          nopam_lazy = mydeps.nopam_lazy
          # nopam_lazy = depset(order = "postorder",
          #                    direct = nopam_lazy_deps),
      )
  )

  directs = [result.cm, result.o, result.cmi]
  if result.mli: directs.append(result.mli)
  if result.cmt: directs.append(result.cmt)
  defaultInfo = DefaultInfo(
      files = depset(
          order = "postorder",
          direct = directs
      )
  )

  result = [defaultInfo, ppx_provider]
  if debug:
      print("PpxModuleProvider RESULT:")
      print(result)

  return result

#############################################
########## DECL:  PPX_MODULE  ################
ppx_module = rule(
  implementation = _ppx_module_impl,
  # implementation = _ppx_module_compile_test,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    doc = attr.string(doc = "Docstring"),
    module_name = attr.string(
      doc = "Allows user to specify a module name different than the target name."
    ),
    ##FIXME: ns replaced by ppx_ns_module?
    ns   = attr.label(
        doc = "Label of an ocaml_ns target. Used to derive namespace, output name, -open arg, etc.",
    ),
    ns_sep = attr.string(
      doc = "Namespace separator.  Default: '__'",
      default = "__"
    ),
    # ns_module = attr.label(
    #   doc = "Label of a ns_module target. Used to derive namespace, output name, -open arg, etc.",
    # ),
    src = attr.label(
      mandatory = True,  # use ocaml_interface for isolated .mli files
      doc = "A single .ml source file label.",
      allow_single_file = OCAML_IMPL_FILETYPES
    ),
    intf = attr.label(
      doc = "Single label of a target providing a single .cmi file (not a .mli source file). Optional",
      allow_single_file = [".cmi"],
      providers = [OcamlInterfaceProvider],
    ),
    data = attr.label_list(
    ),
    runtime_deps  = attr.label_list(
        doc = "PPX runtime dependencies. E.g. a file used by %%import from ppx_optcomp.",
        allow_files = True,
    ),
    lazy_deps  = attr.label_list(
        doc = "PPX lazy (i.e. 'runtime') deps.",
        allow_files = True,
    ),
    # ppx = attr.label_keyed_string_dict(
    #   doc = """Dictionary of one entry. Key is a ppx target, val string is arguments.""",
    #   providers = [PpxExecutableProvider]
    # ),
    ppx  = attr.label(
        doc = "PPX binary (executable).",
        executable = True,
        cfg = "host",
        allow_single_file = True,
        providers = [PpxExecutableProvider]
    ),
    ppx_args  = attr.string_list(
        doc = "Arguments to pass to PPX binary.  (E.g. [\"-cookie\", \"library-name=\\\"ppx_version\\\"\"]"
    ),
    ppx_data  = attr.label_list(
        doc = "PPX dependencies. E.g. a file used by %%import from ppx_optcomp.",
        allow_files = True,
    ),
    opts = attr.string_list(),
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

    warnings                = attr.string(
      default               = "@1..3@5..28@30..39@43@46..47@49..57@61..62-40"
    ),
    linkopts = attr.string_list(),
    # linkall = attr.bool(default = True),
    alwayslink = attr.bool(
      doc = "If true (default), use OCaml -linkall switch",
      default = True,
    ),
    # srcs = attr.label_list(),
    deps = attr.label_list(
        allow_files = True
      # providers = [OpamPkgInfo]
    ),
    mode = attr.string(default = "native"),
    msg = attr.string()
  ),
  provides = [DefaultInfo, PpxModuleProvider],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
