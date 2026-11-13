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
# -nt/-g: C code in HM_TEXT, after the original startup segment (see pdm2wasm)
WCC_FLAGS := -q -bt=dos -ms -0 -s -zl -ecc -zp1 -os -w4 -we -nt=HM_TEXT -g=CGROUP
ARGC      := tests/traces/hangman.argc.json
# Deep trace: calls into original functions are compared too, except those
# implemented in C (C-to-C calls never pass through the original address).
DEEP      := --deep $(HM)/functions.txt --deep-skip $(HM)/replaced.txt

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
	@# The original startup zeroes only the original BSS, so C must not add any.
	@awk '$$1=="_BSS" && $$NF!="00000000" {print "error: C code added uninitialised data (_BSS " $$NF " bytes); initialise it or use an original global"; exit 1}' $(HMB)/hangman.map

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

# Every tests/traces/NAME.json input script has a golden NAME.trace
# recorded from the original binary.
SCENARIOS := $(basename $(notdir $(wildcard tests/traces/hangman-*.json)))

trace: $(PY)
	@rm -f $(ARGC)
	@for s in $(SCENARIOS); do \
	  $(PY) tools/pdm_trace.py $(ORIG) --script tests/traces/$$s.json \
	    $(DEEP) --learn-argc $(ARGC) >/dev/null 2>&1; \
	done
	@for s in $(SCENARIOS); do \
	  $(PY) tools/pdm_trace.py $(ORIG) --script tests/traces/$$s.json \
	    $(DEEP) --argc $(ARGC) -t tests/traces/$$s.trace 2>&1 | grep -E 'stopped' | sed "s/^/$$s: /"; \
	done

trace-check: $(REBUILT) | $(PY)
	@fail=0; for s in $(SCENARIOS); do \
	  $(PY) tools/pdm_trace.py $(REBUILT) --script tests/traces/$$s.json \
	    $(DEEP) --argc $(ARGC) -t build/$$s.trace >/dev/null 2>&1; \
	  if diff -u tests/traces/$$s.trace build/$$s.trace > build/$$s.diff; then \
	    echo "PASS $$s"; else echo "FAIL $$s (see build/$$s.diff)"; fail=1; fi; \
	done; exit $$fail

run-original:
	tools/dosbox_run.py hangman-original --cmd "DESK.EXE HANGMAN.PDM" --frames 15,38

run-rebuilt: $(REBUILT)
	tools/dosbox_run.py hangman-rebuilt --overlay $(REBUILT)=HANGMAN.PDM \
	  --cmd "DESK.EXE HANGMAN.PDM" --frames 15,38

clean:
	rm -rf build
