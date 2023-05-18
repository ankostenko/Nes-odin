package main

import "core:fmt"
import "core:reflect"
import "core:strings"

// Reset vector is hardwired to 0xfffc-0xfffd
RESET_VECTOR_ADDR :: 0xfffc

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

_is_page_boundary_crossed :: proc(address: u16, offset: u8) -> bool {
    return (address & 0xff00) != ((address + u16(offset)) & 0xff00)
}

op_lda :: proc(using cpu: CPU, opcode: u8) -> CPU {
    cpu := cpu

    intermediate: u8 = 0
    arg_address := pc + 1 // address of the opcode argument
    switch opcode {
        case 0xA9: // immediate
            cpu.clock += 2
            cpu.pc += 2
            
            intermediate = system_read_byte(system, arg_address)
        case 0xA5: // zero page
            cpu.clock += 3
            cpu.pc += 2
            
            address := system_read_byte(system, arg_address)
            intermediate = system_read_byte(system, u16(address))
        case 0xB5: // zero page, x
            cpu.clock += 4
            cpu.pc += 2
            
            address := system_read_byte(system, arg_address)
            intermediate = system_read_byte(system, u16(address + x))
        case 0xA1: // indirect zero page, x
            cpu.clock += 6
            cpu.pc += 2

            address := u16(system_read_byte(system, arg_address) + x)
            new_address := system_read_word(system, address)

            intermediate = system_read_byte(system, new_address)
        case 0xB1: // indirect zero page, y
            cpu.clock += 5
            cpu.pc += 2

            address := system_read_byte(system, arg_address)
            new_address := system_read_word(system, u16(address + y))

            if _is_page_boundary_crossed(new_address, y) {
                cpu.clock += 1
            }

            intermediate = system_read_byte(system, new_address)
        case 0xAD: // absolute
            cpu.clock += 4
            cpu.pc += 3

            address := system_read_word(system, arg_address)
            intermediate = system_read_byte(system, address)
        case 0xBD: // absolute, x
            cpu.clock += 4
            cpu.pc += 3

            address := system_read_word(system, arg_address)

            if _is_page_boundary_crossed(address, x) {
                cpu.clock += 1
            }

            intermediate = system_read_byte(system, address + u16(x))
        case 0xB9: // absolute, y
            cpu.clock += 4
            cpu.pc += 3

            address := system_read_word(system, arg_address)
            
            if _is_page_boundary_crossed(address, y) {
                cpu.clock += 1
            }

            intermediate = system_read_byte(system, address + u16(y))
        case:
            panic("Unknown opcode")
    }

    // set flags
    cpu.negative = intermediate & 0x80 == 0x80
    cpu.zero = intermediate == 0

    cpu.a = intermediate

    return cpu
}

op_ldx :: proc(using cpu: CPU, opcode: u8) -> CPU {
    cpu := cpu

    intermediate: u8 = 0
    arg_address := pc + 1 // address of the opcode argument
    switch opcode {
        case 0xA2: // immediate
            cpu.clock += 2
            cpu.pc += 2
            
            intermediate = system_read_byte(system, arg_address)
        case 0xA6: // zero page
            cpu.clock += 3
            cpu.pc += 2

            address := system_read_byte(system, arg_address)
            intermediate = system_read_byte(system, u16(address))
        case 0xB6: // zero page, y
            cpu.clock += 4
            cpu.pc += 2

            address := system_read_byte(system, arg_address)
            intermediate = system_read_byte(system, u16(address + y))
        case 0xAE: // absolute
            cpu.clock += 4
            cpu.pc += 3

            address := system_read_word(system, arg_address)
            intermediate = system_read_byte(system, address)
        case 0xBE: // absolute, y
            cpu.clock += 4
            cpu.pc += 3

            address := system_read_word(system, arg_address)

            if _is_page_boundary_crossed(address, y) {
                cpu.clock += 1
            }

            intermediate = system_read_byte(system, address + u16(y))
        case:
                panic("Unknown opcode")
    }

    // set flags
    cpu.negative = intermediate & 0x80 == 0x80
    cpu.zero = intermediate == 0

    cpu.x = intermediate

    return cpu
}

op_ldy :: proc (using cpu: CPU, opcode: u8) -> CPU {
    cpu := cpu

    intermediate: u8 = 0
    arg_address := pc + 1 // address of the opcode argument
    switch opcode {
        case 0xA0: // immediate
            cpu.clock += 2
            cpu.pc += 2
            
            intermediate = system_read_byte(system, arg_address)
        case 0xA4: // zero page
            cpu.clock += 3
            cpu.pc += 2

            address := system_read_byte(system, arg_address)
            intermediate = system_read_byte(system, u16(address))
        case 0xB4: // zero page, x
            cpu.clock += 4
            cpu.pc += 2

            address := system_read_byte(system, arg_address)
            intermediate = system_read_byte(system, u16(address + x))
        case 0xAC: // absolute
            cpu.clock += 4
            cpu.pc += 3

            address := system_read_word(system, arg_address)
            intermediate = system_read_byte(system, address)
        case 0xBC: // absolute, x
            cpu.clock += 4
            cpu.pc += 3

            address := system_read_word(system, arg_address)

            if _is_page_boundary_crossed(address, x) {
                cpu.clock += 1
            }

            intermediate = system_read_byte(system, address + u16(x))
        case:
                panic("Unknown opcode")
    }

    // set flags
    cpu.negative = intermediate & 0x80 == 0x80
    cpu.zero = intermediate == 0

    cpu.y = intermediate

    return cpu
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