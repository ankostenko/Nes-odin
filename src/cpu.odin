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

op_lda :: proc(using cpu: CPU, operand: u8) -> CPU {
    cpu := cpu
    
    _is_page_boundary_crossed := proc(address: u16, offset: u8) -> bool {
        return (address & 0xff00) != ((address + u16(offset)) & 0xff00)
    }

    intermidiate: u8 = 0
    switch operand {
        case 0xA9: // immediate
            cpu.clock += 2
            
            intermidiate = system_read_byte(system, pc + 1)

            cpu.pc += 2
        case 0xA5: // zero page
            cpu.clock += 3
            
            address := system_read_byte(system, pc + 1)
            intermidiate = system_read_byte(system, u16(address))

            cpu.pc += 2
        case 0xB5: // zero page, x
            cpu.clock += 4
            
            address := system_read_byte(system, pc + 1)
            intermidiate = system_read_byte(system, u16(address + x))

            cpu.pc += 2
        case 0xA1: // indirect zero page, x
            cpu.clock += 6

            address := u16(system_read_byte(system, pc + 1) + x)
            new_address := system_read_word(system, address)

            intermidiate = system_read_byte(system, new_address)

            cpu.pc += 2
        case 0xB1: // indirect zero page, y
            cpu.clock += 5

            address := system_read_byte(system, pc + 1)
            new_address := system_read_word(system, u16(address + y))

            if _is_page_boundary_crossed(new_address, y) {
                cpu.clock += 1
            }

            intermidiate = system_read_byte(system, new_address)

            cpu.pc += 2
        case 0xAD: // absolute
            cpu.clock += 4

            address := system_read_word(system, pc + 1)
            intermidiate = system_read_byte(system, address)

            cpu.pc += 3
        case 0xBD: // absolute, x
            cpu.clock += 4

            address := system_read_word(system, pc + 1)

            if _is_page_boundary_crossed(address, x) {
                cpu.clock += 1
            }

            intermidiate = system_read_byte(system, address + u16(x))

            cpu.pc += 3
        case 0xB9: // absolute, y
            cpu.clock += 4

            address := system_read_word(system, pc + 1)
            
            if _is_page_boundary_crossed(address, y) {
                cpu.clock += 1
            }

            intermidiate = system_read_byte(system, address + u16(y))

            cpu.pc += 3
        case:
            panic("Unknown opcode")
    }

    // set flags
    cpu.negative = intermidiate & 0x80 == 0x80
    cpu.zero = intermidiate == 0

    cpu.a = intermidiate

    return cpu
}