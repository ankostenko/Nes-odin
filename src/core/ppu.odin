package core

PPU :: struct {
    clock: u64
    in_vblank: bool
    base_table_address: u16
    vram_address_inc: u16
    sprite_pattern_table_address: u16
    background_pattern_table_address: u16
    sprite_size_8x8: bool
    master_slave_select: enum {
        READ_BACKDROP_FROM_EXT_PINS,
        OUTPUT_COLOR_ON_EXT_PINS
    }
    nmi_on_vblank: bool
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

// 7  bit  0
// ---- ----
// VSO. ....
// |||| ||||
// |||+-++++- PPU open bus. Returns stale PPU bus contents.
// ||+------- Sprite overflow. The intent was for this flag to be set
// ||         whenever more than eight sprites appear on a scanline, but a
// ||         hardware bug causes the actual behavior to be more complicated
// ||         and generate false positives as well as false negatives; see
// ||         PPU sprite evaluation. This flag is set during sprite
// ||         evaluation and cleared at dot 1 (the second dot) of the
// ||         pre-render line.
// |+-------- Sprite 0 Hit.  Set when a nonzero pixel of sprite 0 overlaps
// |          a nonzero background pixel; cleared at dot 1 of the pre-render
// |          line.  Used for raster timing.
// +--------- Vertical blank has started (0: not in vblank; 1: in vblank).
//            Set at dot 1 of line 241 (the line *after* the post-render
//            line); cleared after reading $2002 and at dot 1 of the
//            pre-render line.
ppu_status :: proc(using ppu: ^PPU) -> u8 {
    status: u8

    if in_vblank {
        status |= 0x80
    }

    ppu.in_vblank = false

    return status
}

// 7  bit  0
// ---- ----
// VPHB SINN
// |||| ||||
// |||| ||++- Base nametable address
// |||| ||    (0 = $2000; 1 = $2400; 2 = $2800; 3 = $2C00)
// |||| |+--- VRAM address increment per CPU read/write of PPUDATA
// |||| |     (0: add 1, going across; 1: add 32, going down)
// |||| +---- Sprite pattern table address for 8x8 sprites
// ||||       (0: $0000; 1: $1000; ignored in 8x16 mode)
// |||+------ Background pattern table address (0: $0000; 1: $1000)
// ||+------- Sprite size (0: 8x8 pixels; 1: 8x16 pixels – see PPU OAM#Byte 1)
// |+-------- PPU master/slave select
// |          (0: read backdrop from EXT pins; 1: output color on EXT pins)
// +--------- Generate an NMI at the start of the
//            vertical blanking interval (0: off; 1: on)
ppu_ctrl :: proc(using ppu: ^PPU, value: u8) {
    // Set base table address based on bit 0 and 1 of value
    switch value & 0x3 {
        case 0:
            base_table_address = 0x2000
        case 1:
            base_table_address = 0x2400
        case 2:
            base_table_address = 0x2800
        case 3:
            base_table_address = 0x2C00
    }

    // Set VRAM address increment based on bit 2 of value
    switch value & 0x4 {
        case 0:
            // Add 1, going across
            vram_address_inc = 1
        case 1:
            // Add 32, going down
            vram_address_inc = 32
    }

    switch value & 0x8 {
        case 0:
            // Sprite pattern table address for 8x8 sprites
            sprite_pattern_table_address = 0x0000
        case 1:
            // Sprite pattern table address for 8x16 sprites
            sprite_pattern_table_address = 0x1000
    }

    switch value & 0x10 {
        case 0:
            // Background pattern table address
            background_pattern_table_address = 0x0000
        case 1:
            // Background pattern table address
            background_pattern_table_address = 0x1000
    }

    switch value & 0x20 {
        case 0:
            // Sprite size 8x8
            sprite_size_8x8 = true
        case 1:
            // Sprite size 8x16
            sprite_size_8x8 = false
    }

    switch value & 0x40 {
        case 0:
            // PPU master/slave select
            master_slave_select = .READ_BACKDROP_FROM_EXT_PINS
        case 1:
            // PPU master/slave select
            master_slave_select = .OUTPUT_COLOR_ON_EXT_PINS
    }

    switch value & 0x80 {
        case 0:
            // Generate an NMI at the start of the vertical blanking interval
            nmi_on_vblank = false
        case 1:
            // Generate an NMI at the start of the vertical blanking interval
            nmi_on_vblank = true
    }
}

ppu_mask :: proc(using ppu: ^PPU, value: u8) {

}

read_ppu_address :: proc(using ppu: ^PPU, address: u16) -> u8 {
    switch address {
        case 0x2002: 
            return ppu_status(ppu)
        case:
            return 0
    }
}

write_ppu_address :: proc(using ppu: ^PPU, address: u16, value: u8) {
    switch address {
        case 0x2000:
            ppu_ctrl(ppu, value)
        case:
            return
    }
}
