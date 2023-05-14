package main

APU :: struct {

}

init_apu :: proc() -> APU {
    return APU{}
}

read_apu_address :: proc(apu: APU, address: u16) -> u8 {
    return 0
}

write_apu_address :: proc(apu: APU, address: u16, value: u8) {
    return
}
