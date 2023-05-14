package main

import "core:log"
import "core:fmt"
import "core:strings"
import "core:os"
import sdl "vendor:sdl2"

MouseButton :: enum u8 {
    Left = 1
    Middle = 2
    Right = 3
}

WINDOW_HEIGHT : i32 : 480
WINDOW_WIDTH : i32 : 480

// Errors
Error :: enum {
    None
    InvalidArguments
    FileDoesntExist
    ErrorLoadingROM
}

Mirroring :: enum u8 {
    Horizontal
    Vertical
}

// Data with a cursor
RawBytesWithCursor :: struct {
    data: []byte
    cursor: u64
}

// NES ROM
Cart :: struct {
    pgr_rom: u8
    chr_rom: u8
    mirroring: Mirroring
    battery_present: bool
    mapper: u8
    raw_data: RawBytesWithCursor
}

// NES cart
ROM :: distinct RawBytesWithCursor

// Stop the game flag
stop_the_game: bool = false

// Load ROM from file into memory
load_rom :: proc(path: string) -> (ROM, Error) {
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

// Read one byte
read_one_byte :: proc {
    read_one_byte_cart,
    read_one_byte_rom
}

// Pop one byte from the cart
read_one_byte_cart :: proc(cart: ^Cart) -> byte {
    cursor := cart.raw_data.cursor
    result := cart.raw_data.data[cursor:cursor+1][0]
    cart.raw_data.cursor += 1
    return result
}

read_one_byte_rom :: proc(rom: ^ROM) -> byte {
    cursor := rom.cursor
    result := rom.data[cursor:cursor+1][0]
    rom.cursor += 1
    return result
}

skip_bytes :: proc {
    skip_bytes_cart,
    skip_bytes_rom
}

skip_bytes_cart :: proc(cart: ^Cart, n: u64) {
    cart.raw_data.cursor += n
}

skip_bytes_rom :: proc(rom: ^ROM, n: u64) {
    rom.cursor += n
}

read_rom :: proc(rom: ^ROM) -> Cart {
    // Read header
    assert(len(rom.data) >= 16, "Invalid ROM header: not enough bytes")
    assert(read_one_byte(rom) == 0x4E, "Invalid ROM header: first byte is not N")
    assert(read_one_byte(rom) == 0x45, "Invalid ROM header: second byte is not E")
    assert(read_one_byte(rom) == 0x53, "Invalid ROM header: third byte is not S")
    assert(read_one_byte(rom) == 0x1A, "Invalid ROM header: fourth byte is not 0x1A")

    pgr_rom := read_one_byte(rom)
    chr_rom := read_one_byte(rom)

    flags_6 := read_one_byte(rom)
    flags_7 := read_one_byte(rom)

    // Detect type of mirroring
    mirroring: Mirroring = .Vertical if flags_6 & 0x01 == 0x01 else .Horizontal

    // Detect if battery is present
    battery_present: bool = flags_6 & 0x02 == 0x02

    // Mapper number (higher 4 bits of flags 6 that goes to lower bits of mapper 
    // and higher 4 bits 7 that goes to higher bits of mapper)
    mapper := flags_6 >> 4 | flags_7 & 0xF0

    return Cart{
        pgr_rom=pgr_rom,
        chr_rom=chr_rom,
        mirroring=mirroring,
        battery_present=battery_present,
        mapper=mapper,
        raw_data=RawBytesWithCursor{rom.data, 16}
    }
}

main :: proc() {
    // Check arguments
    if check_arguments() != .None {
        return
    }
    
    // Load ROM
    rom, err := load_rom(os.args[1])
    if err != .None {
        return
    }

    // Read ROM and return cart
    cart := read_rom(&rom)

    fmt.println("Cart:", cart)

    // Ignore for now

    // // Initialize
    // if err := sdl.Init(sdl.INIT_VIDEO); err < 0 {
	//     fmt.println("Init Error:", sdl.GetError())
    // }
    // defer sdl.Quit()

    // // Create the window and the renderer
    // window: ^sdl.Window
    // renderer: ^sdl.Renderer
    // sdl.CreateWindowAndRenderer(WINDOW_WIDTH, WINDOW_HEIGHT, sdl.WINDOW_SHOWN, &window, &renderer)
    // defer sdl.DestroyWindow(window)
    // defer sdl.DestroyRenderer(renderer)

    // sdl.SetRenderDrawColor(renderer, 0, 0, 0, 0)
    // sdl.RenderClear(renderer)
    // sdl.SetRenderDrawColor(renderer, 255, 0, 0, 255)

    // // Wait for a quit event
    // event: sdl.Event
    // for !stop_the_game {
    //     // Poll for events
    //     for sdl.PollEvent(&event) {
    //         if event.type == sdl.EventType.QUIT || event.key.keysym.sym == sdl.Keycode.ESCAPE { // Quit event
    //             stop_the_game = true
    //             break // Exit event loop
    //         } else if event.type == sdl.EventType.KEYDOWN { // Key events
    //             // Handle key presses
    //             if event.key.keysym.sym == sdl.Keycode.LEFT {
                    
    //             } else if event.key.keysym.sym == sdl.Keycode.RIGHT {
                    
    //             } else if event.key.keysym.sym == sdl.Keycode.UP {
                    
    //             } else if event.key.keysym.sym == sdl.Keycode.DOWN {
                    
    //             }
    //         } else if event.type == sdl.EventType.MOUSEBUTTONDOWN || event.type == sdl.EventType.MOUSEMOTION { // Mouse events
    //             // Ignore mouse events outside the window
    //             if event.button.x < 0 || event.button.x >= WINDOW_WIDTH || event.button.y < 0 || event.button.y >= WINDOW_HEIGHT {
    //                 continue
    //             }

    //             // Handle mouse clicks
    //             if event.button.button == u8(MouseButton.Left) {
    //                 sdl.RenderDrawPoint(renderer, event.button.x, event.button.y)
    //             } else if event.button.button == u8(MouseButton.Right) {
    //                 sdl.SetRenderDrawColor(renderer, 0, 0, 0, 255)
    //                 sdl.RenderClear(renderer)
    //                 sdl.SetRenderDrawColor(renderer, 255, 0, 0, 255)
    //             }
    //         }
    //     }

    //     sdl.RenderPresent(renderer)
    // }
}