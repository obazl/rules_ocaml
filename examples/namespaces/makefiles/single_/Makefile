
all: Amod_Bmod_Hello.cmo
	ocamlc *.cmo Driver.ml -o Driver.exe

Amod.cmo:
	ocamlc -w -49 -c -no-alias-deps Amod.ml

Amod_Bmod.cmo: Amod.cmo
	ocamlc -w -49 -c -no-alias-deps Amod_Bmod.ml

Amod_Bmod_Hello.cmo: Amod_Bmod.cmo
	ocamlc -c -no-alias-deps Amod_Bmod_Hello.ml

clean:
	rm *.cmo;
	rm *.cmi;
	rm *.exe;
