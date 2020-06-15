genrule(
    name = "preproc",
    visibility = ["//visibility:public"],
    message = "Preprocessing sources...",
    tools = ["{TOOL}"],
    srcs = ["{SRC}.mli", "{SRC}.ml"],
    ## OUTPUT ORDER MATTERS! Put the mli files before the ml files:
    outs = ["pp_{SRC}.mli", "pp_{SRC}.ml"],
    cmd = "for f in $(SRCS);"
    + "do"
    + "    echo $$f;"
    + "    BNAME=`basename $$f`;"
    + "    PGM=$(location {TOOL});"
    + "    echo PGM $$PGM;"
    + "    $(location {TOOL})"
    + "    --dump-ast"
    + "    $$f > $(@D)/pp_$$BNAME;"
    + " done"
)
