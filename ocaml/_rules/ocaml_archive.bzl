load("@bazel_skylib//rules:common_settings.bzl",
     "BuildSettingInfo")

load("//ocaml/_providers:ocaml.bzl",
     "CompilationModeSettingProvider",
     "OcamlArchivePayload",
     "OcamlArchiveProvider",
     "OcamlDepsetProvider",
     "OcamlImportProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider")

load("impl_archive.bzl", "impl_archive")

load("@obazl_rules_opam//opam/_providers:opam.bzl", "OpamPkgInfo")

load("//ppx:_providers.bzl", "PpxArchiveProvider")

load("//ocaml/_deps:depsets.bzl", "get_all_deps")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "file_to_lib_name"
)

load(":options_ocaml.bzl", "options_ocaml")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

##################################################
######## RULE DECL:  OCAML_ARCHIVE  #########
#  Build .cmxa, .a
##################################################
def _ocaml_archive_impl(ctx):

  debug = False
  # if (ctx.label.name == "zexe_backend_common"):
  #     debug = True

  if debug:
      print("ARCHIVE TARGET: %s" % ctx.label.name)

  # env = {"OPAMROOT": get_opamroot(),
  #        "PATH": get_sdkpath(ctx)}

  mode = ctx.attr._mode[CompilationModeSettingProvider].value

  mydeps = get_all_deps("ocaml_archive", ctx)

  if debug:
      print("ALL DEPS for target %s" % ctx.label.name)
      print(mydeps)

  # if mode == "dual":
  #     native_result = compile_archive("ocaml_archive", ctx, "native", mydeps)
  #     bc_result     = compile_archive("ocaml_archive", ctx, "bytecode", mydeps)
  # else:
  # result        = compile_archive("ocaml_archive", ctx, mode, mydeps)

  # if debug:
  #     print("OCAML_ARCHIVE COMPILE RESULT:")
  #     print(result)

  # if mode == "native":
  #     payload = OcamlArchivePayload(
  #         archive = ctx.label.name,
  #         cmxa = result.cmxa,
  #         a   = result.a,
  #     )
  #     directs = [result.cmxa, result.a]
  # else:
  #     payload = OcamlArchivePayload(
  #         archive = ctx.label.name,
  #         cma = result.cma
  #     )
  #     directs = [result.cma]

  # archiveProvider = OcamlArchiveProvider(
  #     payload = payload,
  #     deps = OcamlDepsetProvider(
  #         opam = mydeps.opam,
  #         nopam = mydeps.nopam
  #     )
  # )

  # # print("ARCHIVEPROVIDER for {arch}: {ap}".format(arch=ctx.label.name, ap=archiveProvider))
  # return [
  #   DefaultInfo(
  #     files = depset(
  #         order = "postorder", # "preorder",
  #         direct = directs
  #       # transitive = [depset(build_deps + cc_deps)]
  #     )
  #   ),
  #   archiveProvider,
  # ]

################################################################
ocaml_archive = rule(
    implementation = impl_archive, ## _ocaml_archive_impl,
    doc = """Generates an OCaml archive file.""",
    attrs = dict(
        options_ocaml,
        archive_name = attr.string(
            doc = "Name of generated archive file, without extension. Overrides `name` attribute."
        ),
        ## CONFIGURABLE DEFAULTS
        _linkall     = attr.label(default = "@ocaml//archive:linkall"), # FIXME: call it alwayslink?
        _threads     = attr.label(default = "@ocaml//archive:threads"),
        _warnings  = attr.label(default = "@ocaml//archive:warnings"),
        #### end options ####
        doc = attr.string( doc = "Deprecated" ),
        deps = attr.label_list(
            doc = "List of OCaml dependencies.",
            providers = [[OpamPkgInfo],
                         [OcamlImportProvider],
                         [OcamlInterfaceProvider],
                         [OcamlLibraryProvider],
                         [OcamlModuleProvider],
                         [OcamlNsModuleProvider],
                         [OcamlArchiveProvider],
                         [PpxArchiveProvider]
                         ],
        ),

        cc_deps = attr.label_keyed_string_dict(
            doc = """Dictionary specifying C/C++ library dependencies. Key: a target label; value: a linkmode string, which determines which file to link. Valid linkmodes: 'default', 'static', 'dynamic', 'shared' (synonym for 'dynamic'). For more information see [CC Dependencies: Linkmode](../ug/cc_deps.md#linkmode).
            """,
            providers = [[CcInfo]]
        ),
        cc_linkopts = attr.string_list(
            doc = "List of C/C++ link options. E.g. `[\"-lstd++\"]`.",
        ),
        cc_linkall = attr.label_list(
            doc     = "True: use `-whole-archive` (GCC toolchain) or `-force_load` (Clang toolchain). Deps in this attribute must also be listed in cc_deps.",
            providers = [CcInfo],
        ),
        ## FIXME: make cc_linkmode a configurable default
        # cc_linkstatic = attr.bool( ## FIXME: rename cc_linkmode = static | dynamice
        #     doc     = "Override platform-dependent link mode (static or dynamic).",
        #     # default = False  # "@ocaml//:linkstatic"
        # ),
        ## FIXME: should this be hidden? yes - to set all cc_deps for
        ## one rule application, use the cc_deps attrib values.
        _cc_linkmode = attr.label(
            doc     = "Override platform-dependent link mode (static or dynamic). Configurable default is platform-dependent: static on Linux, dynamic on MacOS.",
            # default is os-dependent, but settable to static or dynamic
        ),
        _mode = attr.label(
            default = "@ocaml//mode"
        ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        # msg = attr.string(),
        ## ctx provides no way for impl to discover which rule. to share an impl, we need our own attrib:
        _rule = attr.string( default = "ocaml_archive" )
    ),
    provides = [OcamlArchiveProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
