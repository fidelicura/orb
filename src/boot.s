.option norvc /* our code is for RV32IM, so no compressed instructions, thus we disable them */

.section .data

.section .text.init

    .global _start

_start:
  /* get the ID of the currently running hart (hardware thread) */
  csrr t0, mhartid
  /*
    if the hart id is not 0, then we are not the main thread, so we need
    to "spin" current hart infinitely. otherwise, we are the main thread
    and we need to "escape assembly" as fast as we can to run kernel code
  */
  bnez  t0, 3f
  /*
    NAME: Supervisor Address Translation and Protection (SATP) register,
    used to turn on and off virtual memory addressing hardware mechanism
    NAME: Control and Status Register (CSR),
    used to interact with internal state of processor
    INFO: we clear the SATP, which is in separate memory space of CSRs,
    because we want to work with physical addresses while booting, so we
    disable the enabled-by-default virtual memory hardware mechanism
  */
  csrw satp, zero
.option push
.option norelax /* prevent gnu as from silly optimizations based on virtual memory addressing */
  la gp, _global_pointer
.option pop
  /* load bss range addresses to clear BSS section further */
  la a0, _bss_start
  la a1, _bss_end
  /*
    skip clearing BSS if `_bss_start` address >= `_bss_end` address, it may
    be useful only if our programs and kernel will not use any global
    uninitialized and static variables in any way, so no use BSS which
    means that `_bss_start` address will be equal to `_bss_end` address,
    because we have got no data to put in BSS and it will be empty
  */
  bgeu a0, a1, 2f

/* here we clear the BSS section */
1:
  sw zero, (a0)
  addi a0, a0, 8
  bltu a0, a1, 1b

2:
  /*
    NAME: Stack Pointer (SP) register,
    used to control current size of a stack and manipulate with it
    INFO: we set the stack pointer to the start of a stack so our
    more high-level languages can use it correctly, and for us it
    will be more intuitive from an assembly language level too
  */
  la sp, _stack_start
  /*
    !start of "trap return" mechanism!
    see more in privileged specification
  */
  /*
    !look through RISC-V privilege levels in the first place!
    NAME: [Machine-level] Interrupt Enabled (MIE) bit,
    used to globally enable or disable interrupts of machine level
    NAME: [Machine-level] Previous Interrupt Enabled (MPIE) bit,
    used to save value of MIE when interrupt occurs to restore it
    then from it back to MIE when interrupt finishes
    NAME: [Machine-level] Previous Privilege (PP) pair of bits,
    used to save previous level of privilege mode, usually to
    restore from an interruption that is allowed to be executed
    only on a machine privilege level, because of safety reasons
    INFO: we globally enable interrupts to allow hardware-backed
    system calls, we keep interrupts enabled using the set bit and
    we strongly stay on a machine privilege level to be allowed
    to get all possible resources of a hardware we are running on
  */
  li t0, (0b11 << 11) | (1 << 7) | (1 << 3)
  csrw mstatus, t0
  /*
    NAME: Program Counter (PC) register,
    used to hold the address of the current instruction 
    NAME: [Machine-level] Exception Program Counter (MEPC) bit,
    can hold any possible address inside of it, used to restore
    an instruction address that has encountered the exception
    INFO: set the address of `kmain` function from `kernel.zig`
    as program counter to give control of execution to it at
    the end of assembly, when we `mret` the program control
    INFO: `kmain` is "kernel main" function
  */
  la t1, kmain
  csrw mepc, t1
  /*
    LINK: https://stackoverflow.com/a/56986772, if you don't know
    such things as traps, exceptions, interrups and so on
    NAME: [Machine-level] Trap-VECtor base-address (mtvec) register,
    used to store an address of trap handler (i.e. function) that
    will be executed when trap/exception/interrupt occurs
    INFO: set the address of the trap function in our code
    that will handle trap occurence when we get an exception
    INFO: `ktrap` is "kernel trap" function
  */
  la t2, ktrap
  csrw mtvec, t2
  /*
    NAME: [Machine-level] Interrupt-Enable (MIE) register,
    used to enable or disable interrupts on a machine privilege level
    !not to be confused with MIE *bit*!
    NAME: [Machine-level] Software Interrupt-Enable (MSIE) bit,
    used to enable or disable machine privilege level software interrupts
    NAME: [Machine-level] External Interrupt-Enable (MEIE) bit,
    used to enable or disable external interrupts at machine privilege level
    INFO: we setup for future use software interrupts (e.g. inter-processor
    interrupt for multithreading) and external interrupts (e.g. handling
    ethernet devices from hardware)
  */
  li t3, (1 << 3) | (1 << 11)
  csrw mie, t3
  /* finally, we store the return address and jump right into our Zig code */
  la ra, 3f
  mret

3:
  /* spin the hart infinitely, see `wfi` instruction */
  wfi
  j 3b
