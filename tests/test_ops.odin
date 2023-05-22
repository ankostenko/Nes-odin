package tests

import "core:testing"
import "core:fmt"

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

@(test)
test_pushing_and_pulling_word_to_and_from_stack :: proc(t: ^testing.T) {
    system := core.System{
        scratch_ram=make([]u8, 0x800),
        ppu=core.init_ppu(),
        apu=core.init_apu(),
    }
    cpu := core.init_cpu(system)

    // Push word to stack
    value: u16 = 100

    // Push low byte first then high byte because little endian
    cpu = core._push_byte_to_stack(cpu, cast(u8)(value >> 8))
    cpu = core._push_byte_to_stack(cpu, cast(u8)(value & 0xff))

    // Pull word from stack
    cpu.s += 1
    pulled_value := core.system_read_word(system, core.STACK_START_ADDR + u16(cpu.s))

    expect(t, pulled_value == value, fmt.tprintf("Expected %d, got %d", value, pulled_value))

    // Push word to stack
    value = 0x1234

    // Push low byte first then high byte because little endian
    cpu = core._push_byte_to_stack(cpu, cast(u8)(value >> 8))
    cpu = core._push_byte_to_stack(cpu, cast(u8)(value & 0xff))

    // Pull word from stack
    cpu.s += 1
    pulled_value = core.system_read_word(system, core.STACK_START_ADDR + u16(cpu.s))

    expect(t, pulled_value == value, fmt.tprintf("Expected %d, got %d", value, pulled_value))
}

main :: proc() {
    t := testing.T{}

    test_calculate_jump_address(&t)
    test_is_page_boundary_crossed(&t)
    test_is_page_boundary_crossed_offset(&t)
    test_pushing_and_pulling_word_to_and_from_stack(&t)
}