package main

System :: struct {
    scratch_ram: []u8
    ppu: PPU
    apu: APU
}

init_system :: proc() -> System {
    return System{
        scratch_ram=make([]u8, 0x800),
        ppu=init_ppu(),
        apu=init_apu(),
    }
}

mapper_read_byte :: proc(using system: System, address: u16) -> byte {
    return 0
}

mapper_write_byte :: proc(using system: System, address: u16, value: u8) {
}

read_byte :: proc(using system: System, address: u16) -> byte {
    // We're in the scratch RAM
    if address < 0x2000 {
        // Up until 0x7FF, it's mirrored every 0x800 bytes (0x800, 0x1000, etc). 
        // So writing to 0x800 is the same as writing to 0x0, 0x801 is the same as 0x1, etc.
        return scratch_ram[address & 0x7FF]
    } else if address < 0x4000 {
        // PPU registers
        return read_ppu_address(ppu, address)
    } else if address < 0x4020 {
        // APU registers
        return read_apu_address(apu, address)
    } else {
        // Mapper
        return mapper_read_byte(system, address)
    }
    return 0
}

write_byte :: proc(using system: System, address: u16, value: u8) {
    // We're in the scratch RAM
    if address < 0x2000 {
        scratch_ram[address & 0x7FF] = value
    } else if address < 0x4000 {
        // PPU registers
        write_ppu_address(ppu, address, value)
    } else if address < 0x4020 {
        // APU registers
        write_apu_address(apu, address, value)
    } else {
        // Mapper
        mapper_write_byte(system, address, value)
    }
}