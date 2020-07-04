load("ppx_archive.bzl"       , _ppx_archive      = "ppx_archive")
load("ppx_binary.bzl"        , _ppx_binary       = "ppx_binary")
load("ppx_library.bzl"       , _ppx_library      = "ppx_library")
load("ppx_module.bzl"        , _ppx_module       = "ppx_module")
load("ppx_test.bzl"          , _ppx_test         = "ppx_test")

ppx_archive  = _ppx_archive
ppx_binary   = _ppx_binary
ppx_library  = _ppx_library
ppx_module   = _ppx_module
ppx_test     = _ppx_test

