set quiet

JUST_EXEC := just_executable()

build OPT:
    zig build -Doptimize={{OPT}}

run:
    {{JUST_EXEC}} cls
    {{JUST_EXEC}} build ReleaseSafe
    qemu-system-riscv32 -machine virt -bios none -kernel zig-out/bin/kernel -m 128M -cpu rv32 -smp 4 -nographic -serial mon:stdio

dbg:
    {{JUST_EXEC}} cls
    {{JUST_EXEC}} build Debug
    qemu-system-riscv32 -machine virt -bios none -kernel zig-out/bin/kernel -m 128M -cpu rv32 -smp 4 -nographic -serial mon:stdio -s -S

gdb:
    gdb zig-out/bin/kernel -ex "set architecture riscv:rv32" -ex "target remote localhost:1234" -ex "break _start" -ex "continue" -ex "set scheduler-locking on" -ex "source helper.gdb"

cls:
    rm -rf zig-out/ kernel.dtb kernel.dts

dtb:
    {{JUST_EXEC}} cls
    {{JUST_EXEC}} build Debug
    qemu-system-riscv32 -machine virt -machine dumpdtb=kernel.dtb -bios none -kernel zig-out/bin/kernel -m 128M -cpu rv32 -smp 4 -nographic -serial mon:stdio
    dtc -I dtb -O dts -o kernel.dts kernel.dtb
