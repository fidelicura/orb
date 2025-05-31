const std = @import("std");
const uart = @import("uart.zig");

// setup printf-like writer using zig standard library
const Writer = std.io.GenericWriter(u32, error{}, uart_put_str);
const uart_writer = Writer{ .context = 0 };

// callback to handle printf-like writer in our simple kernel
fn uart_put_str(_: u32, str: []const u8) !usize {
    for (str) |ch| {
        uart.put_char(ch);
    }
    return str.len;
}

// just an example of abstraction over created writer
pub fn println(comptime fmt: []const u8, args: anytype) void {
    uart_writer.print(fmt ++ "\n", args) catch {};
}

// if something bad happens (trap/exception/interrupt), we will
// get to this function and should handle that case appropriately
export fn ktrap() align(4) callconv(.C) noreturn {
    // you spin me right round
    while (true) {}
}

// here we are, at the human readable source code. this is kernel entrypoint which
// will be invoked by the booting (main) hart after the boot code has executed
export fn kmain() callconv(.C) void {
    // NAME: Universal Asynchronous Receiver/Transmitter (UART),
    // used to send data between devices that is quite legacy though
    // INFO: setup access to UART device, so we can print messages
    // to the console or, in our case imaginary, monitor, for example
    uart.init();
    // using our UART connector to print a message at the end of the boot
    println("Zig is running on barebones RISC-V (rv{})!", .{@bitSizeOf(usize)});
    // end of our kernel code and whole codebase as well, bye
}
