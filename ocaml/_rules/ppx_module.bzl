load("@bazel_skylib//lib:paths.bzl", "paths")
load("//ppx/_config:transitions.bzl", "ppx_mode_transition")

load("//ocaml/_providers:ocaml.bzl",
     "OcamlSDK",
     "OcamlInterfaceProvider")
load("@obazl_rules_opam//opam/_providers:opam.bzl", "OpamPkgInfo")
load("//ppx:_providers.bzl",
     "PpxCompilationModeSettingProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")
load("//ocaml/_actions:batch.bzl", "copy_srcs_to_tmp")

load("//ocaml/_actions:compile_module.bzl", "compile_module")

load("//ocaml/_utils:deps.bzl", "get_all_deps")

load("//ocaml/_functions:utils.bzl",
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
load("ppx_options.bzl", "ppx_options")

#############################################
####  OCAML_PPX_MODULE IMPLEMENTATION
def _ppx_module_impl(ctx):

  debug = False
  # if ctx.label.name == "Register_event":
  #     debug = True

  mode = ctx.attr._mode[0][PpxCompilationModeSettingProvider].value

  mydeps = get_all_deps("ppx_module", ctx)

  # result = compile_module("ppx_module", ctx, mode, mydeps)
  if mode == "dual":
      native_result = compile_module("ppx_module", ctx, "native", mydeps)
      bc_result     = compile_module("ppx_module", ctx, "bytecode", mydeps)
  else:
      result        = compile_module("ppx_module", ctx, mode, mydeps)

  if debug:
      print("PPX_MODULE COMPILE RESULT:")
      print(result)

  # if mode == "native":
  payload = struct(
          cmi = result.cmi,  #obj["cmi"] if "cmi" in obj else None,
          mli = result.mli,
          cmx  = result.cmx,
          cmo  = result.cmo,
          cmt = result.cmt,
          o   = result.o
      )
  directs = []
  if result.cmo: directs.append(result.cmo)
  if result.cmx: directs.append(result.cmx)
  if result.cmi: directs.append(result.cmi)
  if result.mli: directs.append(result.mli)

  # else:
  #     payload = struct(
  #         cmi = result.cmi,  #obj["cmi"] if "cmi" in obj else None,
  #         mli = result.mli,
  #         cmo  = result.cmo,
  #         cmt = result.cmt,
  #     )
  #     directs = [result.cmo, result.cmi]

  ppx_provider = PpxModuleProvider(
      payload = payload,
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
        ppx_options,
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        doc = attr.string(doc = "Docstring"),
        module_name = attr.string(
            doc = "Allows user to specify a module name different than the target name."
        ),
        _mode = attr.label(
            default = "@ppx//mode",
            cfg     = ppx_mode_transition
        ),
        _allowlist_function_transition = attr.label(
            ## required for transition fn of attribute _mode
        default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
        ##FIXME: ns replaced by ppx_ns_module?
        ns   = attr.label(
            doc = "Label of an ocaml_ns target. Used to derive namespace, output name, -open arg, etc.",
        ),
        ns_sep = attr.string(
            doc = "Namespace separator.  Default: '__'",
            default = "__"
        ),
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
        ppx_print = attr.label(
            doc = "Format of output of PPX transform, binary (default) or text",
            default = "@ppx//print"
        ),

        ## RULE DEFAULTS
        _linkall     = attr.label(default = "@ppx//module:linkall"), # FIXME: call it alwayslink?
        _threads         = attr.label(default = "@ppx//module:threads"),
        _warnings        = attr.label(default = "@ppx//module:warnings"),
        #### end options ####

        cc_deps = attr.label_keyed_string_dict(
            doc = "C/C++ library dependencies. Keys: lib target. Vals: 'default', 'static', 'dynamic'",
            providers = [[CcInfo]]
        ),
        cc_opts = attr.string_list(
            doc = "C/C++ options",
        ),
        ## FIXME: call this cc_deps_default_type or some such
        # cc_linkstatic = attr.bool(
        # doc = "Control linkage of C/C++ dependencies. True: link to
        # .a file; False: link to shared object file (.so or .dylib)",
        #   default = True # False  ## false on macos, true on linux?
        # ),
        linkopts = attr.string_list(), # FIXME: cc_linkopts
        # srcs = attr.label_list(),
        deps = attr.label_list(
            allow_files = True
            # providers = [OpamPkgInfo]
        ),
        _deps = attr.label(
            doc = "Dependency to be added last.",
            default = "@ppx//module:deps"
        ),
        msg = attr.string()
    ),
    provides = [DefaultInfo, PpxModuleProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
    # Attaching at rule transitions the configuration of this target and all its dependencies
    # (until it gets overwritten again, for example...)
    # cfg     = ppx_mode_transition
)
