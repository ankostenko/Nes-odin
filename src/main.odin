package main

// Core imports
import "core:fmt"
import "core:io"
import "core:os"
import "core:time"
import "nes:core"

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
    using core

    // Check arguments
    number_of_opcodes_to_run, error := check_arguments()
    if error != .None {
        return
    }

    system := init_system()
    cpu := init_cpu(&system)
    start := time.now() // Start the timer
    input := make([]byte, 512)
    for i:u64 = 0; i < number_of_opcodes_to_run; i += 1 {
        // s := os.stream_from_handle(os.stdin)
        // if reader, ok := io.to_reader(s); ok {
        //     io.read(reader, input)
        //     if fmt.tprintf("%s", input) == "s" {
        //         break
        //     }
        // }
        dump_cpu(&cpu)
     
        nmi_before := cpu.system.ppu.nmi_on_vblank

        cpu_clock_cycles_before := cpu.clock
        run_opcode(&cpu)
        cpu_clock_cycles_after := cpu.clock

        ppu := &cpu.system.ppu
        ppu_tick(&system.ppu, (cpu_clock_cycles_after - cpu_clock_cycles_before) * 3)
        nmi_after := cpu.system.ppu.nmi_on_vblank
    
        if nmi_before != nmi_after && ppu.nmi_on_vblank {
            cpu_nmi(&cpu)
        }
    }
    end := time.now() // Stop the timer

    // Print the time it took to run the opcodes
    fmt.println("Ran", number_of_opcodes_to_run, "opcodes in", time.duration_milliseconds(time.diff(start, end)), "milliseconds")

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