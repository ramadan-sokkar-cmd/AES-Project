/******************************************************************************
 * AES-128 Baremetal Application Linker Script for ZynqMP A53 (AArch64)
 * Places application in DDR at 0x100000 (1 MB offset)
 *****************************************************************************/

_STACK_SIZE = DEFINED(_STACK_SIZE) ? _STACK_SIZE : 0x40000;
_HEAP_SIZE  = DEFINED(_HEAP_SIZE)  ? _HEAP_SIZE  : 0x10000;

MEMORY
{
   psu_ddr_0 : ORIGIN = 0x00100000, LENGTH = 0x7FF00000
}

ENTRY(_vector_table)

SECTIONS
{
.text : {
   KEEP (*(.vectors))
   *(.boot)
   *(.text)
   *(.text.*)
   *(.gnu.linkonce.t.*)
   *(.plt)
   *(.gnu_warning)
} > psu_ddr_0

.rodata (ALIGN(16)): {
   __rodata_start = .;
   *(.rodata)
   *(.rodata.*)
   *(.gnu.linkonce.r.*)
   *(.rodata1)
   *(.rodata1.*)
   *(.eh_frame)
   *(.eh_frame.*)
   *(.gnu.linkonce.e.*)
   __rodata_end = .;
} > psu_ddr_0

.data (ALIGN(16)): {
   __data_start = .;
   *(.data)
   *(.data.*)
   *(.gnu.linkonce.d.*)
   *(.data1)
   *(.data1.*)
   *(.sdata)
   *(.sdata.*)
   *(.gnu.linkonce.s.*)
   *(.got)
   *(.got.*)
   *(.got1)
   *(.got1.*)
   *(.got2)
   *(.got2.*)
   __data_end = .;
} > psu_ddr_0

.init_array (ALIGN(16)): {
   PROVIDE_HIDDEN (__init_array_start = .);
   KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))
   KEEP (*(.init_array .ctors))
   PROVIDE_HIDDEN (__init_array_end = .);
} > psu_ddr_0

.fini_array (ALIGN(16)): {
   PROVIDE_HIDDEN (__fini_array_start = .);
   KEEP (*(SORT_BY_INIT_PRIORITY(.fini_array.*) SORT_BY_INIT_PRIORITY(.dtors.*)))
   KEEP (*(.fini_array .dtors))
   PROVIDE_HIDDEN (__fini_array_end = .);
} > psu_ddr_0

.bss (ALIGN(16)) (NOLOAD) : {
   __sbss_start = .;
   __sbss_start__ = .;
   *(.sbss)
   *(.sbss.*)
   *(.gnu.linkonce.sb.*)
   __sbss_end = .;
   __sbss_end__ = .;

   __bss_start = .;
   __bss_start__ = .;
   *(.bss)
   *(.bss.*)
   *(.gnu.linkonce.b.*)
   *(COMMON)
   __bss_end = .;
   __bss_end__ = .;
} > psu_ddr_0

.heap (ALIGN(16)) (NOLOAD) : {
   _heap = .;
   _heap_start = .;
   . += _HEAP_SIZE;
   _heap_end = .;
} > psu_ddr_0

/* Stack section — must be at the end of DDR so stack grows downward */
.stack (ALIGN(16)) (NOLOAD) : {
   _stack_end = .;
   . += _STACK_SIZE;
   . = ALIGN(16);
   _stack = .;
   __stack = _stack;
   /* EL3 stack used by boot.S during initial exception level setup */
   __el3_stack = .;
   . += 0x1000;
} > psu_ddr_0

_end = .;
PROVIDE(end = .);

/DISCARD/ : {
   *(.ARM.extab*)
   *(.ARM.exidx*)
   *(.glue_7)
   *(.glue_7t)
   *(.note.GNU-stack)
}
}
