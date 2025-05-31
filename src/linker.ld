/* see https://sourceware.org/binutils/docs-2.43/ld/ for more information */

/*
  overall algorithm of linker script is simple and straightforward:
  1) declare virtual memory regions from physical address space
  2) specify runtime memory segments (known as program headers)
  3) fill program headers with contents from sections (know as program sections)
*/

/*
  LINK: https://sourceware.org/binutils/docs-2.43/ld/Miscellaneous-Commands.html#index-OUTPUT_005fARCH_0028bfdarch_0029
  INFO: particular output for specific architecture
*/
OUTPUT_ARCH( "riscv" )

/*
  LINK: https://sourceware.org/binutils/docs-2.43/ld/Entry-Point.html#index-ENTRY_0028symbol_0029
  INFO: execution of kernel will start from this label
*/
ENTRY( _start )

/*
  LINK: https://sourceware.org/binutils/docs-2.43/ld/MEMORY.html
  INFO: as long as we got no kernel, we have an access to a
  full physical memory space, and we want to add properties to
  specific address ranges to make interactions more safe or
  just valid due to restrictions of a specific hardware
*/
MEMORY
{
  /*
    declare "ram" memory region that is allowed to be written to (w),
    executed program instructions from (x), and linker can put sections
    in this address space (a). starting from address 0x80000000 with
    a length of 128 megabytes. we start from 0x80000000 because it
    a default convetions for kernels, therefore on lower addresses
    some really important read-only data may be present, like
    memory-mapped register file address and so on
  */
  ram (wxa) : ORIGIN = 0x80000000, LENGTH = 128M
}

/*
  LINK: https://sourceware.org/binutils/docs-2.43/ld/PHDRS.html
  INFO: default algorithm of defining ELF program segments that
  linker has to find from a source code (in our case, it is boot.s) file,
  so, a kernel that will eat this binary, can understand what should go
  where (map a sections and address them correctly) to run our binary
*/
PHDRS
{
  text PT_LOAD;
  data PT_LOAD;
  bss PT_LOAD;
}

/*
  LINK: https://sourceware.org/binutils/docs-2.43/ld/SECTIONS.html
  INFO: it describes program sections in the resulting binary
  file, so we need to handle all sections from all the source files we
  work on. in short, each section is split into two parts: output and input.
  output section, which is before curly braces, describes how will look
  the section in the resulting binary, meanwhile thte input section, which
  is after the curly braces, defines how we handle multiple section
  definitions across multiple source files that we are linking together.
  we also got multiple predefined "functions" like `PROVIDE` or `HIDDEN`,
  patterns with a wildcard, a symbol to get current address (dot) and so on
*/
SECTIONS
{
  /*
    explanation will be only for this segment, but it is straightforward to
    be applied to other parts as well. so, we define `.text` segment, that
    will contain all `.text*` parts from all source files in kernel and
    will be placed in `ram` memory region for both execution and storing.
    note, that store memory and executable memory is not useful in our
    case, because our system does not have distinct storage memory
    and execution memory, but on other devices it may be useful to put
    segments in storage memory, and load it into execution memory at runtime
  */
  .text : {
    PROVIDE(_text_start = .);
    *(.text.init) *(.text .text.*)
    PROVIDE(_text_end = .);
  } >ram AT>ram :text

  PROVIDE(_global_pointer = .);

  .rodata : {
    PROVIDE(_rodata_start = .);
    *(.rodata .rodata.*)
    PROVIDE(_rodata_end = .);
  } >ram AT>ram :text

  .data : {
    /*
      this section is used to store some type
      of data, so we need to align it properly
    */
    . = ALIGN(4096);
    PROVIDE(_data_start = .);
    *(.sdata .sdata.*) *(.data .data.*)
    PROVIDE(_data_end = .);
  } >ram AT>ram :data

  .bss : {
    /*
      we may store some data in future, but at start this is just
      zeroed out memory, so linker will automatically align it for us
    */
    PROVIDE(_bss_start = .);
    *(.sbss .sbss.*) *(.bss .bss.*)
    PROVIDE(_bss_end = .);
  } >ram AT>ram :bss

  PROVIDE(_mem_start = ORIGIN(ram));
  PROVIDE(_mem_end = ORIGIN(ram) + LENGTH(ram));
  PROVIDE(_stack_size = 0x80000 /* 512 kilobytes */);
  PROVIDE(_stack_start = _bss_end + _stack_size);
  PROVIDE(_heap_start = _stack_start);
  PROVIDE(_heap_size = _mem_end - _heap_start);

  /*
    resulting look of memory would look like:
    -------------------------------------------------------------------------
    | other memory before our program that we do not care much              |
    -------------------------------------------------------------------------
    | _mem_start = 0x80000000                                               |
    -------------------------------------------------------------------------
    | .text(1) section of some size (depends on data from compiled program) |
    -------------------------------------------------------------------------
    | .data section of some size (depends on data from compiled program)    |
    -------------------------------------------------------------------------
    | .bss section of some size (depends on data from compiled program)     |
    -------------------------------------------------------------------------
    | uninitialized preallocated memory for stack                           |
    -------------------------------------------------------------------------
    | _stack_start = 0x80080000 (_bss_end addres + 512 kilobytes in hex)    |
    -------------------------------------------------------------------------
    | _heap_start = 0x80080000 (every end address is exclusive, so it ok)   |
    -------------------------------------------------------------------------
    | uninitialized preallocated memory for heap                            |
    -------------------------------------------------------------------------
    | _mem_end = 0x88000000 (_mem_start address + 128 megabytes in hex)     |
    -------------------------------------------------------------------------
    | other memory after our program that we do not care much               |
    -------------------------------------------------------------------------
    1) `.text` section also contains contents from `.rodata` section
  */
}
