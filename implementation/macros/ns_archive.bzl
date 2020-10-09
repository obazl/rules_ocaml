
# Starlark disallows recursion :(
def path2treeA(node, # dictionary {string: dictionary}
               seglist):
    length = len(seglist)
    for i in range(length):
        hd = seglist[i]
        if hd in node:
            node = node[hd] # another dictionry
        else:
            newnode = dict()
            node[hd] = newnode
            node = newnode

def emit_srcs_for_tree(root):
    current = root
    nodes = root.items()
    print("NODES: %s" % nodes)

    nodes = current.items() + nodes
    print("NODES: %s" % nodes)

def print_node(node):
    pfx = node.keys()[0] # should be only 1 key
    print("NODE: %s" % pfx)
    print("NODE[pfx]: %s" % node[pfx])
    kids = node[pfx].keys()
    for k in kids:
        print("module {k} = {pfx}__{k}.ml".format(pfx=pfx, k=k.capitalize()))

################################################################
## generate namespace module, rename component modules
def ocaml_ns_archive_macro(name,
                           rootseg=None,
                           delegates=None, ## modules? ns_modules? components?
                           visibility=None):
    if rootseg:
        root = rootseg
    else:
        root = native.package_name().split("/").pop()

    tree = dict()
    paths = sorted(delegates)
    seglists = []
    for p in paths:
        seglist = [root] + p.split("/")
        seglists.append(seglist)
        # print("path: %s" % seglist)
        path2treeA(tree, seglist)
    # print("tree: %s" % tree["alpha"])

    srcs = []
    ns_module_outfiles = {} # {filename: contents}
    rename_outfiles = []
    RENAME_CMD = ""

    for seglist in seglists:
        pfx = None
        node = tree
        # print("****************")
        # print("seglist: %s" % seglist)
        pfx = []
        for i in range(len(seglist)):
            seg=seglist[i]
            # print("seg {}: {}".format(i, seg))
            node = node[seglist[i]]
            # print("node: %s" % node)
            # if pfx:
            #     pfx = pfx + "__" + seg.capitalize()
            # else:
            #     pfx = seg.capitalize()
            pfx.append(seg.capitalize())
            # print("PFX: %s" % pfx)
            if "done" in node:
                continue
            if seg.endswith(".ml"):
                rename_outfile = "__".join(pfx)
                # print("renaming {} to {}".format("/".join(seglist), rename_outfile))
                pkg = native.package_name()
                src = pkg + "/" + "/".join(seglist[1:])
                srcs.append("/".join(seglist[1:]))
                RENAME_CMD += "cp {src} {dest};\n".format(
                    src = src,
                    dest = "$(RULEDIR)/" + rename_outfile
                )
                rename_outfiles.append(rename_outfile)
                continue
            # end if
            submods = node.keys()
            # print("submods: %s" % submods)
            outfile = "__".join(pfx) + ".ml"
            # print("File: %s" % outfile)
            aliases = []
            for submod in submods:
                alias = "module {submod} = {pfx}__{submod}".format(
                    submod=submod.rstrip(".ml").capitalize(),
                    pfx="__".join(pfx)
                )
                aliases.append(alias)
            ns_module_outfiles[outfile] = "\n".join(aliases)
            # print("pfx: {}, len {}".format(pfx, len(pfx)))
            if len(pfx) > 1:
                genrule_name = name + "_" + "_".join(pfx)
            else:
                genrule_name = name
            # print("wrote file %s" % outfile)
            node["done"] = True
        ## end inner for loop
    ## end outer for loop
    # print("NS_MODULE_OUTFILES: %s" % ns_module_outfiles.keys())
    SH_CONTENT = "echo PWD: `pwd`; "
    for item in ns_module_outfiles.items():
        SH_CONTENT += "echo \"{content}\" > \"$(RULEDIR)/{f}\";\n".format(
            f = item[0],
            content = item[1]
        )
    native.genrule(
        name = name,
        srcs = delegates,
        outs = rename_outfiles + ns_module_outfiles.keys(),
        cmd = SH_CONTENT + "\n"
        + RENAME_CMD
    )

    # print("tree done?")
    # print(tree)

################################################################
RENAME_CMD = """
for f in {srcs};
do
    ## capitalize the input file name
    BNAME=`basename $$f`;
    HD=`expr \"$$BNAME\" : '\(.\).*'`;
    HD=`echo $$HD | tr [a-z] [A-Z]`;
    TL=`expr \"$$BNAME\" : '.\(.*\)'`;
    ## prepend prefix
    MODULE={prefix}__$$HD$$TL;
    cp $$f $(@D)/$$MODULE;
done
"""

def ocaml_submodule_rename(name, prefix, srcs, visibility=None):
    ## IMPORTANT! We use the "make variable" $(SRCS), not the arg
    ## 'srcs'! Bazel will set it to the value of the srcs attrib
    ## (independent of order). That way the filenames are expanded
    ## properly to include workspace path.
    native.genrule(
        name = name,
        srcs = srcs,
        # NB: srcs arg is list of strings, we have to extract the basename
        outs = ["{}__{}".format(prefix, f.split("/").pop().capitalize()) for f in srcs],
        cmd = RENAME_CMD.format(prefix=prefix, srcs="$(SRCS)"),
    )

def ocaml_preproc(name, ppx, srcs, visibility=None):
    native.genrule(
        name = name,
        message = "Preprocessing sources...",
        tools = ["%s" % ppx],
        srcs = srcs,
        outs = ["_pp_/{}".format(f) for f in srcs],
        cmd = "for f in $(SRCS);"
        + " do"
        + "    BNAME=`basename $$f`;"
        + "    $(location %s) $$f > $@;" % ppx
        + " done"
    )

REDIRECTOR_CMD = """
for f in {srcs};
do
    BNAME=`basename $$f`;
    ## remove .ml extension
    BNAME=`expr \"$$BNAME\" : '\(.*\)...'`;
    ## upcase first letter
    HD=`expr \"$$BNAME\" : '\(.\).*'`;
    HD=`echo $$HD | tr [a-z] [A-Z]`;
    ## get the remainer
    TL=`expr \"$$BNAME\" : '.\(.*\)'`;
    ## assemble the converted name
    echo module $$HD$$TL = {prefix}__$$HD$$TL >> \"$@\";
done
"""

def ocaml_redirector_gen(name, redirector, srcs, visibility=None):
    native.genrule(
        name = name,
        srcs = srcs,
        outs = [redirector + "__.ml"],
        cmd = REDIRECTOR_CMD.format(prefix=redirector.split("/").pop().capitalize(),
                                    srcs="$(SRCS)"),
    )

# genrule(
#     name = "preproc_and_rename",
#     message = "genrule: preprocess and rename submodules...",
#     tools = ["//ocaml/ppx:metaquot"],
#     srcs = SRCS,
#     ## WARNING: order matters here. Dune can evidently do this automatically,
#     ## but here it's on the user.
#     outs = [
#         "ppx_version__Lint_version_syntax.ml",
#         "ppx_version__Bin_io_unversioned.ml",
#         "ppx_version__Versioned_module.ml",
#         "ppx_version__Versioned_type.ml",
#         "ppx_version__Versioned_util.ml",
#     ],
#     cmd = "for f in $(SRCS);"
#     + " do"
#     ## transform the file name
#     + "    BNAME=`basename $$f`;"
#     + "    HD=`expr \"$$BNAME\" : '\(.\).*'`;"
#     + "    HD=`echo $$HD | tr [a-z] [A-Z]`;"
#     + "    TL=`expr \"$$BNAME\" : '.\(.*\)'`;"
#     + "    MODULE=ppx_version__$$HD$$TL;"
#     ## preprocess and write to new name
#     + "    $(location //ocaml/ppx:metaquot) $$f > $(@D)/$$MODULE;"
#     + " done"
# )

# genrule(
#     name = "preproc",
#     message = "Preprocessing sources...",
#     tools = ["//ppx:metaquot_ppx"], # <= see ../../ppx/BUILD.bazel
#     srcs = ["deriving_hello.ml"],
#     outs = ["deriving_hello.pp.ml"],
#     cmd = "$(location //ppx:metaquot_ppx)"
#     + " --cookie 'library-name=\"deriving_hello\"'"
#     + " -dump-ast"
#     + " --impl $< > \"$@\";"
#     # + " $< > \"$@\";"
# )
# genrule(
#     name = "test_preproc",
#     message = "Preprocessing test sources...",
#     # hack: putting *.mlh in tools establishes dependency;
#     # putting them in srcs complicates the cmd
#     tools = glob(["test/import_relativity/**/*.mlh"])
#     + [":test_ppx"],
#     srcs = ["test/import_relativity.ml", "test/injection.ml"],
#     outs = TEST_SRCS_PPed,
#     cmd = "for f in $(SRCS);"
#     + "do"
#     + "    echo $$f;"
#     + "    BNAME=`basename $$f`;"
#     + "    HD=`expr \"$$BNAME\" : '\(.\).*'`;"
#     + "    HD=`echo $$HD | tr [a-z] [A-Z]`;"
#     + "    TL=`expr \"$$BNAME\" : '.\(.*\)'`;"
#     + "    $(location :test_ppx)"
#     + "    --cookie 'library-name=\"ppx_optcomp_test\"'"
#     + "    -o $(@D)/_tmp_/ppx_optcomp_test__$$HD$$TL"
#     + "    --impl $$f"
#     + "    -corrected-suffix .ppx-corrected"
#     + "    -diff-cmd - "
#     + "    --dump-ast;"
#     + " done"
# )
