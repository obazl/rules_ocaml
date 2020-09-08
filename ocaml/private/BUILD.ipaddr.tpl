## rules to compile each module
ocaml_module( name = "ipaddr_ml", intf = "ipaddr.mli", impl = "ipaddr.ml")
ocaml_module( name = "ipaddr_sexp_ml", intf = "sexp/ipaddr_sexp.mli", impl = "sexp/ipaddr_sexp.ml")
ocaml_module( name = "ipaddr_top_ml", intf = "ipaddr.mli", impl = "ipaddr.ml")
ocaml_module( name = "ipaddr_unix_ml", intf = "unix/ipaddr_unix.mli", impl = "unix/ipaddr_unix.ml")
## rules to assemble libs/archives
ocaml_archive( name = "ipaddr",  ## produces ipaddr.cmxa
               deps = [":ipaddr_ml",
                       "//lib/macaddr"])
ocaml_archive( name = "sexp",   ## produces ipaddr_sexp.cmxa
               deps = [":ipaddr_sexp_ml",
                       ":ipaddr",
                       "//lib/sexplib0"])
ocaml_archive( name = "top",   ## ipaddr_top.cmxa
               deps = [":ipaddr_top_ml",
                       "//lib/compiler-libs",
                       ":ipaddr",
                       "//lib/macaddr:top"])
ocaml_archive( name = "unix",  ## ipaddr_unix.cmxa
               deps = [":ipaddr_unix_ml",
                       ":ipaddr",
                       "//lib/unix"])

