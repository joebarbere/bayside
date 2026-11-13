# Bayside top-level dev loop.
#
#   make setup          create .venv with capstone + unicorn
#   make hangman        build src/hangman with OpenWatcom (~/watcom or $WATCOM)
#   make trace          trace original HANGMAN.PDM -> refresh golden trace
#   make trace-check    trace the rebuilt HANGMAN and diff against the golden
#   make run-original   headless DOSBox-X: original Hangman, frames in build/run/
#   make run-rebuilt    headless DOSBox-X: rebuilt Hangman swapped in
#
# Works from any shell (fish included): the OpenWatcom env is set here rather
# than by sourcing scripts/setup-watcom.sh.

WATCOM ?= $(HOME)/watcom
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_S)/$(UNAME_M),Linux/x86_64)
  WATCOM_BIN := binl64
else ifeq ($(UNAME_S)/$(UNAME_M),Linux/aarch64)
  WATCOM_BIN := arml64
else ifeq ($(UNAME_S)/$(UNAME_M),Darwin/arm64)
  WATCOM_BIN := armo64
else
  WATCOM_BIN := binm
endif
WATCOM_ENV = WATCOM=$(WATCOM) PATH=$(WATCOM)/$(WATCOM_BIN):$$PATH \
             INCLUDE="$(WATCOM)/h;$(WATCOM)/h/sys" EDDAT=$(WATCOM)/eddat \
             LIB="$(WATCOM)/lib286;$(WATCOM)/lib286/dos"

PY        := .venv/bin/python
ORIG      := archive/deskmate-3.05/extracted/HANGMAN.PDM
REBUILT   := build/hangman/HANGMAN.EXE
SCRIPT    := tests/traces/hangman-define-ok.json
GOLDEN    := tests/traces/hangman-define-ok.trace

.PHONY: setup hangman trace trace-check run-original run-rebuilt clean

setup: $(PY)
$(PY): tools/requirements.txt
	uv venv -q .venv 2>/dev/null || python3 -m venv .venv
	uv pip install -q -p .venv -r tools/requirements.txt 2>/dev/null || \
	  .venv/bin/pip install -q -r tools/requirements.txt
	@touch $(PY)

hangman:
	cd src/hangman && $(WATCOM_ENV) wmake -h

trace: $(PY)
	$(PY) tools/pdm_trace.py $(ORIG) --script $(SCRIPT) -t $(GOLDEN)

trace-check: $(PY) hangman
	$(PY) tools/pdm_trace.py $(REBUILT) --script $(SCRIPT) -t build/hangman-rebuilt.trace
	diff -u $(GOLDEN) build/hangman-rebuilt.trace

run-original:
	tools/dosbox_run.py hangman-original --cmd "DESK.EXE HANGMAN.PDM" --frames 15,38

run-rebuilt: hangman
	tools/dosbox_run.py hangman-rebuilt --overlay $(REBUILT)=HANGMAN.PDM \
	  --cmd "DESK.EXE HANGMAN.PDM" --frames 15,38

clean:
	rm -rf build
