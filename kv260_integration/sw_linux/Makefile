# ============================================================================
# AES-128 Linux Application Makefile (ZynqMP A53, PetaLinux)
# ============================================================================
# Cross-compiles on Windows using the Vitis aarch64-linux-gnu toolchain.
#
# Usage:
#   make          — compile
#   make clean    — remove binary
# ============================================================================

# ---- Toolchain ----
GCC_DIR = C:/AMDDesignTools/2025.2/Vitis/gnu/aarch64/nt/aarch64-linux/bin
CC      = $(GCC_DIR)/aarch64-linux-gnu-gcc.exe

# ---- Paths ----
SHARED_INC = ../sw_baremetal

# ---- Flags ----
CFLAGS = -O2 -Wall -I$(SHARED_INC)
LDFLAGS = -static

# ---- Target ----
TARGET = aes_linux

.PHONY: all clean

all: $(TARGET)

$(TARGET): aes_linux.c $(SHARED_INC)/aes_hw.h
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ aes_linux.c
	@echo ""
	@echo "==============================================="
	@echo "  Build complete: $@"
	@file $@ 2>NUL || echo "  (aarch64 Linux ELF)"
	@echo "==============================================="

clean:
	del /Q $(TARGET) 2>NUL || true
