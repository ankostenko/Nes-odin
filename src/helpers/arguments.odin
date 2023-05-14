package helpers

import "core:os"
import "core:fmt"

// Check arguments
check_arguments :: proc() -> Error {
    // Check that a ROM was specified
    if len(os.args) < 2 {
        fmt.println("Usage: nes <ROM>")
        return .InvalidArguments
    }

    // Check that the ROM exists
    if !os.exists(os.args[1]) {
        fmt.println("Error: ROM does not exist")
        return .FileDoesntExist
    }

    return .None
}