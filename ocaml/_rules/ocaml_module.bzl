load("@bazel_skylib//lib:paths.bzl", "paths")

# load("@rules_foreign_cc//tools/build_defs:framework.bzl",
#      "ForeignCcDeps",
#      "ForeignCcArtifact")

load("//ppx/_config:transitions.bzl", "ppx_mode_transition")

load("//ocaml/_config:transitions.bzl",
     "ocaml_mode_transition_incoming",
     "ocaml_mode_transition_outgoing",)

load("//ocaml/_providers:ocaml.bzl",
     "CompilationModeSettingProvider",
     # "OcamlSDK",
     "OcamlDepsetProvider",
     "OcamlArchiveProvider",
     "OcamlImportProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlNsModuleProvider",
     "OcamlModulePayload",
     "OcamlModuleProvider")
load("@obazl_rules_opam//opam/_providers:opam.bzl", "OpamPkgInfo")
load("//ppx:_providers.bzl",
     "PpxArchiveProvider",
     "PpxExecutableProvider",
     "PpxLibraryProvider",
     "PpxModuleProvider")
load("//ocaml/_actions:compile_module.bzl", "compile_module")

load("//ocaml/_deps:depsets.bzl", "get_all_deps")

load("//ocaml/_functions:utils.bzl",
     # "capitalize_initial_char",
     # "get_opamroot",
     # "get_sdkpath",
     # "get_src_root",
     # "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "WARNING_FLAGS"
)
load(":options_ocaml.bzl", "options_ocaml")

tmpdir = "_obazl_/"

################################################################
########## RULE:  OCAML_MODULE  ################
def _ocaml_module_impl(ctx):

  debug = False
  # if ctx.label.name == "structured_log_events":
  #     debug = True

  # for [k, v] in ctx.var.items():
  #     print("VARS: {k} = {v}".format(k = k, v = v))

  # x = ["STAMPFILES %s" % f.path for f in (ctx.info_file, ctx.version_file)]
  # print(x)

  if debug:
      print("MODULE TARGET: %s" % ctx.label.name)

  if len(ctx.attr.ppx_tags) > 1:
      fail("Only one ppx_tag allowed currently.")

  mode = ctx.attr._mode[CompilationModeSettingProvider].value

  mydeps = get_all_deps("ocaml_module", ctx)
  # if debug:
  #     print("ALL DEPS for target %s:" % ctx.label.name)
  #     print(mydeps)

  if mode == "dual":
      native_result = compile_module("ocaml_module", ctx, "native", mydeps)
      bc_result     = compile_module("ocaml_module", ctx, "bytecode", mydeps)
  else:
      result        = compile_module("ocaml_module", ctx, mode, mydeps)

  if debug:
      print("OCAML_MODULE COMPILE RESULT:")
      print(result)

  # if hasattr(result, "o"):
  if mode == "native":
      payload = OcamlModulePayload(
          # if we have an incoming cmi, its in the nopam deps
          # otherwise, we create it so it goes here(?)
          # what about the mli?
          cmi = result.cmi,  # ctx.file.intf if ctx.file.intf else None,
          mli = result.mli,
          cmx  = result.cmx,
          cmt = result.cmt,
          o   = result.o
      )
      directs = [result.cmx, result.o, result.cmi]
  else:
      payload = OcamlModulePayload(
          # if we have an incoming cmi, its in the nopam deps
          # otherwise, we create it so it goes here(?)
          # what about the mli?
          cmi = result.cmi,  # ctx.file.intf if ctx.file.intf else None,
          mli = result.mli,
          cmo  = result.cmo,
          cmt = result.cmt,
      )
      directs = [result.cmo, result.cmi]

  module_provider = OcamlModuleProvider(
      payload = payload,
      deps = OcamlDepsetProvider(
          opam = result.opam,
          nopam = result.nopam
      )
  )

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
        options_ocaml,
        ## RULE DEFAULTS
        _linkall     = attr.label(default = "@ocaml//module:linkall"), # FIXME: call it alwayslink?
        _threads     = attr.label(default = "@ocaml//module:threads"),
        _warnings  = attr.label(default = "@ocaml//module:warnings"),
        linkopts = attr.string_list(),
        #### end options ####
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        doc = attr.string(
            doc = "Docstring for module"
        ),
        module_name   = attr.string(
            doc = "Module name."
        ),
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
        ################################
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
        ppx_print = attr.label(
            doc = "Format of output of PPX transform, binary (default) or text",
            default = "@ppx//print"
        ),
        deps = attr.label_list(
            providers = [[OpamPkgInfo],
                         [OcamlArchiveProvider],
                         [OcamlInterfaceProvider],
                         [OcamlImportProvider],
                         [OcamlLibraryProvider],
                         [OcamlModuleProvider],
                         [OcamlNsModuleProvider],
                         [PpxArchiveProvider],
                         [PpxModuleProvider],
                         [CcInfo]],
        ),
        _deps = attr.label(
            doc = "Global deps, apply to all instances of rule. Added last.",
            default = "@ocaml//module:deps"
        ),
        cc_deps = attr.label_keyed_string_dict(
            doc = "C/C++ library dependencies",
            # providers = [[CcInfo]]
        ),
        _cc_deps = attr.label(
            doc = "Global cc-deps, apply to all instances of rule. Added last.",
            default = "@ocaml//module:deps"
        ),
        cc_opts = attr.string_list(
        ## FIXME: no need for this, we do not compile cc code
            doc = "C/C++ options",
        ),
        cc_linkstatic = attr.bool(
            ## FIXME: replaced by "static" value for cc_deps dict
            doc     = "Control linkage of C/C++ dependencies. True: link to .a file; False: link to shared object file (.so or .dylib)",
            default = True # False  ## false on macos, true on linux?
        ),
        ## TODO:
        _cc_linkstatic = attr.label(
            doc = "Global statically linked cc-deps, apply to all instances of rule. Added last.",
            default = "@ocaml//module:cc_linkstatic"
        ),
        cc_linkall = attr.label_list(
            ## FIXME: make this sticky; replace with "static-linkall" value for cc_deps dict entry
            doc     = "True: use -whole-archive (GCC toolchain) or -force_load (Clang toolchain)",
            providers = [CcInfo],
        ),
        ## CONFIGURABLE DEFAULTS ##
        _mode       = attr.label(
            default = "@ocaml//mode",
        ),
        dual_mode = attr.bool(default = False),
        # _ppx_mode       = attr.label(
        #     default = "@ppx//mode",
        #     # Attaching to an attribute transitions the configuration of this dependency (and
        #     # all its dependencies)
        #     cfg = ocaml_mode_transition_incoming
        # ),
        # _allowlist_function_transition = attr.label(
        #     ## required for transition fn of attribute _mode
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),

        msg = attr.string(),
    ),
    provides = [OcamlModuleProvider],
    # provides = [DefaultInfo, OutputGroupInfo, PpxInfo],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
    # cfg = ocaml_mode_transition_outgoing
)
