load("ppx_archive.bzl"       , _ppx_archive      = "ppx_archive")
load("ppx_executable.bzl"        , _ppx_executable       = "ppx_executable")
load("ppx_library.bzl"       , _ppx_library      = "ppx_library")
load("ppx_module.bzl"        , _ppx_module       = "ppx_module")
load("ppx_test.bzl"          , _ppx_test         = "ppx_test")

ppx_archive  = _ppx_archive
ppx_executable   = _ppx_executable
ppx_library  = _ppx_library
ppx_module   = _ppx_module
ppx_test     = _ppx_test

