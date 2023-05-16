package main

import "core:fmt"
import "core:os"

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

// Load ROM from file into memory
load_rom_data :: proc(path: string) -> (RawBytesWithCursor, Error) {
    f, err := os.open(path)
    if err != 0 {
        fmt.println("Error: could not open ROM")
        return {}, .ErrorLoadingROM
    }
    defer os.close(f)

    // Read the ROM into memory
    rom_data, success := os.read_entire_file_from_handle(f)

    // Check that the ROM was read successfully
    if !success {
        fmt.println("Error: could not read ROM")
        return {}, .ErrorLoadingROM
    }

    return {rom_data, 0}, .None
}

read_rom :: proc(rom: RawBytesWithCursor) -> Cart {
    rom := rom
    // Read header
    assert(len(rom.data) >= 16, "Invalid ROM header: not enough bytes")
    assert(rbwc_read_one_byte(&rom) == 0x4E, "Invalid ROM header: first byte is not N")
    assert(rbwc_read_one_byte(&rom) == 0x45, "Invalid ROM header: second byte is not E")
    assert(rbwc_read_one_byte(&rom) == 0x53, "Invalid ROM header: third byte is not S")
    assert(rbwc_read_one_byte(&rom) == 0x1A, "Invalid ROM header: fourth byte is not 0x1A")

    pgr_rom := rbwc_read_one_byte(&rom)
    chr_rom := rbwc_read_one_byte(&rom)

    flags_6 := rbwc_read_one_byte(&rom)
    flags_7 := rbwc_read_one_byte(&rom)

    // Detect type of mirroring
    mirroring: Mirroring = .Vertical if flags_6 & 0x01 == 0x01 else .Horizontal

    // Detect if battery is present
    battery_present: bool = flags_6 & 0x02 == 0x02

    // Mapper number (higher 4 bits of flags 6 that goes to lower bits of mapper 
    // and higher 4 bits 7 that goes to higher bits of mapper)
    mapper := flags_6 >> 4 | flags_7 & 0xF0

    // Skip 8 bytes
    _ = rbwc_read_bytes(&rom, 8)

    // Allocate memory for the pages of the program
    prg_rom_pages: [][]byte = make([][]byte, pgr_rom)
    for page in 0..<pgr_rom {
        // Read pages of 16KB
        prg_rom_pages[page] = rbwc_read_bytes(&rom, 16 * 1024)
    }

    // Allocate memory for the pages of the character
    chr_rom_pages: [][]byte = make([][]byte, chr_rom)
    for page in 0..<chr_rom {
        // Read pages of 8KB
        chr_rom_pages[page] = rbwc_read_bytes(&rom, 8 * 1024)
    }

    return Cart{
        pgr_rom=pgr_rom,
        chr_rom=chr_rom,
        mirroring=mirroring,
        battery_present=battery_present,
        mapper=mapper,
        prg_rom_pages=prg_rom_pages,
        chr_rom_pages=chr_rom_pages,
    }
}