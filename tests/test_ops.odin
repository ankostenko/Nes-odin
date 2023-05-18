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

@(test)
test_is_page_boundary_crossed :: proc(t: ^testing.T) {
    // Page boundary is not crossed
    crossed := core._is_page_boundary_crossed(0x200, 0x2ff)
    expect(t, crossed == false)

    // Page boundary is crossed
    crossed = core._is_page_boundary_crossed(0x200, 0x300)
    expect(t, crossed == true)

    // Page boundary is crossed
    crossed = core._is_page_boundary_crossed(0x200, 0x1fe)
    expect(t, crossed == true)
}

@(test)
test_is_page_boundary_crossed_offset :: proc(t: ^testing.T) {
    // Page boundary is not crossed
    crossed := core._is_page_boundary_crossed_offset(0x200, 0x10)
    expect(t, crossed == false)

    // Page boundary is crossed
    crossed = core._is_page_boundary_crossed_offset(0x1fe, 0x10)
    expect(t, crossed == true)
}

main :: proc() {
    t := testing.T{}

    test_calculate_jump_address(&t)
    test_is_page_boundary_crossed(&t)
    test_is_page_boundary_crossed_offset(&t)
}