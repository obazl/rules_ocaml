load("//ocaml/_providers:ocaml.bzl",
     "OcamlArchiveProvider",
     "OcamlImportProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider")

load("@obazl_rules_opam//opam/_providers:opam.bzl", "OpamPkgInfo")

load("//ppx:_providers.bzl", "PpxArchiveProvider") ## what about PpxModule?

load(":options_ocaml.bzl", "options_ocaml")

load("impl_archive.bzl", "impl_archive")

#####################
ocaml_archive = rule(
    implementation = impl_archive,
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

        ## FIXME: do archive rules need to support cc_deps?
        ## They should be attached to members of the archive.
        ## OTOH, if the ocaml wrapper on a cc_dep consists of multiple modules
        ## it makes sense to aggregate them into an archive or library
        ## and attach the cc_dep to the latter.
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
        _rule = attr.string( default = "ocaml_archive" )
    ),
    provides = [OcamlArchiveProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
