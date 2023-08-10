package core

import "core:os"
import "core:fmt"
import "core:strconv"

INFINITE_NUMBER_OF_OPCODES_TO_RUN: i64 = -1
DEFAULT_NUMBER_OF_OPCODES_TO_RUN: i64 = 0


// Check arguments
check_arguments :: proc() -> (i64, Error) {
    number_of_opcodes_to_run := DEFAULT_NUMBER_OF_OPCODES_TO_RUN
    // Check that a ROM was specified
    if len(os.args) < 2 {
        fmt.println("Usage: nes <ROM>")
        return number_of_opcodes_to_run, .InvalidArguments
    }

    // Check that the ROM exists
    if !os.exists(os.args[1]) {
        fmt.println("Error: ROM does not exist")
        return number_of_opcodes_to_run, .FileDoesntExist
    }

    ok: bool
    if len(os.args) == 4 {
        if os.args[2] == "-n" {
            if number_of_opcodes_to_run, ok = strconv.parse_i64_of_base(os.args[3], 10); !ok {
                return DEFAULT_NUMBER_OF_OPCODES_TO_RUN, .InvalidArguments
            }
        }
    }

    return number_of_opcodes_to_run, .None
}

parse_number_of_opcodes_to_run :: proc(input: string) -> i64 {
    number_of_opcodes_to_run, ok := strconv.parse_i64_of_base(input, 10)
    if !ok {
        return DEFAULT_NUMBER_OF_OPCODES_TO_RUN
    }
    return number_of_opcodes_to_run
}