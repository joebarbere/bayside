# ========================================================================
# Makefile for HANGMAN.PDM -- OpenWatcom wmake
# ========================================================================
# Builds the transpiled HANGMAN.PDM from C89 source.
#
# Usage:
#   wmake            -- build HANGMAN.PDM
#   wmake clean      -- remove build artifacts
#
# Requires OpenWatcom C compiler (wcc) and linker (wlink).
# Set WATCOM environment variable to OpenWatcom installation path.
# ========================================================================

# Compiler and linker
CC = wcc
LINK = wlink

# Compiler flags:
#   -mm     Medium memory model (matching original MSC 5.x build)
#   -0      8086 instruction set (real mode only)
#   -bt=dos Target DOS
#   -s      Disable stack checking (original had none)
#   -ox     Maximum optimization (or -od for debug)
#   -zp1    Pack structures on 1-byte boundaries
#   -w4     Warning level 4
#   -fo=    Output object file path
CFLAGS = -mm -0 -bt=dos -s -ox -zp1 -w4

# Build directory
BUILDDIR = ../../build/hangman

# Object files
OBJS = &
    $(BUILDDIR)/hangman.obj &
    $(BUILDDIR)/hangman_ui.obj &
    $(BUILDDIR)/hangman_dialog.obj &
    $(BUILDDIR)/hangman_data.obj &
    $(BUILDDIR)/deskmate.obj

# Target
TARGET = $(BUILDDIR)/HANGMAN.EXE

# Default target
all: $(BUILDDIR) $(TARGET)

# Create build directory
$(BUILDDIR):
	mkdir -p $(BUILDDIR)

# Link
$(TARGET): $(OBJS)
	$(LINK) &
	    system dos &
	    option map=$(BUILDDIR)/hangman.map &
	    option stack=2048 &
	    name $(TARGET) &
	    file $(BUILDDIR)/hangman.obj &
	    file $(BUILDDIR)/hangman_ui.obj &
	    file $(BUILDDIR)/hangman_dialog.obj &
	    file $(BUILDDIR)/hangman_data.obj &
	    file $(BUILDDIR)/deskmate.obj

# Compile rules
$(BUILDDIR)/hangman.obj: hangman.c hangman.h deskmate.h
	$(CC) $(CFLAGS) -fo=$(BUILDDIR)/hangman.obj hangman.c

$(BUILDDIR)/hangman_ui.obj: hangman_ui.c hangman.h deskmate.h
	$(CC) $(CFLAGS) -fo=$(BUILDDIR)/hangman_ui.obj hangman_ui.c

$(BUILDDIR)/hangman_dialog.obj: hangman_dialog.c hangman.h deskmate.h
	$(CC) $(CFLAGS) -fo=$(BUILDDIR)/hangman_dialog.obj hangman_dialog.c

$(BUILDDIR)/hangman_data.obj: hangman_data.c hangman.h deskmate.h
	$(CC) $(CFLAGS) -fo=$(BUILDDIR)/hangman_data.obj hangman_data.c

$(BUILDDIR)/deskmate.obj: deskmate.c deskmate.h
	$(CC) $(CFLAGS) -fo=$(BUILDDIR)/deskmate.obj deskmate.c

# Clean
clean: .SYMBOLIC
	rm -f $(BUILDDIR)/*.obj
	rm -f $(BUILDDIR)/*.map
	rm -f $(TARGET)

