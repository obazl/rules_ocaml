# load("@bazel_skylib//lib:paths.bzl", "paths")


# load("//ppx/_transitions:transitions.bzl", "ppx_mode_transition")

# load("//ocaml/_transistions:mode_transitions.bzl",
#      "ocaml_mode_transition_incoming",
#      "ocaml_mode_transition_outgoing",)

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

# load("//ocaml/_transitions:ns_transitions.bzl",
#      "ocaml_ns_transition_incoming",
#      "ocaml_ns_transition_reset")

load("//ocaml/_providers:ocaml.bzl",
     "CompilationModeSettingProvider",
     "OcamlDepsetProvider",
     "OcamlArchiveProvider",
     "OcamlImportProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlModulePayload",
     "OcamlNsModuleProvider",
     "OcamlModuleProvider")

load("@obazl_rules_opam//opam/_providers:opam.bzl", "OpamPkgInfo")

load("//ppx:_providers.bzl",
     "PpxArchiveProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")

load("//ocaml/_actions:compile_module.bzl", "compile_module")

load("//ocaml/_deps:depsets.bzl", "get_all_deps")

load(":options_ocaml.bzl", "options_ocaml")

OCAML_IMPL_FILETYPES = [
    ".ml", ".cmx", ".cmo", ".cma"
]

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
    doc = """Compiles an OCaml module. Provides: [OcamlModuleProvider](providers_ocaml.md#ocamlmoduleprovider).

**CONFIGURABLE DEFAULTS** for rule `ocaml_module`

In addition to the [OCaml configurable defaults](#configdefs) that apply to all
`ocaml_*` rules, the following apply to this rule:

**Options**

| Label | Default | Notes |
| ----- | ------- | ------- |
| @ocaml//module:deps | `@ocaml//:null` | list of OCaml deps to add to all `ocaml_module` instances |
| @ocaml//module:cc_deps<sup>1</sup> | `@ocaml//:null` | list of cc_deps to add to all `ocaml_module` instances |
| @ocaml//module:cc_linkstatic<sup>1</sup> | `@ocaml//:null` | list of cc_deps to link statically (DEPRECATED) |
| @ocaml//module:warnings | `@1..3@5..28@30..39@43@46..47@49..57@61..62-40`| sets `-w` option for all `ocaml_module` instances |

<sup>1</sup> See [CC Dependencies](../ug/cc_deps.md) for more information on CC deps.

**Boolean Flags**

| Label | Default | `opts` attrib |
| ----- | ------- | ------- |
| @ocaml//module:linkall | True | `-linkall`, `-no-linkall`|
| @ocaml//module:threads | True | `-thread`, `-no-thread`|
| @ocaml//module:verbose | True | `-verbose`, `-no-verbose`|

**NOTE** These do not support `:enable`, `:disable` syntax.

 See [Configurable Defaults](../ug/configdefs_doc.md) for more information.
    """,
    attrs = dict(
        options_ocaml,
        ## RULE DEFAULTS
        _linkall     = attr.label(default = "@ocaml//module:linkall"), # FIXME: call it alwayslink?
        _threads     = attr.label(default = "@ocaml//module:threads"),
        _warnings  = attr.label(default = "@ocaml//module:warnings"),
        # linkopts = attr.string_list(),
        #### end options ####
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        doc = attr.string(
            doc = "Docstring for module. DEPRECATED"
        ),
        module_name   = attr.string(
            doc = "Module name. Overrides `name` attribute."
        ),
        # ns_sep = attr.string(
        #     doc = "Namespace separator.  Default: '__'",
        #     default = "__"
        # ),
        ns = attr.label(
            doc = "Label of an ocaml_ns target. Used to derive namespace, output name, -open arg, etc.",
            default = None
        ),
        # _xns = attr.label(
        #     doc = "Experimental",
        #     default = "@ocaml//ns"
        # ),
        # xns = attr.label(
        #     doc = "Experimental",
        #     cfg = ocaml_ns_transition_reset,
        #     default = "@ocaml//ns"
        # ),
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
        data = attr.label_list(
            allow_files = True,
            doc = "Runtime dependencies: list of labels of data files needed by this module at runtime."
        ),
        deps = attr.label_list(
            doc = "List of OCaml dependencies.",
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
