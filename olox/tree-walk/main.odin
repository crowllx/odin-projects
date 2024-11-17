package tree

import "core:bufio"
import "core:fmt"
import "core:io"
import "core:mem"
import "core:os"
import "parser"

run :: proc(line: string) {
    stmts, errs := parser.parse(line)
    defer {
        for s in stmts {
            parser.statement_destroy(s)
        }
        delete(stmts)
        delete(errs)
    }

    fmt.printfln("errs: %v", errs)
    interpret(stmts, errs)
}

run_file :: proc(file_name: string) {
    if data, ok := os.read_entire_file(file_name); ok {
        stmts, errs := parser.parse(string(data))
        defer {
            for s in stmts {
                parser.statement_destroy(s)
            }
            delete(stmts)
            delete(errs)
        }

        interpret(stmts, errs)
    } else {
        fmt.eprintln("Error reading file.")
    }
}

run_prompt :: proc() -> io.Error {
    r: bufio.Reader
    bufio.reader_init(&r, os.stream_from_handle(os.stdin))
    defer bufio.reader_destroy(&r)
    defer cleanup()

    for {
        line := bufio.reader_read_string(&r, '\n') or_return
        defer delete(line)
        run(line)
    }
    return nil
}

main :: proc() {

    // mem check
    alloc: mem.Tracking_Allocator
    mem.tracking_allocator_init(&alloc, context.allocator)
    defer mem.tracking_allocator_destroy(&alloc)
    context.allocator = mem.tracking_allocator(&alloc)

    switch len(os.args) {
    case 2:
        run_file(os.args[1])
    case 1:
        err := run_prompt()
        if err != nil {
            fmt.eprintln(err)
        }
    case:
        fmt.println("usage: olox [script]")
        os.exit(1)
    }

    for _, leak in alloc.allocation_map {
        fmt.eprintfln("Memory Leak: %v %v", leak.location, leak.size)
    }
    for bad_free, _ in alloc.bad_free_array {
        fmt.eprintfln("Bad free %v, %v", bad_free.location, bad_free.memory)
    }

    fmt.eprintln(alloc.peak_memory_allocated)
}
