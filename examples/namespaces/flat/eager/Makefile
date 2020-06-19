
MODE=-c
LINK_LAZY=
# -no-alias-deps

## NOTE: these are listed in dependency order, which is established by
## the module aliases contained in the files. For example, Alpha.ml says
## `module Beta1 = Alpha__Beta1`, so Alph__Beta1.cmo precedes Alpha.cmo.
OBJS= \
Alpha__Beta1__Gamma__Goodbye.cmo \
Alpha__Beta1__Gamma__Hello.cmo \
Alpha__Beta2__Gamma__Gday.cmo \
Alpha__Gamma__Howdy.cmo \
Alpha__Beta1__Gamma.cmo \
Alpha__Beta1.cmo \
Alpha__Beta2__Gamma.cmo \
Alpha__Beta2.cmo \
Alpha__Gamma.cmo \
Alpha.cmo

driver: ${OBJS}
	ocamlc ${LINK_LAZY} ${OBJS} Driver.ml -o Driver.exe

Alpha.cma: ${OBJS}
	ocamlc -linkall -a ${OBJS} -o Alpha.cma

## Namer modules do not have compile-time deps:
Alpha__Beta1__Gamma__Hello.cmo:
	ocamlc -w -49 -c ${LINK_LAZY} Alpha__Beta1__Gamma__Hello.ml

Alpha__Beta1__Gamma__Goodbye.cmo:
	ocamlc -w -49 ${MODE} ${LINK_LAZY} Alpha__Beta1__Gamma__Goodbye.ml -o Alpha__Beta1__Gamma__Goodbye.cmo

Alpha__Beta2__Gamma__Gday.cmo:
	ocamlc -w -49 ${MODE} ${LINK_LAZY} Alpha__Beta2__Gamma__Gday.ml -o Alpha__Beta2__Gamma__Gday.cmo

Alpha__Gamma__Howdy.cmo:
	ocamlc -w -49 ${MODE} ${LINK_LAZY} Alpha__Gamma__Howdy.ml

## NS modules do have compile-time linkage deps: the modules it
## aliases. Remove one of them and you will get "Error: Unbound
## module".
Alpha__Gamma.cmo: Alpha__Gamma__Howdy.cmo
	ocamlc -w -49 ${MODE} ${LINK_LAZY} Alpha__Gamma.ml

Alpha__Beta1__Gamma.cmo: Alpha__Beta1__Gamma__Goodbye.cmo Alpha__Beta1__Gamma__Hello.cmo
	ocamlc -w -49 ${MODE} ${LINK_LAZY} Alpha__Beta1__Gamma.ml -o Alpha__Beta1__Gamma.cmo

Alpha__Beta1.cmo: Alpha__Beta1__Gamma.cmo
	ocamlc -w -49 ${MODE} ${LINK_LAZY} Alpha__Beta1.ml -o Alpha__Beta1.cmo

Alpha__Beta2__Gamma.cmo: Alpha__Beta2__Gamma__Gday.cmo
	ocamlc -w -49 ${MODE} ${LINK_LAZY} Alpha__Beta2__Gamma.ml

Alpha__Beta2.cmo: Alpha__Beta2__Gamma.cmo
	ocamlc -w -49 ${MODE} ${LINK_LAZY} Alpha__Beta2.ml

Alpha.cmo: Alpha__Beta1.cmo Alpha__Beta2.cmo Alpha__Gamma.cmo
	ocamlc -w -49 ${MODE} ${LINK_LAZY} Alpha.ml

clean:
	-rm *.exe 2>/dev/null || true;
	-rm *.cmi 2>/dev/null || true;
	-rm *.cmo 2>/dev/null || true;
	-rm *.cma 2>/dev/null || true;
	-rm *.cmx 2>/dev/null || true;
	-rm *.cmxa 2>/dev/null || true;
