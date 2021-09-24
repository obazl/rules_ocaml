load("//ocaml:providers.bzl",
     "OcamlArchiveMarker",
     "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsArchiveMarker",
     "OcamlNsLibraryMarker",
     "OcamlSignatureMarker",
     "PpxArchiveMarker") ## what about PpxModule?

load(":options.bzl", "options")

load("impl_archive.bzl", "impl_archive")

load("//ocaml/_transitions:ns_transitions.bzl", "nsarchive_in_transition")

#####################
ocaml_archive = rule(
    implementation = impl_archive,
    doc = """Generates an OCaml archive file.""",
    attrs = dict(
        options("ocaml"),
        archive_name = attr.string(
            doc = "Name of generated archive file, without extension. Overrides `name` attribute."
        ),
        ## CONFIGURABLE DEFAULTS
        _linkall     = attr.label(default = "@ocaml//archive/linkall"),
        # _threads     = attr.label(default = "@ocaml//archive/threads"),
        _warnings  = attr.label(default = "@ocaml//archive:warnings"),
        #### end options ####

        shared = attr.bool(
            doc = "True: build a shared lib (.cmxs)",
            default = False
        ),

        standalone = attr.bool(
            doc = "True: link total depgraph. False: link only direct deps.  Default False.",
            default = False
        ),

        modules = attr.label_list(
            doc = "List of component modules.",
            providers = [[OcamlImportMarker],
                         [OcamlLibraryMarker],
                         [OcamlArchiveMarker],
                         [OcamlModuleMarker],
                         # [OcamlNsArchiveMarker],
                         [OcamlNsLibraryMarker],
                         [OcamlSignatureMarker],
                         # [PpxArchiveMarker]
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
        # cc_linkall = attr.label_list( ## FIXME: not needed
        #     doc     = "True: use `-whole-archive` (GCC toolchain) or `-force_load` (Clang toolchain). Deps in this attribute must also be listed in cc_deps.",
        #     providers = [CcInfo],
        # ),
        _cc_linkmode = attr.label( ## FIXME: not needed?
            doc     = "Override platform-dependent link mode (static or dynamic). Configurable default is platform-dependent: static on Linux, dynamic on MacOS.",
            # default is os-dependent, but settable to static or dynamic
        ),
        _mode = attr.label(
            default = "@ocaml//mode"
        ),
        _projroot = attr.label(
            default = "@ocaml//:projroot"
        ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        _rule = attr.string( default = "ocaml_archive" ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
    ),
    incompatible_use_toolchain_transition = True,
    ## this is not an ns archive, and it does not use ns ConfigState,
    ## but we need to reset the ConfigState anyway, so the deps are not affected.
    # cfg     = nsarchive_in_transition,
    provides = [OcamlArchiveMarker],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
