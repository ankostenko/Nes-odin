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
    fmt.printf("a: %X, x: %X, y: %X, s: %X, pc: %X, clock: %d | flags: ", a, x, y, s, pc, clock)
    
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
    fmt.println()
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

op_sta :: proc(using cpu: CPU, opcode: u8) -> CPU {
    cpu := cpu

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

    return cpu
}

op_stx :: proc(using cpu: CPU, opcode: u8) -> CPU {
    cpu := cpu

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

    return cpu
}

op_sty :: proc(using cpu: CPU, opcode: u8) -> CPU {
    cpu := cpu

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

    return cpu
}

op_tax :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.clock += 2
    cpu.pc += 1

    // flags
    cpu.negative = a & 0x80 == 0x80
    cpu.zero = a == 0

    cpu.x = a

    return cpu
}

op_txa :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.clock += 2
    cpu.pc += 1

    // flags
    cpu.negative = x & 0x80 == 0x80
    cpu.zero = x == 0

    cpu.a = x

    return cpu
}

op_tay :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.clock += 2
    cpu.pc += 1

    // flags
    cpu.negative = a & 0x80 == 0x80
    cpu.zero = a == 0

    cpu.y = a

    return cpu
}

op_tya :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.clock += 2
    cpu.pc += 1

    // flags
    cpu.negative = y & 0x80 == 0x80
    cpu.zero = y == 0

    cpu.a = y

    return cpu
}

op_tsx :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.clock += 2
    cpu.pc += 1

    // flags
    cpu.negative = s & 0x80 == 0x80
    cpu.zero = s == 0

    cpu.x = s

    return cpu
}

op_txs :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.clock += 2
    cpu.pc += 1

    cpu.s = x

    return cpu
}

op_pla :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.clock += 4
    cpu.pc += 1
    
    cpu.s += 1

    s_address := system_read_byte(system, STACK_START_ADDR + u16(cpu.s))
    intermediate := system_read_byte(system, u16(s_address))

    // flags
    cpu.negative = intermediate & 0x80 == 0x80
    cpu.zero = intermediate == 0

    cpu.a = intermediate

    return cpu
}

op_pha :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.clock += 3
    cpu.pc += 1

    system_write_byte(system, STACK_START_ADDR + u16(cpu.s), a)
    cpu.s -= 1

    return cpu
}

_pull_status_register :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    status_register_byte: byte
    status_register_byte, cpu = _pull_byte_from_stack(cpu)

    // flags
    cpu.carry     = status_register_byte & 0x01 == 0x01
    cpu.zero      = status_register_byte & 0x02 == 0x02
    cpu.interrupt = status_register_byte & 0x04 == 0x04
    cpu.decimal   = status_register_byte & 0x08 == 0x08
    cpu.overflow  = status_register_byte & 0x40 == 0x40
    cpu.negative  = status_register_byte & 0x80 == 0x80

    return cpu
}

_pull_byte_from_stack :: proc(using cpu: CPU) -> (u8, CPU) {
    cpu := cpu

    cpu.s += 1
    value := system_read_byte(system, STACK_START_ADDR + u16(cpu.s))

    return value, cpu
}

_pull_word_from_stack :: proc(using cpu: CPU) -> (u16, CPU) {
    cpu := cpu

    cpu.s += 1
    value := system_read_word(system, STACK_START_ADDR + u16(cpu.s))
    cpu.s += 1

    return value, cpu
}

op_plp :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.clock += 4
    cpu.pc += 1

    cpu = _pull_status_register(cpu)

    return cpu
}

_push_byte_to_stack :: proc(using cpu: CPU, value: u8) -> CPU {
    cpu := cpu

    system_write_byte(system, STACK_START_ADDR + u16(cpu.s), value)
    cpu.s -= 1

    return cpu
}

_push_word_to_stack :: proc(using cpu: CPU, value: u16) -> CPU {
    cpu := cpu

    cpu = _push_byte_to_stack(cpu, cast(u8)(value >> 8))
    cpu = _push_byte_to_stack(cpu, cast(u8)(value & 0xFF))

    return cpu
}

_push_status_register :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    status_register_byte: u8 = 0

    status_register_byte |= 0x01 if cpu.carry      else 0
    status_register_byte |= 0x02 if cpu.zero       else 0
    status_register_byte |= 0x04 if cpu.interrupt  else 0
    status_register_byte |= 0x08 if cpu.decimal    else 0
    status_register_byte |= 0x10 if cpu.break_flag else 0
    status_register_byte |= 0x20 // unused, always 1
    status_register_byte |= 0x40 if cpu.overflow   else 0
    status_register_byte |= 0x80 if cpu.negative   else 0

    cpu = _push_byte_to_stack(cpu, status_register_byte)

    return cpu
}

op_php :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.clock += 3
    cpu.pc += 1

    cpu = _push_status_register(cpu)

    return cpu
}

_calculate_address_for_jump :: proc(address: u16, offset: i8) -> u16 {
    if offset < 0 {
        return address - cast(u16)math.abs(offset)
    } else {
        return address + cast(u16)offset
    }
}

// TODO: test this
_take_branch :: proc(using cpu: CPU, arg_address: u16) -> CPU {
    cpu := cpu

    cpu.clock += 1 // penalty for taking the branch

    offset := cast(i8)system_read_byte(system, arg_address) // signed offset

    new_address := _calculate_address_for_jump(pc, offset)
    if _is_page_boundary_crossed(pc, new_address) {
        cpu.clock += 1 // penalty for crossing a page boundary
    }

    cpu.pc = new_address

    return cpu
}

// TODO: test this
op_bpl :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    arg_address := pc + 1 // address of the opcode argument

    cpu.clock += 2

    if !cpu.negative {
        cpu = _take_branch(cpu, arg_address)
    } else {
        cpu.pc += 2
    }
    return cpu
}

// TODO: test this
op_bmi :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    arg_address := pc + 1 // address of the opcode argument

    if cpu.negative {
        cpu = _take_branch(cpu, arg_address)
    } else {
        cpu.pc += 2
    }

    return cpu
}

op_bvc :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    arg_address := pc + 1 // address of the opcode argument

    if !cpu.overflow {
        cpu = _take_branch(cpu, arg_address)
    } else {
        cpu.pc += 2
    }

    return cpu
}

op_bvs :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    arg_address := pc + 1 // address of the opcode argument

    if cpu.overflow {
        cpu = _take_branch(cpu, arg_address)
    } else {
        cpu.pc += 2
    }

    return cpu
}

op_bcc :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    arg_address := pc + 1 // address of the opcode argument

    if !cpu.carry {
        cpu = _take_branch(cpu, arg_address)
    } else {
        cpu.pc += 2
    }

    return cpu
}

// TODO: test this
op_bcs :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    arg_address := pc + 1 // address of the opcode argument

    if cpu.carry {
        cpu = _take_branch(cpu, arg_address)
    } else {
        cpu.pc += 2
    }

    return cpu
}

// TODO: test this
op_bne :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    arg_address := pc + 1 // address of the opcode argument

    if !cpu.zero {
        cpu = _take_branch(cpu, arg_address)
    } else {
        cpu.pc += 2
    }

    return cpu
}

// TODO: test this
op_beq :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    arg_address := pc + 1 // address of the opcode argument

    if cpu.zero {
        cpu = _take_branch(cpu, arg_address)
    } else {
        cpu.pc += 2
    }

    return cpu
}

// TODO: test this
op_brk :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.clock += 7

    // Push the PC to the stack
    cpu = _push_word_to_stack(cpu, cpu.pc)

    cpu = _push_status_register(cpu)

    cpu.pc = system_read_word(system, IRQ_VECTOR_ADDR)

    // set the break flag
    cpu.break_flag = true
    cpu.interrupt = true

    return cpu
}

op_rti :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

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

    cpu = _pull_status_register(cpu)
    pulled_pc: u16
    pulled_pc, cpu = _pull_word_from_stack(cpu)
    cpu.pc = pulled_pc

    return cpu
}

op_jsr :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    arg_address := pc + 1 // address of the opcode argument

    cpu.clock += 6

    // Push the PC + 2 (the next operation) to the stack
    cpu = _push_word_to_stack(cpu, cpu.pc + 2)

    // Jump to the address, absolute addressing mode
    cpu.pc = system_read_word(system, arg_address)

    return cpu
}

op_rts :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.clock += 6

    // Read the PC from the stack
    pulled_pc: u16
    pulled_pc, cpu = _pull_word_from_stack(cpu)
    cpu.pc = pulled_pc

    return cpu
}

op_jmp :: proc(using cpu: CPU, opcode: u8) -> CPU {
    cpu := cpu

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
    
    return cpu
}

op_bit :: proc(using cpu: CPU, opcode: u8) -> CPU {
    cpu := cpu
    
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

    return cpu
}


// Reset the carry flag
op_clc :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.carry = false

    cpu.clock += 2
    cpu.pc += 1

    return cpu
}

op_sec :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.carry = true

    cpu.clock += 2
    cpu.pc += 1

    return cpu
}

op_cld :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.decimal = false

    cpu.clock += 2
    cpu.pc += 1

    return cpu
}

op_sed :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.decimal = true

    cpu.clock += 2
    cpu.pc += 1

    return cpu
}

op_cli :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.interrupt = false

    cpu.clock += 2
    cpu.pc += 1

    return cpu
}

op_sei :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.interrupt = true

    cpu.clock += 2
    cpu.pc += 1

    return cpu
}

op_clv :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.overflow = false

    cpu.clock += 2
    cpu.pc += 1

    return cpu
}

op_nop :: proc(using cpu: CPU) -> CPU {
    cpu := cpu

    cpu.clock += 2
    cpu.pc += 1

    return cpu
}