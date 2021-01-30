load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/_providers:ocaml.bzl",
    "CompilationModeSettingProvider",
     "OcamlNsModulePayload",
     "OcamlNsResolverProvider")
load("//ppx:_providers.bzl",
     "PpxNsModuleProvider")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
)

OCAML_FILETYPES = [
    ".ml", ".mli", ".cmx", ".cmo", ".cma"
]

tmpdir = "_obazl_/"

#################
def _impl_ns_resolver(ctx):

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    aliases = []
    ## declare ns module file, as input to compile action
    ns_sep = ""

    if ctx.attr.ns:
        ns_module_name = capitalize_initial_char(ctx.attr.ns)
    else:
        if ctx.workspace_name == "__main__": # default, if not explicitly named
            ws = "Null"
        else:
            ws = ctx.workspace_name
            # print("WS: %s" % ws)
        ws = capitalize_initial_char(ws) if ws else ""
        ns_module_name = ws + "_" + ctx.label.package.replace("/", "_").replace("-", "_") + "__"

    dep_graph = []
    for sm in ctx.files.srcs:
        sm_parts = paths.split_extension(sm.basename)
        module = capitalize_initial_char(sm_parts[0])
        alias = "module {mod} = {ns}{sep}{mod}".format(
            mod = module,
            sep    = ns_sep,
            ns = ns_module_name
        )
        aliases.append(alias)

    # if ctx.attr._rule == "ocaml_ns":
    #     mode = ctx.attr._mode[CompilationModeSettingProvider].value
    # elif ctx.attr._rule == "ppx_ns":
    #     mode = ctx.attr._mode[CompilationModeSettingProvider].value

    ns_filename = tmpdir + ns_module_name + ".ml"
    # print("NS FILE: %s" % ns_filename)
    ns_file = ctx.actions.declare_file(ns_filename)

    ## action: generate ns module file with alias content
    ctx.actions.write(
        output = ns_file,
        content = "\n".join(aliases) + "\n"
    )
    outputs = []
    directs = []

    directs.append(ns_file)

    ## now declare compilation outputs. compiling always produces 3 files:
    obj_cmi_fname = tmpdir + ns_module_name + ".cmi"
    obj_cmi = ctx.actions.declare_file(obj_cmi_fname)
    directs.append(obj_cmi)
    if mode == "native":
        obj_cm__fname = tmpdir + ns_module_name + ".cmx" # tc.objext
    else:
        obj_cm__fname = tmpdir + ns_module_name + ".cmo" # tc.objext
    obj_cm_ = ctx.actions.declare_file(obj_cm__fname)
    directs.append(obj_cm_)

    ################################
    args = ctx.actions.args()

    if mode == "bytecode":
        args.add(tc.ocamlc.basename)
    else:
        args.add(tc.ocamlopt.basename)
        obj_o_fname = ns_module_name + ".o"
        obj_o = ctx.actions.declare_file(tmpdir + obj_o_fname)
        outputs.append(obj_o)
        directs.append(obj_o)

    args.add("-w", "-49") # Warning 49: no cmi file was found in path for module
    outputs.append(obj_cm_)
    outputs.append(obj_cmi)

    # if ctx.attr._warnings:
    #     args.add_all(ctx.attr._warnings[BuildSettingInfo].value, before_each="-w", uniquify=True)

    # if hasattr(ctx.attr, "opts"):
    #     args.add_all(ctx.attr.opts)

    # # dep_graph.append(ns_compile_src)
    args.add("-I", ns_file.dirname)
    dep_graph.append(ns_file)

    # # for dep in ctx.files.deps:
    # #     # dep_graph.append(dep)
    # #     args.add("-I", dep.path)

    # ## -no-alias-deps is REQUIRED for ns modules;
    # ## see https://caml.inria.fr/pub/docs/manual-ocaml/modulealias.html
    args.add("-no-alias-deps")

    args.add("-c")
    args.add("-o", obj_cm_)
    args.add(ns_file.path)

    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs = dep_graph, # [module_src],
        outputs = outputs,
        tools = [tc.ocamlfind, tc.ocamlopt],
        mnemonic = "OcamlNsModuleAction" if ctx.attr._rule == "ocaml_ns" else "PpxNsModuleAction",
        progress_message = "{mode} compiling: @{ws}//{pkg}:{tgt} (rule {rule})".format(
            mode = mode,
            ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
            pkg = ctx.label.package,
            rule=ctx.attr._rule,
            tgt=ctx.label.name,
        )
    )

    provider = OcamlNsResolverProvider(
        payload = depset(order = "postorder", direct = outputs)
    )

    return [
        DefaultInfo(files = depset(
            order = "postorder",
            direct = outputs
        )),
        provider
    ]

################
ocaml_ns_resolver = rule(
  implementation = _impl_ns_resolver,
    doc = """This rule sets the "ns prefix string", which serves as a kind of pseudo-namespace. Submodule names will be formed by prefixing this string to the (original, un-namespaced) module name, separated by 'sep' (default: '__').

The main namespace module will contain aliasing equations that map module names to these prefixed module names.

By default, the ns prefix string is formed from the package name, with '/' replaced by '_'. You can use the 'ns' attribute to change this:

ns(ns = "foobar", srcs = glob(["*.ml"]))

    """,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    ns   = attr.string(
        doc = "Namespace defaults to package name with '/' replaced by '_'. Use this attribute to set it to some other string."
    ),
    separator = attr.string(
        doc = "String used to separate namespace implementation prefix from submodule name."
    ),
    srcs = attr.label_list(
        doc = "List of files from which submodule names are to be derived for inclusion in the namespace definition. The module name will be formed by truncating the extension and capitalizing the initial character. Module code generated from lex and yacc can be accomodated by using the module name for the source file and generating a .ml source file of the same aname, e.g. lexer.mll -> lexer.ml.",
        allow_files = True,
    ),
    deps = attr.label_list(
        doc = "Dependencies"
    ),
    _mode = attr.label(
        default = "@ocaml//mode"
    ),
    _warnings  = attr.label(default = "@ocaml//ns:warnings"),
    _rule = attr.string(default = "ocaml_ns_resolver")
  ),
  # provides = [DefaultInfo, OcamlNsModuleProvider],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
