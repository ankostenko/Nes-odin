package main 

PPU :: struct {

}

init_ppu :: proc() -> PPU {
    return PPU{}
}

read_ppu_address :: proc(ppu: PPU, address: u16) -> u8 {
    return 0
}

write_ppu_address :: proc(ppu: PPU, address: u16, value: u8) {
    return
}
