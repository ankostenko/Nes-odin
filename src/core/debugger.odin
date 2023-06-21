package core

import "core:fmt"

_make_flags_string :: proc(using cpu: ^CPU) -> string {
    return fmt.tprintf("%s%s%s%s%s%s%s| ",
                    "N " if negative else "- ",
                    "V " if overflow else "- ",
                    "B " if break_flag else "- ",
                    "D " if decimal else "- ",
                    "I " if interrupt else "- ",
                    "Z " if zero else "- ",
                    "C " if carry else "- ")
}

_make_cpu_state_string :: proc(using cpu: ^CPU) -> string {
    return fmt.tprintf("%4X> a: %2X x: %2X y: %2X s: %2X clk: %8d ppu_clk: %8d | ", pc, a, x, y, s, clock, system.ppu.clock)
}

_make_ppu_state_string :: proc(using cpu: ^CPU) -> string {
    return fmt.tprintf("v: %5t nmi: %5t bta: %4X ppuctrl: %2x ",
                        system.ppu.in_vblank,
                        system.ppu.nmi_on_vblank,
                        system.ppu.base_table_address,
                        system_read_byte(system, 0x2000))
}

dump_cpu :: proc(using cpu: ^CPU) {
    fmt.print(fmt.tprintf("%s%s%s", _make_cpu_state_string(cpu), _make_flags_string(cpu), _make_ppu_state_string(cpu)))
}

opcode_to_mnemonic :: proc(opcode: u8) -> string {
    switch opcode {
        case 0x00:
            return "BRK"
        case 0x01, 0x05, 0x09, 0x0D, 0x11, 0x15, 0x19, 0x1D:
            return "ORA"
        case 0x06, 0x0A, 0x0E, 0x16, 0x1E:
            return "ASL"
        case 0x08:
            return "PHP"
        case 0x0C:
            return "NOP"
        case 0x10:
            return "BPL"
        case 0x18:
            return "CLC"
        case 0x20:
            return "JSR"
        case 0x21, 0x25, 0x29, 0x2D, 0x31, 0x35, 0x39, 0x3D:
            return "AND"
        case 0x24, 0x2C:
            return "BIT"
        case 0x26, 0x2A, 0x2E, 0x36, 0x3E:
            return "ROL"
        case 0x28:
            return "PLP"
        case 0x30:
            return "BMI"
        case 0x38:
            return "SEC"
        case 0x40:
            return "RTI"
        case 0x41, 0x45, 0x49, 0x4D, 0x51, 0x55, 0x59, 0x5D:
            return "EOR"
        case 0x46, 0x4A, 0x4E, 0x56, 0x5E:
            return "LSR"
        case 0x48:
            return "PHA"
        case 0x4C, 0x6C:
            return "JMP"
        case 0x50:
            return "BVC"
        case 0x58:
            return "CLI"
        case 0x60:
            return "RTS"
        case 0x61, 0x65, 0x69, 0x6D, 0x71, 0x75, 0x79, 0x7D:
            return "ADC"
        case 0x66, 0x6A, 0x6E, 0x76, 0x7E:
            return "ROR"
        case 0x68:
            return "PLA"
        case 0x70:
            return "BVS"
        case 0xB0:
            return "BCS"
        case 0xD0:
            return "BNE"
        case 0xF0:
            return "BEQ"
        case 0x78:
            return "SEI"
        case 0x81, 0x85, 0x8D, 0x91, 0x95, 0x99, 0x9D:
            return "STA"
        case 0x84, 0x8C, 0x94:
            return "STY"
        case 0x86, 0x8E, 0x96:
            return "STX"
        case 0x88:
            return "DEY"
        case 0x8A:
            return "TXA"
        case 0xAA:
            return "TAX"
        case 0xA8:
            return "TAY"
        case 0x98:
            return "TYA"
        case 0xBA:
            return "TSX"
        case 0x9A:
            return "TXS"
        case 0xA0, 0xA4, 0xAC, 0xB4, 0xBC:
            return "LDY"
        case 0xA1, 0xA5, 0xA9, 0xAD, 0xB1, 0xB5, 0xB9, 0xBD:
            return "LDA"
        case 0xA2, 0xA6, 0xAE, 0xB6, 0xBE:
            return "LDX"
        case 0xC0, 0xC4, 0xCC:
            return "CPY"
        case 0xC1, 0xC5, 0xC9, 0xCD, 0xD1, 0xD5, 0xD9, 0xDD:
            return "CMP"
        case 0xC6, 0xCE, 0xD6, 0xDE:
            return "DEC"
        case 0xCA:
            return "DEX"
        case 0xE0, 0xE4, 0xEC:
            return "CPX"
        case 0xE1, 0xE5, 0xE9, 0xED, 0xF1, 0xF5, 0xF9, 0xFD:
            return "SBC"
        case 0xE6, 0xEE, 0xF6, 0xFE:
            return "INC"
        case 0xE8:
            return "INX"
        case 0xC8:
            return "INY"
        case 0xEA:
            return "NOP"
        case 0xD8:
            return "CLD"
        case 0xF8:
            return "SED"
        case 0xB8:
            return "CLV"
        case:
            return("UOPCODE")
    }
}

// Returns an argument of the given opcode depending on the addressing mode
opcode_argument :: proc(using cpu: ^CPU, opcode: u8) -> string {
    argument: string
    switch opcode {
        // All instruction with immediate addressing mode
        case 0x09, 0x29, 0x49, 0x69, 0x0A, 0x2A, 0x4A, 0x6A, 0xC9, 0xE9, 0xC0, 0xE0, 0xA9, 0xA2, 0xA0:
            argument = fmt.tprintf("#$%02X", am_imm(cpu))
        // All instructions with zero page addressing mode
        case 0x05, 0x25, 0x45, 0x65, 0x85, 0xA5, 0xC5, 0xE5, 0x06, 0x26, 0x46, 0x66, 0xC6, 0xE6, 0xA6, 0x24, 0xC4, 0xE4, 0xA4, 0x84:
            argument = fmt.tprintf("$%02X", am_zp_address(cpu))
        // All instructions with zero page, x addressing mode
        case 0x15, 0x35, 0x55, 0x75, 0x95, 0xB5, 0xD5, 0xF5, 0x16, 0x36, 0x56, 0x76, 0xD6, 0xF6, 0xB4, 0x94:
            argument = fmt.tprintf("$%02X,X", am_zp_address(cpu))
        // All instructions with zero page, y addressing mode
        case 0x96, 0xB6:
            argument = fmt.tprintf("$%02X,Y", am_zp_address(cpu))
        // All instructions with absolute addressing mode
        case 0x20, 0x0D, 0x2D, 0x4D, 0x6D, 0x8D, 0xAD, 0xCD, 0xED, 0x0E, 0x2E, 0x4E, 0x6E, 0x8E, 0xAE, 0xCE, 0xEE, 0xAC, 0xCC, 0xEC, 0xBC, 0x8C:
            argument = fmt.tprintf("$%04X", am_abs_address(cpu))
        // All instructions with absolute, x addressing mode
        case 0x1D, 0x3D, 0x5D, 0x7D, 0x9D, 0xBD, 0xDD, 0xFD, 0x1E, 0x3E, 0x5E, 0x7E, 0x9E, 0xBE, 0xDE, 0xFE:
            argument = fmt.tprintf("$%04X,X", am_abs_address(cpu))
        // All instructions with absolute, y addressing mode
        case 0x19, 0x39, 0x59, 0x79, 0x99, 0xB9, 0xD9, 0xF9:
            argument = fmt.tprintf("$%04X,Y", am_abs_address(cpu))
        // All instructions with indirect zero page, x addressing mode
        case 0x01, 0x21, 0x41, 0x61, 0x81, 0xA1, 0xC1, 0xE1:
            argument = fmt.tprintf("($%02X,X)", am_zp_address(cpu))
        // All instructions with indirect zero page, y addressing mode
        case 0x11, 0x31, 0x51, 0x71, 0x91, 0xB1, 0xD1, 0xF1:
            argument = fmt.tprintf("($%02X),Y", am_zp_address(cpu))
        case 0x10, 0x30, 0x50, 0x70, 0x90, 0xB0, 0xD0, 0xF0: // Branches
            offset := am_imm(cpu) // Even though it is relative addressing mode, the argument is an immediate value
            argument = fmt.tprintf("$%04X", _calculate_address_for_jump(pc + 2, i8(offset)))
        case:
            argument = ""
    }

    // Post processing an argument to replace it with known addresses if possible
    if argument == "$2002" {
        return "$2002 (PPUSTATUS)"
    } else if argument == "$2000" {
        return "$2000 (PPUCTRL)"
    } else if argument == "$2001" {
        return "$2001 (PPUMASK)"
    } else if argument == "$2003" {
        return "$2003 (OAMADDR)"
    } else if argument == "$2004" {
        return "$2004 (OAMDATA)"
    } else if argument == "$2005" {
        return "$2005 (PPUSCROLL)"
    } else if argument == "$2006" {
        return "$2006 (PPUADDR)"
    } else if argument == "$2007" {
        return "$2007 (PPUDATA)"
    } else if argument == "$4014" {
        return "$4014 (OAMDMA)"
    }

    return argument
}