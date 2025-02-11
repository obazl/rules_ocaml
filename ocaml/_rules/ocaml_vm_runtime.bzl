# load(":options.bzl", "options") # , "options_ns_resolver")

load("@rules_ocaml//build:providers.bzl", "OCamlVmRuntimeProvider")

load("//lib:colors.bzl", "CCRED", "CCMAGBG", "CCRESET")

###############################
def _ocaml_vm_runtime(ctx):

    debug = False

    if debug:
        print("{c}ocaml_vm_runtime:{r} {lbl}".format(
            c=CCMAGBG,r=CCRESET, lbl=ctx.label))

    if ctx.label == Label("@rules_ocaml//cfg/runtime:dynamic"):
        kind = "dynamic"
    elif ctx.label == Label("@rules_ocaml//cfg/runtime:static"):
        kind = "static"
    else:
        kind = "standalone"

    # if kind == standalone, run ocamlc -make-runtime

    defaultInfo = DefaultInfo(
        # executable=out_exe,
        # runfiles = myrunfiles
    )
    ocamlVmRuntimeProvider = OCamlVmRuntimeProvider(
        kind = kind
    )

    providers = [
        defaultInfo,
        ocamlVmRuntimeProvider
    ]

    return providers

###############################
# rule_options = options("rules_ocaml")
# rule_options.update(options_vm_runtime("ocaml"))

#########################
ocaml_vm_runtime = rule(
  implementation = _ocaml_vm_runtime,
    doc = "User-defined runtime, using ocamlc -make-runtime",
    attrs = dict(
        deps = attr.label_list(
            doc = """Libraries whose cc deps should be included in the runtime
            """,
            providers = [
                [CcInfo], # deps must provide CcInfo
            ]
        ),
        _rule = attr.string(default = "ocaml_vm_runtime")
    ),
    provides = [OCamlVmRuntimeProvider],
    executable = False,
    toolchains = [
        "@rules_ocaml//toolchain/type:std",
    ],
)
