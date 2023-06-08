package core

import "core:fmt"
import "core:reflect"
import "core:strings"
import "core:math"

// Reset vector is hardwired to 0xfffc-0xfffd
RESET_VECTOR_ADDR :: 0xfffc
STACK_START_ADDR :u16: 0x0100
STACK_END_ADDR :u16: 0x01ff
IRQ_VECTOR_ADDR :u16: 0xfffe

// Size of this structure is 80 bytes
CPU :: struct {
    a: u8 // accumulator 
    x: u8 // index register x
    y: u8 // index register y
    s: u8 // stack pointer
    pc: u16 // program counter
    negative: bool // negative flag
    overflow: bool // overflow flag
    break_flag: bool // break flag
    decimal: bool // decimal flag
    interrupt: bool // interrupt flag
    zero: bool // zero flag
    carry: bool // carry flag
    system: System // system
    clock: u64 // clock cycles
}

init_cpu :: proc(system: System) -> CPU {
    reset_vector := system_read_word(system, RESET_VECTOR_ADDR)
    return CPU {
        negative=false
        overflow=false
        break_flag=false
        decimal=false
        interrupt=true
        zero=false
        carry=false
        a=0
        x=0
        y=0
        s=0xfd // stack pointer starts at 0xfd
        pc=reset_vector
        system=system
        clock=0
    }
}

dump_cpu :: proc(using cpu: CPU) {
    fmt.printf("%8X> a: %4X x: %4X y: %4X s: %4X clk: %8d | ", pc, a, x, y, s, clock)
    
    cpu_type_id := typeid_of(CPU)
    types := reflect.struct_field_types(cpu_type_id)
    for name, i in reflect.struct_field_names(cpu_type_id) {
        if reflect.is_boolean(types[i]) {
            if (cast(^bool)reflect.struct_field_value_by_name(cpu, name).data)^ {
                fmt.printf("%r ", 'V' if name == "overflow" else strings.to_upper(name)[0])
            } else {
                fmt.printf("- ")
            }   
        }
    }
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
        case 0x0D, 0x2D, 0x4D, 0x6D, 0x8D, 0xAD, 0xCD, 0xED, 0x0E, 0x2E, 0x4E, 0x6E, 0x8E, 0xAE, 0xCE, 0xEE, 0xAC, 0xCC, 0xEC, 0xBC:
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

run_opcode :: proc(using cpu: ^CPU) {
    opcode := system_read_byte(system, pc)
    argument := system_read_byte(system, pc + 1)
    fmt.printf("| %X %s %s\n", opcode, opcode_to_mnemonic(opcode), opcode_argument(cpu, opcode))
    switch opcode {
        case 0x00:
            op_brk(cpu)
        case 0x01, 0x05, 0x09, 0x0D, 0x11, 0x15, 0x19, 0x1D:
            op_ora(cpu, opcode)
        case 0x06, 0x0A, 0x0E, 0x16, 0x1E:
            op_asl(cpu, opcode)
        case 0x08:
            op_php(cpu)
        case 0x0C:
            op_nop(cpu)
        case 0x10:
            op_bpl(cpu)
        case 0x18:
            op_clc(cpu)
        case 0x20:
            op_jsr(cpu)
        case 0x21, 0x25, 0x29, 0x2D, 0x31, 0x35, 0x39, 0x3D:
            op_and(cpu, opcode)
        case 0x24, 0x2C:
            op_bit(cpu, opcode)
        case 0x26, 0x2A, 0x2E, 0x36, 0x3E:
            op_rol(cpu, opcode)
        case 0x28:
            op_plp(cpu)
        case 0x30:
            op_bmi(cpu)
        case 0x38:
            op_sec(cpu)
        case 0x40:
            op_rti(cpu)
        case 0x41, 0x45, 0x49, 0x4D, 0x51, 0x55, 0x59, 0x5D:
            op_eor(cpu, opcode)
        case 0x46, 0x4A, 0x4E, 0x56, 0x5E:
            op_lsr(cpu, opcode)
        case 0x48:
            op_pha(cpu)
        case 0x4C, 0x6C:
            op_jmp(cpu, opcode)
        case 0x50:
            op_bvc(cpu)
        case 0x58:
            op_cli(cpu)
        case 0x60:
            op_rts(cpu)
        case 0x61, 0x65, 0x69, 0x6D, 0x71, 0x75, 0x79, 0x7D:
            op_adc(cpu, opcode)
        case 0x66, 0x6A, 0x6E, 0x76, 0x7E:
            op_ror(cpu, opcode)
        case 0x68:
            op_pla(cpu)
        case 0x70:
            op_bvs(cpu)
        case 0xB0:
            op_bcs(cpu)
        case 0xD0:
            op_bne(cpu)
        case 0xF0:
            op_beq(cpu)
        case 0x78:
            op_sei(cpu)
        case 0x81, 0x85, 0x8D, 0x91, 0x95, 0x99, 0x9D:
            op_sta(cpu, opcode)
        case 0x84, 0x8C, 0x94:
            op_sty(cpu, opcode)
        case 0x86, 0x8E, 0x96:
            op_stx(cpu, opcode)
        case 0x88:
            op_dey(cpu)
        case 0x8A:
            op_txa(cpu)
        case 0xAA:
            op_tax(cpu)
        case 0xA8:
            op_tay(cpu)
        case 0x98:
            op_tya(cpu)
        case 0xBA:
            op_tsx(cpu)
        case 0x9A:
            op_txs(cpu)
        case 0xA0, 0xA4, 0xAC, 0xB4, 0xBC:
            op_ldy(cpu, opcode)
        case 0xA1, 0xA5, 0xA9, 0xAD, 0xB1, 0xB5, 0xB9, 0xBD:
            op_lda(cpu, opcode)
        case 0xA2, 0xA6, 0xAE, 0xB6, 0xBE:
            op_ldx(cpu, opcode)
        case 0xC0, 0xC4, 0xCC:
            op_cpy(cpu, opcode)
        case 0xC1, 0xC5, 0xC9, 0xCD, 0xD1, 0xD5, 0xD9, 0xDD:
            op_cmp(cpu, opcode)
        case 0xC6, 0xCE, 0xD6, 0xDE:
            op_dec(cpu, opcode)
        case 0xCA:
            op_dex(cpu)
        case 0xE0, 0xE4, 0xEC:
            op_cpx(cpu, opcode)
        case 0xE1, 0xE5, 0xE9, 0xED, 0xF1, 0xF5, 0xF9, 0xFD:
            op_sbc(cpu, opcode)
        case 0xE6, 0xEE, 0xF6, 0xFE:
            op_inc(cpu, opcode)
        case 0xE8:
            op_inx(cpu)
        case 0xC8:
            op_iny(cpu)
        case 0xEA:
            op_nop(cpu)
        case 0xD8:
            op_cld(cpu)
        case 0xF8:
            op_sed(cpu)
        case 0xB8:
            op_clv(cpu)
        case:
            panic("Unknown opcode")
    }
}

// Returns true if the page boundary is crossed when adding the offset to the address
_is_page_boundary_crossed_offset :: proc(address: u16, offset: u8) -> bool {
    return (address & 0xff00) != ((address + u16(offset)) & 0xff00)
}

// Returns true if the page boundary is crossed comparing the two addresses
_is_page_boundary_crossed :: proc(address: u16, new_address: u16) -> bool {
    return (address & 0xff00) != (new_address & 0xff00)
}

// Immediate addressing mode
am_imm :: proc(using cpu: ^CPU) -> u8 {
    argument_address := pc + 1
    return system_read_byte(system, argument_address)
}


am_zp_address :: proc(using cpu: ^CPU) -> u8 {
    argument_address := pc + 1
    return system_read_byte(system, argument_address)
}

// Zero page addressing mode
am_zp :: proc(using cpu: ^CPU) -> u8 {
    address := am_zp_address(cpu)
    return system_read_byte(system, u16(address))
}

// Zero page, x addressing mode
am_zpx :: proc(using cpu: ^CPU) -> u8 {
    address := am_zp_address(cpu)
    return system_read_byte(system, u16(address + x))
}

// Zero page, y addressing mode
am_zpy :: proc(using cpu: ^CPU) -> u8 {
    address := am_zp_address(cpu)
    return system_read_byte(system, u16(address + y))
}

am_abs_address :: proc(using cpu: ^CPU) -> u16 {
    argument_address := pc + 1
    return system_read_word(system, argument_address)
}

// Absolute addressing mode
am_abs :: proc(using cpu: ^CPU) -> u8 {
    address := am_abs_address(cpu)
    return system_read_byte(system, address)
}

// Absolute, x addressing mode
// NOTE: adds a cycle if the page boundary is crossed and add_cycle_on_cross_boundary is true
am_absx :: proc(using cpu: ^CPU, add_cycle_on_cross_boundary: bool) -> u8 {
    address := am_abs_address(cpu)
    value := system_read_byte(system, address + u16(x))

    if add_cycle_on_cross_boundary && _is_page_boundary_crossed(address, address + u16(x)) {
        cpu.clock += 1
    }

    return value
}

// Absolute, y addressing mode
// NOTE: adds a cycle if the page boundary is crossed and add_cycle_on_cross_boundary is true
am_absy :: proc(using cpu: ^CPU, add_cycle_on_cross_boundary: bool) -> u8 {
    address := am_abs_address(cpu)
    value := system_read_byte(system, address + u16(y))

    if add_cycle_on_cross_boundary && _is_page_boundary_crossed(address, address + u16(y)) {
        cpu.clock += 1
    }

    return value
}

// X-indexed, indirect addressing mode
am_izx :: proc(using cpu: ^CPU) -> u8 {
    argument_address := pc + 1
    zp_address := system_read_byte(system, argument_address)
    new_address := system_read_word(system, u16(zp_address + x))
    return system_read_byte(system, new_address)
}

// Y-indexed, indirect addressing mode
// NOTE: adds a cycle if the page boundary is crossed and add_cycle_on_cross_boundary is true
am_izy :: proc(using cpu: ^CPU, add_cycle_on_cross_boundary: bool) -> u8 {
    argument_address := pc + 1
    zp_address := system_read_byte(system, argument_address)
    new_address := system_read_word(system, u16(zp_address)) + u16(y)

    if add_cycle_on_cross_boundary && _is_page_boundary_crossed(new_address - u16(y), new_address) {
        cpu.clock += 1
    }

    return system_read_byte(system, new_address)
}

is_negative :: proc(value: u8) -> bool {
    return (value & 0x80) != 0
}

is_zero :: proc(value: u8) -> bool {
    return value == 0
}

// OR with accumulator
op_ora :: proc(using cpu: ^CPU, opcode: u8) {
    switch opcode {
        case 0x09: // immediate
            cpu.a |= am_imm(cpu)
            
            cpu.clock += 2
            cpu.pc += 2
        case 0x05: // zero page
            cpu.a |= am_zp(cpu)
            
            cpu.clock += 3
            cpu.pc += 2
        case 0x15: // zero page, x
            cpu.a |= am_zpx(cpu)
            
            cpu.clock += 4
            cpu.pc += 2
        case 0x01: // indirect zero page, x
            cpu.a |= am_izx(cpu)
            
            cpu.clock += 6
            cpu.pc += 2
        case 0x11: // indirect zero page, y
            cpu.a |= am_izy(cpu, true)
            
            cpu.clock += 5
            cpu.pc += 2
        case 0x0D: // absolute
            cpu.a |= am_abs(cpu)
            
            cpu.clock += 4
            cpu.pc += 3
        case 0x1D: // absolute, x
            cpu.a |= am_absx(cpu, true)
            
            cpu.clock += 4
            cpu.pc += 3
        case 0x19: // absolute, y
            cpu.a |= am_absy(cpu, true)
            
            cpu.clock += 4
            cpu.pc += 3
        case:
            panic("Unknown opcode")
    }

    // Set flags
    cpu.negative = is_negative(cpu.a)
    cpu.zero = is_zero(cpu.a)
}


// AND - Logical AND with accumulator
op_and :: proc(using cpu: ^CPU, opcode: u8) {
    switch opcode {
        case 0x29: // immediate
            cpu.a &= am_imm(cpu)
            
            cpu.clock += 2
            cpu.pc += 2
        case 0x25: // zero page
            cpu.a &= am_zp(cpu)
            
            cpu.clock += 3
            cpu.pc += 2
        case 0x35: // zero page, x
            cpu.a &= am_zpx(cpu)
            
            cpu.clock += 4
            cpu.pc += 2
        case 0x21: // indirect zero page, x
            cpu.a &= am_izx(cpu)
            
            cpu.clock += 6
            cpu.pc += 2
        case 0x31: // indirect zero page, y
            cpu.a &= am_izy(cpu, true)
            
            cpu.clock += 5
            cpu.pc += 2
        case 0x2D: // absolute
            cpu.a &= am_abs(cpu)
            
            cpu.clock += 4
            cpu.pc += 3
        case 0x3D: // absolute, x
            cpu.a &= am_absx(cpu, true)
            
            cpu.clock += 4
            cpu.pc += 3
        case 0x39: // absolute, y
            cpu.a &= am_absy(cpu, true)
            
            cpu.clock += 4
            cpu.pc += 3
        case:
            panic("Unknown opcode")
    }

    // Set flags
    cpu.negative = is_negative(cpu.a)
    cpu.zero = is_zero(cpu.a)
}

// XOR (exclusive or) memory with accumulator
op_eor :: proc(using cpu: ^CPU, opcode: u8) {
    switch opcode {
        case 0x49: // immediate
            cpu.a ~= am_imm(cpu)
            
            cpu.clock += 2
            cpu.pc += 2
        case 0x45: // zero page
            cpu.a ~= am_zp(cpu)
            
            cpu.clock += 3
            cpu.pc += 2
        case 0x55: // zero page, x
            cpu.a ~= am_zpx(cpu)
            
            cpu.clock += 4
            cpu.pc += 2
        case 0x41: // indirect zero page, x
            cpu.a ~= am_izx(cpu)
            
            cpu.clock += 6
            cpu.pc += 2
        case 0x51: // indirect zero page, y
            cpu.a ~= am_izy(cpu, true)
            
            cpu.clock += 5
            cpu.pc += 2
        case 0x4D: // absolute
            cpu.a ~= am_abs(cpu)
            
            cpu.clock += 4
            cpu.pc += 3
        case 0x5D: // absolute, x
            cpu.a ~= am_absx(cpu, true)
            
            cpu.clock += 4
            cpu.pc += 3
        case 0x59: // absolute, y
            cpu.a ~= am_absy(cpu, true)
            
            cpu.clock += 4
            cpu.pc += 3
        case:
            panic("Unknown opcode")
    }

    // Set flags
    cpu.negative = is_negative(cpu.a)
    cpu.zero = is_zero(cpu.a)
}

op_adc :: proc(using cpu: ^CPU, opcode: u8) {
    intermediate: u16 = 0
    switch opcode {
        case 0x69: // immediate
            intermediate = u16(cpu.a + am_imm(cpu) + 1 if cpu.carry else 0)
            
            cpu.clock += 2
            cpu.pc += 2
        case 0x65: // zero page
            intermediate = u16(cpu.a + am_zp(cpu) + 1 if cpu.carry else 0)
            
            cpu.clock += 3
            cpu.pc += 2
        case 0x75: // zero page, x
            intermediate = u16(cpu.a + am_zpx(cpu) + 1 if cpu.carry else 0)
            
            cpu.clock += 4
            cpu.pc += 2
        case 0x61: // indirect zero page, x
            intermediate = u16(cpu.a + am_izx(cpu) + 1 if cpu.carry else 0)
            
            cpu.clock += 6
            cpu.pc += 2
        case 0x71: // indirect zero page, y
            intermediate = u16(cpu.a + am_izy(cpu, true) + 1 if cpu.carry else 0)
            
            cpu.clock += 5
            cpu.pc += 2
        case 0x6D: // absolute
            intermediate = u16(cpu.a + am_abs(cpu) + 1 if cpu.carry else 0)
            
            cpu.clock += 4
            cpu.pc += 3
        case 0x7D: // absolute, x
            intermediate = u16(cpu.a + am_absx(cpu, true) + 1 if cpu.carry else 0)
            
            cpu.clock += 4
            cpu.pc += 3
        case 0x79: // absolute, y
            intermediate = u16(cpu.a + am_absy(cpu, true) + 1 if cpu.carry else 0)
            
            cpu.clock += 4
            cpu.pc += 3
        case:
            panic("Unknown opcode")
    }

    // Set flags
    cpu.negative = is_negative(u8(intermediate))
    cpu.zero = is_zero(u8(intermediate))

    cpu.carry = intermediate > 255 // The flag is reset if the result is in the range 0 to 255
    // There's no notion of signed addition in 6502, so we have to convert to signed first
    cpu.overflow = i16(intermediate) > 127 || i16(intermediate) < -128 // The flag is reset if the result is in the range -128 to 127

    cpu.a = u8(intermediate)
}

op_sbc :: proc(using cpu: ^CPU, opcode: u8) {
    intermediate: u16
    switch opcode {
        case 0xE9: // immediate
            intermediate = u16(cpu.a - am_imm(cpu) - 1 if !cpu.carry else 0)
            
            cpu.clock += 2
            cpu.pc += 2
        case 0xE5: // zero page
            intermediate = u16(cpu.a - am_zp(cpu) - 1 if !cpu.carry else 0)
            
            cpu.clock += 3
            cpu.pc += 2
        case 0xF5: // zero page, x
            intermediate = u16(cpu.a - am_zpx(cpu) - 1 if !cpu.carry else 0)
            
            cpu.clock += 4
            cpu.pc += 2
        case 0xE1: // indirect zero page, x
            intermediate = u16(cpu.a - am_izx(cpu) - 1 if !cpu.carry else 0)
            
            cpu.clock += 6
            cpu.pc += 2
        case 0xF1: // indirect zero page, y
            intermediate = u16(cpu.a - am_izy(cpu, true) - 1 if !cpu.carry else 0)
            
            cpu.clock += 5
            cpu.pc += 2
        case 0xED: // absolute
            intermediate = u16(cpu.a - am_abs(cpu) - 1 if !cpu.carry else 0)
            
            cpu.clock += 4
            cpu.pc += 3
        case 0xFD: // absolute, x
            intermediate = u16(cpu.a - am_absx(cpu, true) - 1 if !cpu.carry else 0)
            
            cpu.clock += 4
            cpu.pc += 3
        case 0xF9: // absolute, y
            intermediate = u16(cpu.a - am_absy(cpu, true) - 1 if !cpu.carry else 0)
            
            cpu.clock += 4
            cpu.pc += 3
        case:
            panic("Unknown opcode")
    }

    // Set flags
    cpu.negative = is_negative(u8(intermediate))
    cpu.zero = is_zero(u8(intermediate))
    cpu.carry = intermediate >= 0
    cpu.overflow = i16(intermediate) > 127 || i16(intermediate) < -128

    cpu.a = u8(intermediate)
}

op_cmp :: proc(using cpu: ^CPU, opcode: u8) {
    intermediate: i16
    switch opcode {
        case 0xC9: // immediate
            intermediate = i16(cpu.a - am_imm(cpu))
            
            cpu.clock += 2
            cpu.pc += 2
        case 0xC5: // zero page
            intermediate = i16(cpu.a - am_zp(cpu))
            
            cpu.clock += 3
            cpu.pc += 2
        case 0xD5: // zero page, x
            intermediate = i16(cpu.a - am_zpx(cpu))
            
            cpu.clock += 4
            cpu.pc += 2
        case 0xC1: // indirect zero page, x
            intermediate = i16(cpu.a - am_izx(cpu))
            
            cpu.clock += 6
            cpu.pc += 2
        case 0xD1: // indirect zero page, y
            intermediate = i16(cpu.a - am_izy(cpu, true))
            
            cpu.clock += 5
            cpu.pc += 2
        case 0xCD: // absolute
            intermediate = i16(cpu.a - am_abs(cpu))
            
            cpu.clock += 4
            cpu.pc += 3
        case 0xDD: // absolute, x
            intermediate = i16(cpu.a - am_absx(cpu, true))
            
            cpu.clock += 4
            cpu.pc += 3
        case 0xD9: // absolute, y
            intermediate = i16(cpu.a - am_absy(cpu, true))
            
            cpu.clock += 4
            cpu.pc += 3
        case:
            panic("Unknown opcode")
    }

    // Set flags
    cpu.negative = is_negative(u8(intermediate))
    cpu.zero = is_zero(u8(intermediate))
    cpu.carry = i16(cpu.a) >= intermediate // TODO: Check this
}

op_cpx :: proc(using cpu: ^CPU, opcode: u8) {
    intermediate: i16
    switch opcode {
        case 0xE0: // immediate
            intermediate = i16(cpu.x - am_imm(cpu))
            
            cpu.clock += 2
            cpu.pc += 2
        case 0xE4: // zero page
            intermediate = i16(cpu.x - am_zp(cpu))
            
            cpu.clock += 3
            cpu.pc += 2
        case 0xEC: // absolute
            intermediate = i16(cpu.x - am_abs(cpu))
            
            cpu.clock += 4
            cpu.pc += 3
        case:
            panic("Unknown opcode")
    }

    // Set flags
    cpu.negative = is_negative(u8(intermediate))
    cpu.zero = is_zero(u8(intermediate))
    cpu.carry = i16(cpu.x) >= intermediate // TODO: Check this
}

op_cpy :: proc(using cpu: ^CPU, opcode: u8) {
    intermediate: i16
    switch opcode {
        case 0xC0: // immediate
            intermediate = i16(cpu.y - am_imm(cpu))
            
            cpu.clock += 2
            cpu.pc += 2
        case 0xC4: // zero page
            intermediate = i16(cpu.y - am_zp(cpu))
            
            cpu.clock += 3
            cpu.pc += 2
        case 0xCC: // absolute
            intermediate = i16(cpu.y - am_abs(cpu))
            
            cpu.clock += 4
            cpu.pc += 3
        case:
            panic("Unknown opcode")
    }

    // Set flags
    cpu.negative = is_negative(u8(intermediate))
    cpu.zero = is_zero(u8(intermediate))
    cpu.carry = i16(cpu.y) >= intermediate // TODO: Check this
}

op_dec :: proc(using cpu: ^CPU, opcode: u8) {
    intermediate: u8
    address: u16
    switch opcode {
        case 0xC6: // zero page
            address = u16(am_zp_address(cpu))
            intermediate = u8(am_zp(cpu) - 1)

            cpu.clock += 5
            cpu.pc += 2
        case 0xD6: // zero page, x
            address = u16(am_zp_address(cpu))
            intermediate = u8(am_zpx(cpu) - 1)

            cpu.clock += 6
            cpu.pc += 2
        case 0xCE: // absolute
            address = am_abs_address(cpu)
            intermediate = u8(am_abs(cpu) - 1)

            cpu.clock += 6
            cpu.pc += 3
        case 0xDE: // absolute, x
            address = am_abs_address(cpu)
            intermediate = u8(am_absx(cpu, false) - 1)

            cpu.clock += 7
            cpu.pc += 3
        case:
            panic("Unknown opcode")
    }

    // Set flags
    cpu.negative = is_negative(intermediate)
    cpu.zero = is_zero(intermediate)

    // Write to memory
    system_write_byte(system, address, intermediate)
}

op_dex :: proc(using cpu: ^CPU) {
    cpu.clock += 2
    cpu.pc += 1

    cpu.x -= 1

    // Set flags
    cpu.negative = is_negative(cpu.x)
    cpu.zero = is_zero(cpu.x)
}

op_dey :: proc(using cpu: ^CPU) {
    cpu.clock += 2
    cpu.pc += 1

    cpu.y -= 1

    // Set flags
    cpu.negative = is_negative(cpu.y)
    cpu.zero = is_zero(cpu.y)
}

op_inc :: proc(using cpu: ^CPU, opcode: u8) {
    intermediate: u8
    address: u16
    switch opcode {
        case 0xE6: // zero page
            address = u16(am_zp_address(cpu))
            intermediate = u8(am_zp(cpu) + 1)

            cpu.clock += 5
            cpu.pc += 2
        case 0xF6: // zero page, x
            address = u16(am_zp_address(cpu))
            intermediate = u8(am_zpx(cpu) + 1)

            cpu.clock += 6
            cpu.pc += 2
        case 0xEE: // absolute
            address = am_abs_address(cpu)
            intermediate = u8(am_abs(cpu) + 1)

            cpu.clock += 6
            cpu.pc += 3
        case 0xFE: // absolute, x
            address = am_abs_address(cpu)
            intermediate = u8(am_absx(cpu, false) + 1)

            cpu.clock += 7
            cpu.pc += 3
        case:
            panic("Unknown opcode")
    }

    cpu.negative = is_negative(intermediate)
    cpu.zero = is_zero(intermediate)

    // Write to memory
    system_write_byte(system, address, intermediate)
}

op_inx :: proc(using cpu: ^CPU) {
    cpu.clock += 2
    cpu.pc += 1

    cpu.x += 1

    // Set flags
    cpu.negative = is_negative(cpu.x)
    cpu.zero = is_zero(cpu.x)
}

op_iny :: proc(using cpu: ^CPU) {
    cpu.clock += 2
    cpu.pc += 1

    cpu.y += 1

    // Set flags
    cpu.negative = is_negative(cpu.y)
    cpu.zero = is_zero(cpu.y)
}

// Arithmetic shift left
op_asl :: proc(using cpu: ^CPU, opcode: u8) {
    intermediate: u16
    address: u16
    switch opcode {
        case 0x0A: // accumulator
            cpu.clock += 2
            cpu.pc += 1

            intermediate = u16(cpu.a) << 1
            cpu.a = u8(intermediate)
        case 0x06: // zero page
            address = u16(am_zp_address(cpu))
            intermediate = u16(am_zp(cpu)) << 1

            cpu.clock += 5
            cpu.pc += 2
            system_write_byte(system, address, u8(intermediate))
        case 0x16: // zero page, x
            address = u16(am_zp_address(cpu))
            intermediate = u16(am_zpx(cpu)) << 1

            cpu.clock += 6
            cpu.pc += 2
            system_write_byte(system, address, u8(intermediate))
        case 0x0E: // absolute
            address = am_abs_address(cpu)
            intermediate = u16(am_abs(cpu)) << 1

            cpu.clock += 6
            cpu.pc += 3
            system_write_byte(system, address, u8(intermediate))
        case 0x1E: // absolute, x
            address = am_abs_address(cpu)
            intermediate = u16(am_absx(cpu, false)) << 1

            cpu.clock += 7
            cpu.pc += 3
            system_write_byte(system, address, u8(intermediate))
        case:
            panic("Unknown opcode")
    }

    // Set flags
    cpu.negative = is_negative(u8(intermediate))
    cpu.zero = is_zero(u8(intermediate))
    cpu.carry = intermediate > 255
}

// Rotate left
op_rol :: proc(using cpu: ^CPU, opcode: u8) {
    intermediate: u16
    switch opcode {
        case 0x2A: // accumulator
            cpu.clock += 2
            cpu.pc += 1

            intermediate = u16(cpu.a) << 1
            if cpu.carry {
                intermediate |= 1
            }
            cpu.a = u8(intermediate)
        case 0x26: // zero page
            address := u16(am_zp_address(cpu))
            intermediate = u16(am_zp(cpu)) << 1

            cpu.clock += 5
            cpu.pc += 2
            if cpu.carry {
                intermediate |= 1
            }
            system_write_byte(system, address, u8(intermediate))
        case 0x36: // zero page, x
            address := u16(am_zp_address(cpu))
            intermediate = u16(am_zpx(cpu)) << 1

            cpu.clock += 6
            cpu.pc += 2
            if cpu.carry {
                intermediate |= 1
            }
            system_write_byte(system, address, u8(intermediate))
        case 0x2E: // absolute
            address := am_abs_address(cpu)
            intermediate = u16(am_abs(cpu)) << 1

            cpu.clock += 6
            cpu.pc += 3
            if cpu.carry {
                intermediate |= 1
            }
            system_write_byte(system, address, u8(intermediate))
        case 0x3E: // absolute, x
            address := am_abs_address(cpu)
            intermediate = u16(am_absx(cpu, false)) << 1

            cpu.clock += 7
            cpu.pc += 3
            if cpu.carry {
                intermediate |= 1
            }
            system_write_byte(system, address, u8(intermediate))
        case:
            panic("Unknown opcode")
    }

    // Set flags
    cpu.negative = is_negative(u8(intermediate))
    cpu.zero = is_zero(u8(intermediate))
    cpu.carry = intermediate > 255
}

// Logical shift right
op_lsr :: proc(using cpu: ^CPU, opcode: u8) {
    intermediate: u16

    switch opcode {
        case 0x4A: // accumulator
            cpu.clock += 2
            cpu.pc += 1

            value := cpu.a

            cpu.carry = value & 1 == 0 // Set carry flag to the value of the bit that is being shifted out

            intermediate = u16(value) >> 1
            cpu.a = u8(intermediate)
        case 0x46: // zero page
            address := u16(am_zp_address(cpu))
            value := am_zp(cpu)

            cpu.clock += 5
            cpu.pc += 2

            cpu.carry = value & 1 == 0 // Set carry flag to the value of the bit that is being shifted out

            intermediate = u16(value) >> 1
            system_write_byte(system, address, u8(intermediate))
        case 0x56: // zero page, x
            address := u16(am_zp_address(cpu))
            value := am_zpx(cpu)

            cpu.clock += 6
            cpu.pc += 2

            cpu.carry = value & 1 == 0 // Set carry flag to the value of the bit that is being shifted out

            intermediate = u16(value) >> 1
            system_write_byte(system, address, u8(intermediate))
        case 0x4E: // absolute
            address := am_abs_address(cpu)
            value := am_abs(cpu)

            cpu.clock += 6
            cpu.pc += 3

            cpu.carry = value & 1 == 0 // Set carry flag to the value of the bit that is being shifted out

            intermediate = u16(value) >> 1
            system_write_byte(system, address, u8(intermediate))
        case 0x5E: // absolute, x
            address := am_abs_address(cpu)
            value := am_absx(cpu, false)

            cpu.clock += 7
            cpu.pc += 3

            cpu.carry = value & 1 == 0 // Set carry flag to the value of the bit that is being shifted out

            intermediate = u16(value) >> 1
            system_write_byte(system, address, u8(intermediate))
        case:
            panic("Unknown opcode")
    }

    // Set flags
    cpu.negative = false
    cpu.zero = is_zero(u8(intermediate))
}

op_ror :: proc(using cpu: ^CPU, opcode: u8) {
    intermediate: u8
    switch opcode {
        case 0x6A: // accumulator
            cpu.clock += 2
            cpu.pc += 1

            value := cpu.a

            temp_carry := cpu.carry
            cpu.carry = value & 1 == 0 // Set carry flag to the value of the bit that is being shifted out

            intermediate = value >> 1
            if temp_carry {
                intermediate |= 0x80
            }
            cpu.a = intermediate
        case 0x66: // zero page
            address := u16(am_zp_address(cpu))
            value := am_zp(cpu)

            cpu.clock += 5
            cpu.pc += 2

            temp_carry := cpu.carry
            cpu.carry = value & 1 == 0 // Set carry flag to the value of the bit that is being shifted out

            intermediate = value >> 1
            if temp_carry {
                intermediate |= 0x80
            }
            system_write_byte(system, address, intermediate)
        case 0x76: // zero page, x
            address := u16(am_zp_address(cpu))
            value := am_zpx(cpu)

            cpu.clock += 6
            cpu.pc += 2

            temp_carry := cpu.carry
            cpu.carry = value & 1 == 0 // Set carry flag to the value of the bit that is being shifted out

            intermediate = value >> 1
            if temp_carry {
                intermediate |= 0x80
            }
            system_write_byte(system, address, intermediate)
        case 0x6E: // absolute
            address := am_abs_address(cpu)
            value := am_abs(cpu)

            cpu.clock += 6
            cpu.pc += 3

            temp_carry := cpu.carry
            cpu.carry = value & 1 == 0 // Set carry flag to the value of the bit that is being shifted out

            intermediate = value >> 1
            if temp_carry {
                intermediate |= 0x80
            }
            system_write_byte(system, address, intermediate)
        case 0x7E: // absolute, x
            address := am_abs_address(cpu)
            value := am_absx(cpu, false)

            cpu.clock += 7
            cpu.pc += 3

            temp_carry := cpu.carry
            cpu.carry = value & 1 == 0 // Set carry flag to the value of the bit that is being shifted out

            intermediate = value >> 1
            if temp_carry {
                intermediate |= 0x80
            }
            system_write_byte(system, address, intermediate)
        case:
            panic("Unknown opcode")
    }

    // Set flags
    cpu.negative = is_negative(u8(intermediate))
    cpu.zero = is_zero(u8(intermediate))
}

op_lda :: proc(using cpu: ^CPU, opcode: u8) {
    intermediate: u8 = 0
    switch opcode {
        case 0xA9: // immediate
            intermediate = am_imm(cpu)
            
            cpu.clock += 2
            cpu.pc += 2
        case 0xA5: // zero page
            intermediate = am_zp(cpu)
            
            cpu.clock += 3
            cpu.pc += 2
        case 0xB5: // zero page, x
            intermediate = am_zpx(cpu)
            
            cpu.clock += 4
            cpu.pc += 2        
        case 0xA1: // indirect zero page, x
            intermediate = am_izx(cpu)
            
            cpu.clock += 6
            cpu.pc += 2
        case 0xB1: // indirect zero page, y
            intermediate = am_izy(cpu, true)
            
            cpu.clock += 5
            cpu.pc += 2
        case 0xAD: // absolute
            intermediate = am_abs(cpu)
            
            cpu.clock += 4
            cpu.pc += 3
        case 0xBD: // absolute, x
            intermediate = am_absx(cpu, true)
            
            cpu.clock += 4
            cpu.pc += 3
        case 0xB9: // absolute, y
            intermediate = am_absy(cpu, true)
            
            cpu.clock += 4
            cpu.pc += 3
        case:
            panic("Unknown opcode")
    }

    // set flags
    cpu.negative = is_negative(intermediate)
    cpu.zero = is_zero(intermediate)

    cpu.a = intermediate
}

op_ldx :: proc(using cpu: ^CPU, opcode: u8) {
    intermediate: u8 = 0
    switch opcode {
        case 0xA2: // immediate
            intermediate = am_imm(cpu)
            
            cpu.clock += 2
            cpu.pc += 2
        case 0xA6: // zero page
            intermediate = am_zp(cpu)
            
            cpu.clock += 3
            cpu.pc += 2
        case 0xB6: // zero page, y
            intermediate = am_zpy(cpu)
            
            cpu.clock += 4
            cpu.pc += 2
        case 0xAE: // absolute
            intermediate = am_abs(cpu)
            
            cpu.clock += 4
            cpu.pc += 3
        case 0xBE: // absolute, y
            intermediate = am_absy(cpu, true)
            
            cpu.clock += 4
            cpu.pc += 3
        case:
                panic("Unknown opcode")
    }

    // set flags
    cpu.negative = is_negative(intermediate)
    cpu.zero = is_zero(intermediate)

    cpu.x = intermediate
}

op_ldy :: proc (using cpu: ^CPU, opcode: u8) {
    intermediate: u8 = 0
    switch opcode {
        case 0xA0: // immediate
            intermediate = am_imm(cpu)
            
            cpu.clock += 2
            cpu.pc += 2
        case 0xA4: // zero page
            intermediate = am_zp(cpu)
            
            cpu.clock += 3
            cpu.pc += 2
        case 0xB4: // zero page, x
            intermediate = am_zpx(cpu)
            
            cpu.clock += 4
            cpu.pc += 2
        case 0xAC: // absolute
            intermediate = am_abs(cpu)
            
            cpu.clock += 4
            cpu.pc += 3
        case 0xBC: // absolute, x
            intermediate = am_absx(cpu, true)
            
            cpu.clock += 4
            cpu.pc += 3
        case:
            panic("Unknown opcode")
    }

    // set flags
    cpu.negative = is_negative(intermediate)
    cpu.zero = is_zero(intermediate)

    cpu.y = intermediate
}

op_sta :: proc(using cpu: ^CPU, opcode: u8) {
    arg_address := pc + 1 // address of the opcode argument

    switch opcode {
        case 0x85: // zero page
            cpu.clock += 3
            cpu.pc += 2

            address := system_read_byte(system, arg_address)
            system_write_byte(system, u16(address), a)
        case 0x95: // zero page, x
            cpu.clock += 4
            cpu.pc += 2

            address := system_read_byte(system, arg_address) // Get the zero page address
            system_write_byte(system, u16(address + x), a)
        case 0x8D: // absolute
            cpu.clock += 4
            cpu.pc += 3

            address := system_read_word(system, arg_address)
            system_write_byte(system, address, a)
        case 0x9D: // absolute, x
            cpu.clock += 5
            cpu.pc += 3

            address := system_read_word(system, arg_address)
            system_write_byte(system, address + u16(x), a)
        case 0x99: // absolute, y
            cpu.clock += 5
            cpu.pc += 3

            address := system_read_word(system, arg_address)
            system_write_byte(system, address + u16(y), a)
        case 0x81: // indirect zero page, x
            cpu.clock += 6
            cpu.pc += 2

            zp_address := system_read_byte(system, arg_address)
            address := system_read_word(system, u16(zp_address + x)) // Get the address from the zero page address + x
            system_write_byte(system, address, a)
        case 0x91: // indirect zero page, y
            cpu.clock += 6
            cpu.pc += 2
            
            zp_address := system_read_byte(system, arg_address)
            address := system_read_word(system, u16(zp_address)) // Get the address from the zero page address
            system_write_byte(system, address + u16(y), a)
        case:
            panic("Unknown opcode")
    }
}

op_stx :: proc(using cpu: ^CPU, opcode: u8) {
    arg_address := pc + 1 // address of the opcode argument

    switch opcode {
        case 0x86: // zero page
            cpu.clock += 3
            cpu.pc += 2

            address := system_read_byte(system, arg_address)
            system_write_byte(system, u16(address), x)
        case 0x96: // zero page, y
            cpu.clock += 4
            cpu.pc += 2

            address := system_read_byte(system, arg_address) // Get the zero page address
            system_write_byte(system, u16(address + y), x)
        case 0x8E: // absolute
            cpu.clock += 4
            cpu.pc += 3

            address := system_read_word(system, arg_address)
            system_write_byte(system, address, x)
        case:
            panic("Unknown opcode")
    }
}

op_sty :: proc(using cpu: ^CPU, opcode: u8) {
    arg_address := pc + 1 // address of the opcode argument

    switch opcode {
        case 0x84: // zero page
            cpu.clock += 3
            cpu.pc += 2

            address := system_read_byte(system, arg_address)
            system_write_byte(system, u16(address), y)
        case 0x94: // zero page, x
            cpu.clock += 4
            cpu.pc += 2

            address := system_read_byte(system, arg_address) // Get the zero page address
            system_write_byte(system, u16(address + x), y)
        case 0x8C: // absolute
            cpu.clock += 4
            cpu.pc += 3

            address := system_read_word(system, arg_address)
            system_write_byte(system, address, y)
        case:
            panic("Unknown opcode")
    }
}

op_tax :: proc(using cpu: ^CPU) {
    cpu.clock += 2
    cpu.pc += 1

    // flags
    cpu.negative = a & 0x80 == 0x80
    cpu.zero = a == 0

    cpu.x = a
}

op_txa :: proc(using cpu: ^CPU) {
    cpu.clock += 2
    cpu.pc += 1

    // flags
    cpu.negative = x & 0x80 == 0x80
    cpu.zero = x == 0

    cpu.a = x
}

op_tay :: proc(using cpu: ^CPU) {
    cpu.clock += 2
    cpu.pc += 1

    // flags
    cpu.negative = a & 0x80 == 0x80
    cpu.zero = a == 0

    cpu.y = a
}

op_tya :: proc(using cpu: ^CPU) {
    cpu.clock += 2
    cpu.pc += 1

    // flags
    cpu.negative = y & 0x80 == 0x80
    cpu.zero = y == 0

    cpu.a = y
}

op_tsx :: proc(using cpu: ^CPU) {
    cpu.clock += 2
    cpu.pc += 1

    // flags
    cpu.negative = s & 0x80 == 0x80
    cpu.zero = s == 0

    cpu.x = s
}

// Loads the X register to the stack pointer
op_txs :: proc(using cpu: ^CPU) {
    cpu.clock += 2
    cpu.pc += 1

    cpu.s = x
}

op_pla :: proc(using cpu: ^CPU) {
    cpu.clock += 4
    cpu.pc += 1
    
    cpu.s += 1

    s_address := system_read_byte(system, STACK_START_ADDR + u16(cpu.s))
    intermediate := system_read_byte(system, u16(s_address))

    // flags
    cpu.negative = intermediate & 0x80 == 0x80
    cpu.zero = intermediate == 0

    cpu.a = intermediate
}

op_pha :: proc(using cpu: ^CPU) {
    cpu.clock += 3
    cpu.pc += 1

    system_write_byte(system, STACK_START_ADDR + u16(cpu.s), a)
    cpu.s -= 1
}

_pull_status_register :: proc(using cpu: ^CPU) {
    status_register_byte: byte
    status_register_byte = _pull_byte_from_stack(cpu)

    // flags
    cpu.carry     = status_register_byte & 0x01 == 0x01
    cpu.zero      = status_register_byte & 0x02 == 0x02
    cpu.interrupt = status_register_byte & 0x04 == 0x04
    cpu.decimal   = status_register_byte & 0x08 == 0x08
    cpu.overflow  = status_register_byte & 0x40 == 0x40
    cpu.negative  = status_register_byte & 0x80 == 0x80
}

_pull_byte_from_stack :: proc(using cpu: ^CPU) -> u8 {
    cpu.s += 1
    value := system_read_byte(system, STACK_START_ADDR + u16(cpu.s))

    return value
}

_pull_word_from_stack :: proc(using cpu: ^CPU) -> u16 {
    cpu.s += 1
    value := system_read_word(system, STACK_START_ADDR + u16(cpu.s))
    cpu.s += 1

    return value
}

op_plp :: proc(using cpu: ^CPU) {
    cpu.clock += 4
    cpu.pc += 1

    _pull_status_register(cpu)
}

_push_byte_to_stack :: proc(using cpu: ^CPU, value: u8) {
    system_write_byte(system, STACK_START_ADDR + u16(cpu.s), value)
    cpu.s -= 1
}

_push_word_to_stack :: proc(using cpu: ^CPU, value: u16) {
    _push_byte_to_stack(cpu, cast(u8)(value >> 8))
    _push_byte_to_stack(cpu, cast(u8)(value & 0xFF))
}

_push_status_register :: proc(using cpu: ^CPU) {
    status_register_byte: u8 = 0

    status_register_byte |= 0x01 if cpu.carry      else 0
    status_register_byte |= 0x02 if cpu.zero       else 0
    status_register_byte |= 0x04 if cpu.interrupt  else 0
    status_register_byte |= 0x08 if cpu.decimal    else 0
    status_register_byte |= 0x10 if cpu.break_flag else 0
    status_register_byte |= 0x20 // unused, always 1
    status_register_byte |= 0x40 if cpu.overflow   else 0
    status_register_byte |= 0x80 if cpu.negative   else 0

    _push_byte_to_stack(cpu, status_register_byte)
}

op_php :: proc(using cpu: ^CPU) {
    cpu.clock += 3
    cpu.pc += 1

    _push_status_register(cpu)
}

_calculate_address_for_jump :: proc(address: u16, offset: i8) -> u16 {
    if offset < 0 {
        return address - cast(u16)math.abs(offset)
    } else {
        return address + cast(u16)offset
    }
}

// TODO: test this
_take_branch :: proc(using cpu: ^CPU, arg_address: u16) {
    cpu.clock += 1 // penalty for taking the branch

    offset := cast(i8)system_read_byte(system, arg_address) // signed offset

    new_address := _calculate_address_for_jump(arg_address + 1, offset)
    if _is_page_boundary_crossed(arg_address + 1, new_address) {
        cpu.clock += 1 // penalty for crossing a page boundary
    }

    cpu.pc = new_address
}

// TODO: test this
// Branch if plus
op_bpl :: proc(using cpu: ^CPU) {
    arg_address := pc + 1 // address of the opcode argument

    cpu.clock += 2

    if !cpu.negative {
        _take_branch(cpu, arg_address)
    } else {
        cpu.pc += 2
    }
}

// TODO: test this
// Branch if minus
op_bmi :: proc(using cpu: ^CPU) {
    arg_address := pc + 1 // address of the opcode argument

    if cpu.negative {
        _take_branch(cpu, arg_address)
    } else {
        cpu.pc += 2
    }
}

// Branch if overflow clear
op_bvc :: proc(using cpu: ^CPU) {
    arg_address := pc + 1 // address of the opcode argument

    if !cpu.overflow {
        _take_branch(cpu, arg_address)
    } else {
        cpu.pc += 2
    }
}

// Branch if overflow set
op_bvs :: proc(using cpu: ^CPU) {
    arg_address := pc + 1 // address of the opcode argument

    if cpu.overflow {
        _take_branch(cpu, arg_address)
    } else {
        cpu.pc += 2
    }
}

// Branch if carry clear
op_bcc :: proc(using cpu: ^CPU) {
    arg_address := pc + 1 // address of the opcode argument

    if !cpu.carry {
        _take_branch(cpu, arg_address)
    } else {
        cpu.pc += 2
    }
}

// TODO: test this
// Branch if carry set
op_bcs :: proc(using cpu: ^CPU) {
    arg_address := pc + 1 // address of the opcode argument

    if cpu.carry {
        _take_branch(cpu, arg_address)
    } else {
        cpu.pc += 2
    }
}

// TODO: test this
// Branch if not equal
op_bne :: proc(using cpu: ^CPU) {
    arg_address := pc + 1 // address of the opcode argument

    if !cpu.zero {
        _take_branch(cpu, arg_address)
    } else {
        cpu.pc += 2
    }
}

// TODO: test this
// Branch if equal
op_beq :: proc(using cpu: ^CPU) {
    arg_address := pc + 1 // address of the opcode argument

    if cpu.zero {
        _take_branch(cpu, arg_address)
    } else {
        cpu.pc += 2
    }
}

// TODO: test this
// Break
op_brk :: proc(using cpu: ^CPU) {
    cpu.clock += 7

    // Push the PC to the stack
    _push_word_to_stack(cpu, cpu.pc)

    _push_status_register(cpu)

    cpu.pc = system_read_word(system, IRQ_VECTOR_ADDR)

    // set the break flag
    cpu.break_flag = true
    cpu.interrupt = true
}

// Return from interrupt
op_rti :: proc(using cpu: ^CPU) {
    cpu.clock += 6

    // [| |P|PC1|PC2|X|X|X|]
    //  s^
    // Read the status register from the stack
    // [| |P|PC1|PC2|X|X|X|]
    //    s^
    // Read the PC from the stack
    // [| |P|PC1|PC2|X|X|X|]
    //       s^
    // Increment the stack pointer
    // [| |P|PC1|PC2|X|X|X|]
    //           s^
    // We have to point to the first free byte on the stack

    _pull_status_register(cpu)
    cpu.pc = _pull_word_from_stack(cpu)
}


// Jump to subroutine
op_jsr :: proc(using cpu: ^CPU) {
    arg_address := pc + 1 // address of the opcode argument

    cpu.clock += 6

    // Push the PC + 2 (the next operation) to the stack
    _push_word_to_stack(cpu, cpu.pc + 2)

    // Jump to the address, absolute addressing mode
    cpu.pc = system_read_word(system, arg_address)
}

// Return from subroutine
op_rts :: proc(using cpu: ^CPU) {
    cpu.clock += 6

    // Read the PC from the stack
    cpu.pc = _pull_word_from_stack(cpu)
}

// Jump
op_jmp :: proc(using cpu: ^CPU, opcode: u8) {
    switch opcode {
        case 0x4C: // JMP absolute
            arg_address := pc + 1 // address of the opcode argument
            cpu.pc = system_read_word(system, arg_address)
            cpu.clock += 3
        case 0x6C: // JMP indirect
            arg_address := pc + 1 // address of the opcode argument
            indirect_address := system_read_word(system, arg_address)
            cpu.pc = system_read_word(system, indirect_address)
            cpu.clock += 5
        case:
            panic("Unknown opcode")
    }

    cpu.pc += 3
}

// Test bits in memory with accumulator
op_bit :: proc(using cpu: ^CPU, opcode: u8) {
    arg_address := pc + 1 // address of the opcode argument
    value: u8

    switch opcode {
        case 0x24: // Zero page
            address := system_read_byte(system, arg_address)
            value = system_read_byte(system, cast(u16)address)

            cpu.clock += 3
            cpu.pc += 2
        case 0x2C: // Absolute
            address := system_read_word(system, arg_address)
            value = system_read_byte(system, address)

            cpu.clock += 4
            cpu.pc += 3
        case:
            panic("Unknown opcode")
    }

    // Set flags
    cpu.negative = (value & 0x80) != 0 // set the negative flag to the 7th bit of the memory
    cpu.overflow = (value & 0x40) != 0 // set the overflow flag to the 6th bit of the memory
    cpu.zero     = (value & a)    == 0 // set the zero flag to the result of the AND operation between the accumulator and the memory
}


// Reset the carry flag
op_clc :: proc(using cpu: ^CPU) {
    cpu.carry = false

    cpu.clock += 2
    cpu.pc += 1
}

// Set the carry flag
op_sec :: proc(using cpu: ^CPU) {
    cpu.carry = true

    cpu.clock += 2
    cpu.pc += 1
}

// Clear decimal mode
op_cld :: proc(using cpu: ^CPU) {
    cpu.decimal = false

    cpu.clock += 2
    cpu.pc += 1
}

// Set decimal mode
op_sed :: proc(using cpu: ^CPU) {
    cpu.decimal = true

    cpu.clock += 2
    cpu.pc += 1
}

// Clear interrupt disable
op_cli :: proc(using cpu: ^CPU) {
    cpu.interrupt = false

    cpu.clock += 2
    cpu.pc += 1
}

// Set interrupt disable
op_sei :: proc(using cpu: ^CPU) {
    cpu.interrupt = true

    cpu.clock += 2
    cpu.pc += 1
}

// Clear overflow flag
op_clv :: proc(using cpu: ^CPU) {
    cpu.overflow = false

    cpu.clock += 2
    cpu.pc += 1
}

// No operation
op_nop :: proc(using cpu: ^CPU) {
    cpu.clock += 2
    cpu.pc += 1
}