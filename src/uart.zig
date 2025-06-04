//! LINK: https://www.qemu.org/docs/master/system/riscv/virt.html#supported-devices
//! INFO: this is a driver for the NS16550A UART device, which is the only driver
//! supported on the QEMU `virt` platform for virtualization as a generic device

const std = @import("std");

pub const Register = struct {
    pub const Common = struct {
        const Self = @This();

        pub const base: usize = 0x10000000;

        /// Calculates an address of the register and casts it into the pointer.
        /// Accepts only `Register.ReadOnly`, `Register.WriteOnly` and `Register.ReadWrite`.
        /// Returns a pointer to the specified register.
        fn calculate_pointer(self: anytype) *volatile u8 {
            switch (@TypeOf(self)) {
                Register.ReadOnly, Register.WriteOnly, Register.ReadWrite => {},
                else => |T| {
                    const message = std.fmt.comptimePrint("function accepts only `Register.ReadOnly`, `Register.WriteOnly` or `Register.ReadWrite`: got {}", .{T});
                    @compileError(message);
                },
            }

            const offset = @intFromEnum(self);
            const address = Self.base + offset;
            return @ptrFromInt(address);
        }

        /// Validates that passed value (`with`) is either of the same type of `Self`,
        /// or a pointer to it. Produces compile error if `with` is incorrect. Returns
        /// `with` unchanged if it was a `Self`, otherwise (i.e., `with` was a pointer)
        /// dereferences `with` and returns the underlying `Self` value.
        pub fn validate_any_self(comptime S: type, with: anytype) Self {
            const T = @TypeOf(with);
            const type_info = @typeInfo(T);

            const error_message = std.fmt.comptimePrint("function accepts only `Self`, `*Self` or `*const Self`: expected {}, got {}", .{ Self, T });

            switch (type_info) {
                .pointer => |pointer_info| {
                    if (pointer_info.size != .one) @compileError(error_message);

                    const child_type = pointer_info.child;
                    if (child_type != S) @compileError(error_message);

                    return with.*;
                },
                .@"struct" => {
                    if (T != S) @compileError(error_message);

                    return with;
                },
                else => @compileError(error_message),
            }
        }
    };

    pub const ReadOnly = enum(u8) {
        const Self = @This();

        usingnamespace Register.Common;

        const ReadOnlyImpl = struct {
            /// Read a byte from the specified (as `self`) UART register.
            /// Accepts only `Self`, `*Self` or `*const Self`.
            pub fn read(self: anytype) u8 {
                const value = Self.validate_any_self(Self, self); // TODO: infers as ReadOnly, while called from ReadWrite
                const pointer = Self.calculate_pointer(value);
                return pointer.*;
            }
            pub const load = read; // convenient alias
        };
        pub usingnamespace ReadOnlyImpl;

        receive_buffer = 0x00,
        line_status = 0x05,

        pub const Status = enum(u8) {
            line_status_ready = (1 << 1),
        };
    };

    pub const WriteOnly = enum(u8) {
        const Self = @This();

        usingnamespace Register.Common;

        const WriteOnlyImpl = struct {
            /// Writes a byte to the specified (as `self`) UART register.
            /// Accepts only `Self`, `*Self` or `*const Self`.
            pub fn write(self: anytype, byte: u8) void {
                const value = Self.validate_any_self(Self, self); // TODO: infers as WriteOnly, while called from ReadWrite
                const pointer = Self.calculate_pointer(value);
                pointer.* = byte;
            }
            pub const store = write; // convenient alias
        };
        pub usingnamespace WriteOnlyImpl;

        transmitter_holding = 0x00,
        fifo_control = 0x02,
        line_control = 0x03,

        pub const Status = enum(u8) {
            transmitter_holding_empty = (1 << 1),
        };
    };

    pub const ReadWrite = enum(u8) {
        const Self = @This();

        usingnamespace Register.Common;

        const ReadWriteImpl = struct {
            pub usingnamespace Register.ReadOnly.ReadOnlyImpl;
            pub usingnamespace Register.WriteOnly.WriteOnlyImpl;
        };
        pub usingnamespace ReadWriteImpl;

        // TODO: abstract method to work with divisor latches as a single register
        divisor_latch_least = 0x00,
        divisor_latch_most = 0x01,
        pub const interrupt_enable = Self.divisor_latch_most;
    };

    pub const Latch = enum(u1) {
        const Self = @This();

        low,
        high,
    };
};

pub fn put_char(byte: u8) void {
    const is_transmitter_holding_empty = @intFromEnum(Register.WriteOnly.Status.transmitter_holding_empty);
    // wait for the transmission line to be empty before enqueuing more bytes to
    // the device by checking transmission holding register bit in LSR
    while (Register.ReadOnly.line_status.read() & is_transmitter_holding_empty == 1) {}

    // transmission line of device is empty, it is ready to accept bytes
    Register.WriteOnly.transmitter_holding.write(byte);
}

pub fn get_char() ?u8 {
    // we can read bytes from UART only when it is ready to do so, therefore we
    // need to check if is it ready, by looking at LSR.
    const current_line_status_register_status = Register.ReadOnly.line_status.read();
    const is_line_status_ready = @intFromEnum(Register.ReadOnly.Status.line_status_ready);
    const line_status_register_readiness_mask = current_line_status_register_status & is_line_status_ready;

    const is_there_byte_available_to_read = line_status_register_readiness_mask == 1;
    if (is_there_byte_available_to_read) {
        return Register.ReadOnly.receive_buffer.read();
    } else {
        return null;
    }
}

/// LINK: https://www.lammertbies.nl/comm/info/serial-uart
/// INFO: code to initialize NS16550A UART device to a ready state according to manual. the
/// goal of this process is to say to UART in what form our communication with it will
/// happen: a size of a single communication unit (character), if there would be any signs
/// (i.e. stop bits, parity bits), types of registers that would be used (latch or data), etc
/// MORE: https://www.lammertbies.nl/comm/info/rs-232-specs
pub fn init() void {
    // INFO: enter and setup i/o communication mode
    // SCHEMA:
    //  each character is equal to 8 bits
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━┓
    //  single stop bit is used                         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━━━┓ ┃
    //  data io registers are used                    ┃ ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━┓         ┃ ┣┓
    Register.WriteOnly.line_control.write(0b0_0_0_0_0_0_11);
    // SCHEMA:
    //  enable FIFO
    // ┗━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    Register.WriteOnly.fifo_control.write(0b00_0_0_0_0_0_1);
    // SCHEMA:
    //  enable interrupts for "received data available" status
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━┛
    Register.ReadWrite.interrupt_enable.write(0b0000_0_0_0_0);

    // INFO: setup latch for communication frequency
    // SCHEMA:
    //  each character is equal to 8 bits
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━┓
    //  single stop bit is used                         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━━━┓ ┃
    //  latch registers are used                      ┃ ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━┓         ┃ ┣┓
    Register.WriteOnly.line_control.write(0b1_0_0_0_0_0_11);
    // INFO: divisor latch is actually a single register split
    // ┏━━━━━━━━━━━━━━━┓
    // ┃ DIVISOR LATCH ┃
    // ┣━━━━━━━┳━━━━━━━┫
    // ┃  DLM  ┃  DLL  ┃
    // ┣━━━━━━━╋━━━━━━━┫
    // ┃[15..8]┃[7...0]┃
    // ┗━━━━━━━┻━━━━━━━┛
    Register.ReadWrite.divisor_latch_least.write(80);
    Register.ReadWrite.divisor_latch_most.write(2);

    // INFO: return to the i/o communication mode
    // SCHEMA:
    //  each character is equal to 8 bits
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━┓
    //  single stop bit is used                         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━━━┓ ┃
    //  data io registers are used                    ┃ ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━┓         ┃ ┣┓
    Register.WriteOnly.line_control.write(0b0_0_0_0_0_0_11);
}
