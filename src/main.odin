package main

// Core imports
import "core:log"
import "core:fmt"
import "core:strings"
import "core:os"

// Our own imports
import "nes:cart"
import "nes:helpers"

// Vendor imports
import sdl "vendor:sdl2"


MouseButton :: enum u8 {
    Left = 1
    Middle = 2
    Right = 3
}

WINDOW_HEIGHT : i32 : 480
WINDOW_WIDTH : i32 : 480

// Stop the game flag
stop_the_game: bool = false

main :: proc() {
    // Check arguments
    if helpers.check_arguments() != .None {
        return
    }
    
    // Load ROM
    rom, err := cart.load_rom(os.args[1])
    if err != .None {
        return
    }

    // Read ROM and return cart
    cart_instance := cart.read_rom(&rom)

    fmt.println("Cart:", cart_instance)

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