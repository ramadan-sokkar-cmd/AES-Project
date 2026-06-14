/*
 * ============================================================================
 * Minimal Multi-EL Startup for AES-128 Baremetal App (ZynqMP A53)
 * ============================================================================
 * Works at EL3, EL2, or EL1. Disables MMU and flushes TLB — all physical
 * addresses directly accessible (Device-nGnRnE, non-cacheable).
 *
 * After QSPI boot, A53 #0 is at EL2 (U-Boot, MMU on). After rst -processor, EL3.
 * This startup detects EL, sets VBAR, disables MMU, and calls main().
 * ============================================================================
 */

/* ---- Exception Vector Table (2KB, 16 entries × 128 bytes) ---- */
.section .vectors, "ax"
.balign 2048
.global _vector_table
_vector_table:
    /* Current EL with SP0 */
    b   _start                 /* 0x000: Sync (also our reset entry) */
    .space 0x7C
    b   _exc_hang              /* 0x080: IRQ */
    .space 0x7C
    b   _exc_hang              /* 0x100: FIQ */
    .space 0x7C
    b   _exc_hang              /* 0x180: SError */
    .space 0x7C

    /* Current EL with SPx */
    b   _exc_hang              /* 0x200: Sync */
    .space 0x7C
    b   _exc_hang              /* 0x280: IRQ */
    .space 0x7C
    b   _exc_hang              /* 0x300: FIQ */
    .space 0x7C
    b   _exc_hang              /* 0x380: SError */
    .space 0x7C

    /* Lower EL using AArch64 */
    b   _exc_hang              /* 0x400: Sync */
    .space 0x7C
    b   _exc_hang              /* 0x480: IRQ */
    .space 0x7C
    b   _exc_hang              /* 0x500: FIQ */
    .space 0x7C
    b   _exc_hang              /* 0x580: SError */
    .space 0x7C

    /* Lower EL using AArch32 */
    b   _exc_hang              /* 0x600: Sync */
    .space 0x7C
    b   _exc_hang              /* 0x680: IRQ */
    .space 0x7C
    b   _exc_hang              /* 0x700: FIQ */
    .space 0x7C
    b   _exc_hang              /* 0x780: SError */
    .space 0x7C

/* ---- Startup Code ---- */
.section .boot, "ax"
.global _start
.type _start, %function

_start:
    /* Mask all interrupts (A, I, F) — prevents U-Boot timer IRQs */
    msr  daifset, #0xf

    /* Load vector table address */
    ldr  x0, =_vector_table

    /* Detect exception level */
    mrs  x1, currentel

    /* Set VBAR and disable MMU for the current EL */
    cmp  x1, #0xc              /* EL3? */
    b.eq _init_el3
    cmp  x1, #0x8              /* EL2? */
    b.eq _init_el2
    cmp  x1, #0x4              /* EL1? */
    b.eq _init_el1
    b   _exc_hang              /* Unknown EL → hang */

_init_el3:
    msr  vbar_el3, x0
    mrs  x1, sctlr_el3
    bic  x1, x1, #0x1          /* M=0: MMU off */
    bic  x1, x1, #0x4          /* C=0: D-cache off */
    msr  sctlr_el3, x1
    tlbi alle3
    b   _post_mmu

_init_el2:
    msr  vbar_el2, x0
    mrs  x1, sctlr_el2
    bic  x1, x1, #0x1          /* M=0: MMU off */
    bic  x1, x1, #0x4          /* C=0: D-cache off */
    msr  sctlr_el2, x1
    tlbi alle2
    b   _post_mmu

_init_el1:
    msr  vbar_el1, x0
    mrs  x1, sctlr_el1
    bic  x1, x1, #0x1          /* M=0: MMU off */
    bic  x1, x1, #0x4          /* C=0: D-cache off */
    msr  sctlr_el1, x1
    tlbi alle1

_post_mmu:
    dsb  sy
    isb

    /* Invalidate I-cache (instruction addresses may change with MMU off) */
    ic   iallu
    dsb  sy
    isb

    /* Set up stack pointer */
    ldr  x0, =__el3_stack
    mov  sp, x0

    /* Zero BSS: from __sbss_start__ to __bss_end__ */
    ldr  x0, =__sbss_start__
    ldr  x1, =__bss_end__
    mov  x2, xzr
1:
    cmp  x0, x1
    b.cs 2f
    str  x2, [x0], #8
    b    1b
2:

    /* Call main() — MMU OFF, all physical addresses accessible */
    bl   main

    /* If main returns, halt forever */
3:
    wfi
    b    3b

/* ---- Exception Handler (infinite loop) ---- */
_exc_hang:
    b    _exc_hang

/* ---- C runtime stubs (needed because -nostartfiles skips crtbegin/crtend) ---- */
.global _init
_init:
    ret

.global _fini
_fini:
    ret
