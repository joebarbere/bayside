# Bayside top-level dev loop.
#
#   make setup          create .venv with capstone + unicorn
#   make hangman        build HANGMAN.PDM: original code + C functions from
#                       src/hangman/replaced.txt spliced in (build/hangman/)
#   make identical      rebuild with no C spliced in; must be byte-identical
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
REBUILT   := build/hangman/HANGMAN.PDM
HM        := src/hangman
HMB       := build/hangman
HM_C      := $(wildcard $(HM)/*.c)
HM_OBJ    := $(patsubst $(HM)/%.c,$(HMB)/%.obj,$(HM_C))
# -ms small model, -0 8086, -s no stack checks, -zl no default libs,
# -ecc __cdecl everywhere (MSC convention, so C <-> original code calls work),
# -zp1 byte packing, -os optimise for size
WCC_FLAGS := -q -bt=dos -ms -0 -s -zl -ecc -zp1 -os -w4 -we
SCRIPT    := tests/traces/hangman-define-ok.json
GOLDEN    := tests/traces/hangman-define-ok.trace
ARGC      := tests/traces/hangman.argc.json

.PHONY: setup hangman identical trace trace-check run-original run-rebuilt clean

setup: $(PY)
$(PY): tools/requirements.txt
	uv venv -q .venv 2>/dev/null || python3 -m venv .venv
	uv pip install -q -p .venv -r tools/requirements.txt 2>/dev/null || \
	  .venv/bin/pip install -q -r tools/requirements.txt
	@touch $(PY)

hangman: $(REBUILT)

$(HMB)/orig.asm: $(ORIG) $(HM)/functions.txt $(HM)/replaced.txt $(HM)/dgroup.syms tools/pdm2wasm.py | $(PY)
	@mkdir -p $(HMB)
	$(PY) tools/pdm2wasm.py $(ORIG) --functions $(HM)/functions.txt \
	  --replaced $(HM)/replaced.txt --data-syms $(HM)/dgroup.syms -o $@

$(HMB)/orig.obj: $(HMB)/orig.asm
	$(WATCOM_ENV) wasm -q -0 -fo=$@ $<

$(HMB)/%.obj: $(HM)/%.c $(HM)/hangman.h
	@mkdir -p $(HMB)
	$(WATCOM_ENV) wcc $(WCC_FLAGS) -fo=$@ $<

# orig.obj must be linked first: its segments fix the original layout.
$(HMB)/hangman.exe: $(HMB)/orig.obj $(HM_OBJ)
	$(WATCOM_ENV) wlink option quiet format dos option map=$(HMB)/hangman.map \
	  option nodefaultlibs option start=_crt_start name $@ \
	  $(foreach o,$^,file $(o)) 2>&1 | grep -v W1014 || true
	@test -f $@

$(REBUILT): $(HMB)/hangman.exe tools/mkpdm.py
	$(PY) tools/mkpdm.py $< --orig $(ORIG) --map $(HMB)/hangman.map -o $@

identical: | $(PY)
	@mkdir -p build/identical
	$(PY) tools/pdm2wasm.py $(ORIG) --functions $(HM)/functions.txt \
	  --data-syms $(HM)/dgroup.syms -o build/identical/orig.asm
	$(WATCOM_ENV) wasm -q -0 -fo=build/identical/orig.obj build/identical/orig.asm
	$(WATCOM_ENV) wlink option quiet format dos option map=build/identical/h.map \
	  option nodefaultlibs option start=_crt_start name build/identical/h.exe \
	  file build/identical/orig.obj 2>&1 | grep -v W1014 || true
	$(PY) tools/mkpdm.py build/identical/h.exe --orig $(ORIG) \
	  --map build/identical/h.map -o build/identical/HANGMAN.PDM --verify

trace: $(PY)
	$(PY) tools/pdm_trace.py $(ORIG) --script $(SCRIPT) --learn-argc $(ARGC)
	$(PY) tools/pdm_trace.py $(ORIG) --script $(SCRIPT) --argc $(ARGC) -t $(GOLDEN)

trace-check: $(REBUILT) | $(PY)
	$(PY) tools/pdm_trace.py $(REBUILT) --script $(SCRIPT) --argc $(ARGC) -t build/hangman-rebuilt.trace
	diff -u $(GOLDEN) build/hangman-rebuilt.trace

run-original:
	tools/dosbox_run.py hangman-original --cmd "DESK.EXE HANGMAN.PDM" --frames 15,38

run-rebuilt: $(REBUILT)
	tools/dosbox_run.py hangman-rebuilt --overlay $(REBUILT)=HANGMAN.PDM \
	  --cmd "DESK.EXE HANGMAN.PDM" --frames 15,38

clean:
	rm -rf build
