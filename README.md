# Description

This project is a very-very commented and detailed explanation on writing your own small kernel for 32-bit RISC-V.
It is built upon [QEMU] - an emulation software, using [`virt`].

# Build

1) Install [Zig] programming language:
- Linux: <https://ziglang.org/download>
2) Install [QEMU] system for RISC-V:
- Ubuntu: `apt install qemu-system-misc`
- Arch: `pacman -S qemu-system-riscv`
3) Install [Just] command runner:
- Ubuntu: `apt install just`
- Arch: `pacman -S just`
4) Install [`gdb`] debugger:
- Ubuntu: `apt install gdb`
- Arch: `pacman -S gdb`
4) Run or build in an appropriate way:
- `just build`: builds a whole project as a single binary
- `just run`: builds a whole project and runs built binary in a QEMU
- `just dbg`: builds a whole project and runs build binary in a QEMU with open debugging port
- `just gdb`: connects to the open QEMU debugging port (_see `just dbg`_) using [`gdb`]

>There is also `helper.gdb` [GDB] script for printing relevant information while debugging. You may find it useful.

# Code

Order of look-through:
1) `src/linker.lds`
2) `src/boot.s`
3) `src/kernel.zig`
4) `src/uart.zig`
Just read comments from file in a provided order.

# Clarifications

Kernel is built for 4-core RV32IM ISA compatible CPU with ILP32 ABI using [GNU] toolchain (see [GCC]). The source code does not implement BIOS, only the kernel itself!

<!-- Appendix: links -->
[QEMU]: https://qemu.org
[`virt`]: https://qemu.org/docs/master/system/riscv/virt.html
[Zig]: https://ziglang.org
[Just]: https://just.systems
[`gdb`]: https://gnu.org/software/gdb
[GDB]: https://gnu.org/software/gdb
[GNU]: https://gnu.org/
[GCC]: https://gcc.gnu.org/
