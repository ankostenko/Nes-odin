package core

import "core:os"

// Result size is 56 bytes
System :: struct {
    scratch_ram: []u8
    ppu: PPU
    apu: APU
    cart: Cart
}

init_system :: proc() -> System {
    // Load ROM data
    rom_bytes, err := load_rom_data(os.args[1])
    if err != .None {
        return {}
    }

    // Read ROM and return cart
    cart_instance := read_rom(rom_bytes)

    return System{
        scratch_ram=make([]u8, 0x800),
        ppu=init_ppu(),
        apu=init_apu(),
        cart=cart_instance,
    }
}

mapper_read_byte :: proc(using system: System, address: u16) -> byte {
    if address >= 0x8000 && address <= 0xBFFF { // PRG-ROM bank 0
        return cart.prg_rom_pages[0][address - 0x8000]
    } else if address >= 0xC000 && address <= 0xFFFF {
        return cart.prg_rom_pages[cart.pgr_rom - 1][address - 0xC000]
    } else {
        panic("Invalid mapper read address")
    }
}

mapper_write_byte :: proc(using system: System, address: u16, value: u8) {
}

system_read_word :: proc(using system: System, address: u16) -> u16 {
    return (cast(u16)system_read_byte(system, address)) | ((cast(u16)system_read_byte(system, address + 1)) << 8)
}

system_read_byte :: proc(using system: System, address: u16) -> byte {
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

system_write_byte :: proc(using system: System, address: u16, value: u8) {
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