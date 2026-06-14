# ============================================================================
# AES-128 Baremetal Application Makefile (ZynqMP A53, Standalone BSP)
# ============================================================================
# Prerequisites:
#   - Vitis 2025.2 platform must be generated (run build_baremetal.tcl first)
#   - BSP at workspace/aes_platform/psu_cortexa53_0/standalone_domain/bsp/
#
# Usage:
#   make          — compile and link
#   make clean    — remove build artifacts
# ============================================================================

# ---- Toolchain ----
GCC_DIR = C:/AMDDesignTools/2025.2/Vitis/gnu/aarch64/nt/aarch64-none/bin
CC      = $(GCC_DIR)/aarch64-none-elf-gcc.exe
OBJCOPY = $(GCC_DIR)/aarch64-none-elf-objcopy.exe

# ---- Paths ----
PROJECT_ROOT = .
WORKSPACE    = $(PROJECT_ROOT)/workspace
BSP_DIR      = $(WORKSPACE)/aes_platform/psu_cortexa53_0/standalone_domain/bsp/psu_cortexa53_0
BSP_INC      = $(BSP_DIR)/include
BSP_LIB      = $(BSP_DIR)/lib

# ---- Source files ----
SRC_C   = aes_baremetal.c
SRC_S   = start.S
OBJ_C   = $(SRC_C:.c=.o)
OBJ_S   = $(SRC_S:.S=.o)
OBJ     = $(OBJ_S) $(OBJ_C)

# ---- Compiler flags ----
CFLAGS  = -O2 -c -Wall -Wextra -g \
          -DARMA53_64 \
          -ffunction-sections -fdata-sections \
          -fno-tree-loop-distribute-patterns \
          -I$(BSP_INC) \
          -I.

# ---- Linker flags ----
# -nostartfiles: skip BSP/GCC crt0 (we use start.S — no MMU, raw physical)
# No -lxil: our app accesses hardware directly, no BSP library calls needed
LDFLAGS = -nostartfiles -n \
          -Wl,--gc-sections \
          -Wl,--build-id=none \
          -T lscript.ld \
          -Wl,--start-group,-lgcc,-lc,--end-group

# ---- Target ----
TARGET  = aes_baremetal.elf
TARGET2 = aes_fsbl.elf
TARGET3 = aes_ila_loop.elf

.PHONY: all fsbl ila clean

all: $(TARGET)

fsbl: $(TARGET2)

ila: $(TARGET3)

$(TARGET): CFLAGS += 
$(TARGET): $(OBJ) lscript.ld
	$(CC) $(LDFLAGS) $(OBJ) -o $@
	@echo ""
	@echo "==============================================="
	@echo "  Build complete: $@ (JTAG mode)"
	@echo "  Size:"
	@$(GCC_DIR)/aarch64-none-elf-size.exe $@
	@echo "==============================================="

$(TARGET2): CFLAGS += -DFSBL_BOOT
$(TARGET2): aes_baremetal.c start.S aes_hw.h lscript.ld
	$(CC) $(CFLAGS) -c start.S -o start_fsbl.o
	$(CC) $(CFLAGS) -c aes_baremetal.c -o aes_baremetal_fsbl.o
	$(CC) $(LDFLAGS) start_fsbl.o aes_baremetal_fsbl.o -o $@
	@del /Q start_fsbl.o aes_baremetal_fsbl.o 2>NUL || true
	@echo ""
	@echo "==============================================="
	@echo "  Build complete: $@ (FSBL boot mode)"
	@echo "  Size:"
	@$(GCC_DIR)/aarch64-none-elf-size.exe $@
	@echo "==============================================="

$(TARGET3): CFLAGS += -DFSBL_BOOT
$(TARGET3): aes_ila_loop.c start.S aes_hw.h lscript.ld
	$(CC) $(CFLAGS) -c start.S -o start_ila.o
	$(CC) $(CFLAGS) -c aes_ila_loop.c -o aes_ila_loop.o
	$(CC) $(LDFLAGS) start_ila.o aes_ila_loop.o -o $@
	@del /Q start_ila.o aes_ila_loop.o 2>NUL || true
	@echo ""
	@echo "==============================================="
	@echo "  Build complete: $@ (ILA loop mode)"
	@echo "  Size:"
	@$(GCC_DIR)/aarch64-none-elf-size.exe $@
	@echo "==============================================="

%.o: %.c aes_hw.h
	$(CC) $(CFLAGS) $< -o $@

%.o: %.S
	$(CC) $(CFLAGS) $< -o $@

clean:
	del /Q *.o $(TARGET) $(TARGET2) $(TARGET3) 2>NUL || true

# ---- Assembler file dependencies ----
start.o: start.S
