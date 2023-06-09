package core

PPU :: struct {
    clock: u64
    in_vblank: bool
}

init_ppu :: proc() -> PPU {
    return PPU{
        clock=0,
        in_vblank=false
    }
}

ppu_tick :: proc(using ppu: ^PPU, cycles: u64) {
    ppu.clock += cycles

    clock_in_current_frame := clock % (341 * 262)
    if clock_in_current_frame > (341 * 241) && !in_vblank {
        ppu.in_vblank = true
    } else if clock_in_current_frame <= (341 * 241) && in_vblank {
        ppu.in_vblank = false
    }
}

read_ppu_address :: proc(using ppu: ^PPU, address: u16) -> u8 {
    status: u8

    if in_vblank {
        status |= 0x80
    }

    ppu.in_vblank = false

    return status
}

write_ppu_address :: proc(using ppu: PPU, address: u16, value: u8) {
    return
}
