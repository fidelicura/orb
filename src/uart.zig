//! LINK: https://www.qemu.org/docs/master/system/riscv/virt.html#supported-devices
//! INFO: this is a driver for the NS16550A UART device, which is the only driver
//! supported on the QEMU `virt` platform for virtualization as a generic device

// LINK: https://uart16550.readthedocs.io/_/downloads/en/latest/pdf/
// INFO: communication with UART is made using UART registers, so there
// are many registers that we are gonna use to make some simple stuff

/// LINK: https://github.com/qemu/qemu/blob/master/hw/riscv/virt.c#L94
/// INFO: address space of UART serial device is located at 0x10000000
export const UART_BASE: usize = 0x10000000;

// SECTION: input registers
/// Recieve Buffer Register
export const UART_RBR_OFFSET: usize = 0;
/// Line Status Register
export const UART_LSR_OFFSET: usize = 5;

// SECTION: output registers
/// Divisor Latch Low
export const UART_DLL_OFFSET: usize = 0;
/// Divisor Latch High
export const UART_DLM_OFFSET: usize = 1;
/// FIFO Control Register
export const UART_FCR_OFFSET: usize = 2;
/// Line Control Register
export const UART_LCR_OFFSET: usize = 3;

// SECTION: input and output registers
/// Interrupt Enable Register
export const UART_IER_OFFSET: usize = 1;

// SECTION: constants of possible UART internal states
/// Receiver Data is in "Ready" state
export const UART_LSR_RDR: usize = 0b0_0_0_0_0_0_0_1;
/// Transmit Hold Register is in "Empty" state
export const UART_LSR_THRE: usize = 0b0_0_1_0_0_0_0_0;

// simple write behind a pointer to a specific address
fn write_reg(offset: usize, value: u8) void {
    const ptr: *volatile u8 = @ptrFromInt(UART_BASE + offset);
    ptr.* = value;
}

// simple read behind a pointer from a specific address
fn read_reg(offset: usize) u8 {
    const ptr: *volatile u8 = @ptrFromInt(UART_BASE + offset);
    return ptr.*;
}

pub fn put_char(ch: u8) void {
    // wait for the transmission line to be empty before
    // enqueuing more characters to the device via checking
    // transmission holding register bit in LSR
    while ((read_reg(UART_LSR_OFFSET) & UART_LSR_THRE) == 0) {}

    write_reg(0, ch);
}

pub fn get_char() ?u8 {
    // check that we actually have a character to read
    if (read_reg(UART_LSR_OFFSET) & UART_LSR_RDR == 1) {
        // if so, then we read this characeter and return it
        return read_reg(UART_RBR_OFFSET);
    }

    // otherwise, return nothing
    return null;
}

/// LINK: https://www.lammertbies.nl/comm/info/serial-uart
/// INFO: code to initialize NS16550A UART device to a ready state according to manual. the
/// goal of this process is to say to UART in what form our communication with it will
/// happen: a size of a single communication unit (character), if there would be any signs
/// (i.e. stop bits, parity bits), types of registers that would be used (latch or data), etc
/// MORE: https://www.lammertbies.nl/comm/info/rs-232-specs
pub fn init() void {
    // INFO: data io registers are RBR, THR and IER
    // SCHEMA:
    //  each character is equal to 8 bits
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┻━━━┓
    //  single stop bit is used              ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━┓ ┃
    //  data io registers are used         ┃ ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━┻┓         ┃ ┣┓
    write_reg(UART_LCR_OFFSET, 0b0_0_0_0_0_0_11);
    // SCHEMA:
    //  enable FIFO
    // ┗━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    write_reg(UART_FCR_OFFSET, 0b00_0_0_0_0_0_1);
    // SCHEMA:
    //  enable interrupts for "received data available" status
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━┛
    write_reg(UART_IER_OFFSET, 0b0000_0_0_0_0);
    // INFO: latch registers are DLL and DLM
    // SCHEMA:
    //  each character is equal to 8 bits
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┻━━━┓
    //  single stop bit is used              ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━┓ ┃
    //  latch registers are used           ┃ ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━┳┛        ┃ ┣┓
    write_reg(UART_LCR_OFFSET, 0b1_0_0_0_0_0_11);

    // least communication frequency speed
    write_reg(UART_DLL_OFFSET, 80);
    // most communication frequency speed
    write_reg(UART_DLM_OFFSET, 2);

    // SCHEMA:
    //  each character is equal to 8 bits
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┻━━━┓
    //  single stop bit is used              ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━┓ ┃
    //  data io registers are used         ┃ ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━┻┓         ┃ ┣┓
    write_reg(UART_LCR_OFFSET, 0b0_0_0_0_0_0_11);
}
