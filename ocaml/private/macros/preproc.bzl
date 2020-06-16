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

def ocaml_submodule_rename(name, prefix, srcs):
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

def ocaml_preproc(name, ppx, srcs):
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

def ocaml_redirector_gen(name, redirector, srcs):
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
