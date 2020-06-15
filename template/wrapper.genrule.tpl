## generate a wrapper module containing lines of the form:
## module Foo_bar = Ppx_version__Foo_bar""",
## Lines will be generated from filenames in the current directory.
genrule(
    name = "{MODULE}_wrapper_gen",
    message = "Generating wrapper module code...",
    ## Globbing is supported, but it's better to list inputs explicitly:
    srcs = ["AMOD.ml", "BMOD.ml"],
    outs = ["{MODULE}.ml"],
    cmd = " for f in $(SRCS);"
    + " do"
    + "     BNAME=`basename $$f`;"
    ## remove .ml extension
    + "     BNAME=`expr \"$$BNAME\" : '\(.*\)...'`;"
    ## upcase first letter
    + "     HD=`expr \"$$BNAME\" : '\(.\).*'`;"
    + "     HD=`echo $$HD | tr [a-z] [A-Z]`;"
    ## get the remainder
    + "     TL=`expr \"$$BNAME\" : '.\(.*\)'`;"
    ## assemble the converted name
    + "     echo module $$HD$$TL = {MODULE}__$$HD$$TL >> \"$@\";"
    + " done"
)

genrule(
    name = "preproc_and_rename",
    message = "Preprocessing and renaming modules...",
    tools = [{TOOL}],
    ## Globbing is supported, but it's better to list inputs explicitly:
    srcs = ["A_MOD.ml", "B_MOD.ml"],
    ## Outputs must be explicitly enumerated:
    outs = [
        "{MODULE}__A_MOD.ml",
        "{MODULE}__B_MOD.ml",
    ],
    cmd = "for f in $(SRCS);"
    + " do"
    ## transform the file name: capitalize, then prefix module_name__
    + "    BNAME=`basename $$f`;"
    + "    HD=`expr \"$$BNAME\" : '\(.\).*'`;"
    + "    TL=`expr \"$$BNAME\" : '.\(.*\)'`;"
    + "    MODULE={MODULE}__$$HD$$TL;"
    ## preprocess and write to new name
    + "    $(location {TOOL}) $$f > $(@D)/$$MODULE;"
    + " done"
)
