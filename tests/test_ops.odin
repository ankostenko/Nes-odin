package tests

import "core:testing"
import "nes:core"

expect :: testing.expect

@(test)
test_calculate_jump_address :: proc(t: ^testing.T) {
    // Calculate jump address with positive offset
    calculated_address := core._calculate_address_for_jump(0x200, 2)
    expect(t, calculated_address == 0x202)

    // Calculate jump address with negative offset
    calculated_address = core._calculate_address_for_jump(0x200, -2)
    expect(t, calculated_address == 0x1fe)
}

main :: proc() {
    t := testing.T{}

    test_calculate_jump_address(&t)
}