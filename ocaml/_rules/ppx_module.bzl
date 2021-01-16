load("//ppx/_transitions:transitions.bzl", "ppx_mode_transition")

load("//ocaml/_providers:ocaml.bzl",
     "CompilationModeSettingProvider",
     "OcamlInterfaceProvider")

load("//ppx:_providers.bzl",
     "PpxExecutableProvider",
     "PpxModuleProvider")

load("//ocaml/_actions:compile_module.bzl", "compile_module")

load("//ocaml/_deps:depsets.bzl", "get_all_deps")

load("options_ppx.bzl", "options_ppx")

OCAML_IMPL_FILETYPES = [
    ".ml", ".cmx", ".cmo", ".cma"
]
#############################################
####  OCAML_PPX_MODULE IMPLEMENTATION
def _ppx_module_impl(ctx):

  debug = False
  # if ctx.label.name == "Register_event":
  #     debug = True

  mode = ctx.attr._mode[0][CompilationModeSettingProvider].value

  mydeps = get_all_deps(ctx.attr._rule, ctx)

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
          opam_adjunct = mydeps.opam_adjunct,
          # opam_adjunct = depset(order = "postorder",
          #                    direct = opam_adjunct_deps),
          nopam = result.nopam,
          nopam_adjunct = mydeps.nopam_adjunct
          # nopam_adjunct = depset(order = "postorder",
          #                    direct = nopam_adjunct_deps),
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
        options_ppx,
        deps = attr.label_list(
            doc = "List of OCaml dependencies.",
            allow_files = True
            # providers = [OpamPkgInfo]
        ),
        _deps = attr.label(
            doc = "Global deps, apply to all instances of rule. Added last.",
            default = "@ppx//module:deps"
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
            ## required for transition fn 'ppx_mode_transition', for attribute _mode
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
        ##FIXME: ns replaced by ppx_ns_module?
        ns   = attr.label(
            doc = "Label of a [ppx_ns](#ppx_ns) target. Used to derive namespace, output name, -open arg, etc.",
        ),
        # ns_sep = attr.string(
        #     doc = "Namespace separator.  Default: '__' (double underscore).",
        #     default = "__"
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
            doc = "Runtime dependencies: list of labels of data files needed by this module at runtime."
        ),
        runtime_deps  = attr.label_list(
            doc = "PPX runtime dependencies. E.g. a file used by %%import from ppx_optcomp.",
            allow_files = True,
        ),
        adjunct_deps = attr.label_list(
            doc = "List of [adjunct dependencies](../ug/ppx.md#adjunct_deps).",
            # providers = [[DefaultInfo], [PpxModuleProvider]]
            allow_files = True,
        ),
        ppx  = attr.label(
            doc = "PPX binary (executable) used to transform source before compilation.",
            executable = True,
            cfg = "host",
            allow_single_file = True,
            providers = [PpxExecutableProvider]
        ),
        ppx_args  = attr.string_list(
            doc = "Arguments to pass to ppx executable.  (E.g. [\"-cookie\", \"library-name=\\\"ppx_version\\\"\"]"
        ),
        ppx_data  = attr.label_list(
            doc = "PPX runtime dependencies. List of labels of files needed by PPX at preprocessing runtime. E.g. a file used by `[%%import ]` from [ppx_optcomp](https://github.com/janestreet/ppx_optcomp).",
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
        # linkopts = attr.string_list(), # FIXME: cc_linkopts
        # srcs = attr.label_list(),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        msg = attr.string( doc = "DEPRECATED" ),
        _rule = attr.string( default = "ppx_module" )
    ),
    provides = [DefaultInfo, PpxModuleProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
    # Attaching at rule transitions the configuration of this target and all its dependencies
    # (until it gets overwritten again, for example...)
    # cfg     = ppx_mode_transition
)
