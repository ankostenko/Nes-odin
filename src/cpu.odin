package main

// Reset vector is hardwired to 0xfffc-0xfffd
RESET_VECTOR_ADDR :: 0xfffc

// Size of this structure is 80 bytes
CPU :: struct {
    a: u8 // accumulator 
    x: u8 // index register x
    y: u8 // index register y
    s: u8 // stack pointer
    pc: u16 // program counter
    carry: bool // carry flag
    zero: bool // zero flag
    interrupt: bool // interrupt flag
    decimal: bool // decimal flag
    overflow: bool // overflow flag
    negative: bool // negative flag
    system: System // system
    clock: u64 // clock cycles
}

init_cpu :: proc(system: System) -> CPU {
    reset_vector := system_read_word(system, RESET_VECTOR_ADDR)
    return CPU {
        carry=false
        zero=false
        interrupt=true
        decimal=false
        overflow=false
        negative=false
        a=0
        x=0
        y=0
        s=0xfd // stack pointer starts at 0xfd
        pc=reset_vector
        system=system
        clock=0
    }
}

op_lda :: proc(using cpu: CPU, operand: u8) -> CPU {
    cpu := cpu
    
    intermidiate: u8 = 0
    switch operand {
        case 0xA9: // immediate
            intermidiate = system_read_byte(system, pc + 1)
            cpu.clock += 2
        case:
            panic("Unknown opcode")
    }

    // set flags
    cpu.negative = intermidiate & 0x80 == 0x80
    cpu.zero = intermidiate == 0

    cpu.a = intermidiate

    return cpu
}