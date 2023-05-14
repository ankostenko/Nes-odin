package cart

import "nes:helpers"

Mirroring :: enum u8 {
    Horizontal
    Vertical
}

// NES cartridge
Cart :: struct {
    pgr_rom: u8
    chr_rom: u8
    mirroring: Mirroring
    battery_present: bool
    mapper: u8
    prg_rom_pages: [][]byte
    chr_rom_pages: [][]byte
}
