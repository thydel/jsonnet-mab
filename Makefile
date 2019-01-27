top:; date

.DELETE_ON_ERROR:
.DEFAULT_GOAL := tests

Makefile:;

yaml2json.py := import sys, yaml, json;
yaml2json.py.opts := indent=4, default=str, sort_keys=True
yaml2json.py += json.dump(yaml.load(sys.stdin), sys.stdout, $(yaml2json.py.opts))
yaml2json    := python3 -c '$(yaml2json.py)'

%.json: tests.yml; < $< $(yaml2json) | jq .$* > $@

json.names := match bind matchAndBind
jsons := $(json.names:%=%.json)

jsons: $(jsons)

tests: jsons; @./tests.jsonnet | jq

clean:; rm $(jsons)

.PHONY: jsons tests clean

