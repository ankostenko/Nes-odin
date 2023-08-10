package main

// Core imports
import "core:fmt"
import "core:io"
import "core:os"
import "core:bufio"
import "core:time"
import "core:strings"
import "core:strconv"

// Local imports
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
    
    buf: [256]byte
    number_of_opcodes_have_run: i64 = 0
    run_in_break: bool = false
    in_breaking_mode: bool = false
    enable_input: bool = true
    address_to_break_at: u16
    in_stepping: bool = false
    for {
        if enable_input && number_of_opcodes_to_run == INFINITE_NUMBER_OF_OPCODES_TO_RUN {
            fmt.print(">>> ")
        }
        // Input
        input: string
        if enable_input && number_of_opcodes_to_run == INFINITE_NUMBER_OF_OPCODES_TO_RUN {
            n, os_error := os.read(os.stdin, buf[:])
            if os_error < 0 {
                fmt.println("Error reading from stdin:", os_error)
                return
            }
            input = strings.trim(string(buf[:n]), " \n\r\t")
        }

        // Parse input
        if enable_input && number_of_opcodes_to_run == INFINITE_NUMBER_OF_OPCODES_TO_RUN {
            if input == "exit" {
                break
            } else if input == "help" {
                fmt.println("exit - Exit the emulator")
                fmt.println("help - Print this help message")
                fmt.println("dump - Dump the CPU state")
                fmt.println("r - run")
                continue
            } else if input == "dump" {
                dump_cpu(&cpu)
                print_current_opcode(&cpu)
                continue
            } else if input == "s" {
                address_to_break_at += 1
                in_stepping = true
            } else if input[:1] == "r" {
                enable_input = false
                if in_breaking_mode {
                    run_in_break = true
                }
                in_stepping = false
            } else if strings.contains(input, "brk") {
                tmp, ok := strconv.parse_u64_of_base(strings.trim(input[3:], " \n\r\t"), 16)
                address_to_break_at = u16(tmp) // Regarding the cast, we can assume that the address is valid and fits in a u16
                if !ok {
                    fmt.println("Invalid address, try again")
                    continue
                } else {
                    fmt.printf("Breakpoint set at %X\n", address_to_break_at)
                }
                continue
            } else if input == "rmbrk" {
                address_to_break_at = 0
                fmt.println("Breakpoint removed")
            }
        }

        if !run_in_break && cpu.pc == address_to_break_at {
            if !in_stepping {
                fmt.printf("Breakpoint hit at %X\n", address_to_break_at)
            }
            enable_input = true
            in_breaking_mode = true
            continue
        } else {
            run_in_break = false
        }

        // Logic and everything
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

        if number_of_opcodes_to_run != INFINITE_NUMBER_OF_OPCODES_TO_RUN && number_of_opcodes_have_run >= number_of_opcodes_to_run {
            break
        }
        number_of_opcodes_have_run += 1
    }
    end := time.now() // Stop the timer

    // Print the time it took to run the opcodes
    if number_of_opcodes_to_run != INFINITE_NUMBER_OF_OPCODES_TO_RUN {
        fmt.println("Ran", number_of_opcodes_to_run, "opcodes in", time.duration_milliseconds(time.diff(start, end)), "milliseconds")
    }

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