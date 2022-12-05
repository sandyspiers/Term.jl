module Consoles
import Term: ACTIVE_CONSOLE_WIDTH, ACTIVE_CONSOLE_HEIGHT
export console_height,
    console_width,
    cursor_position,
    up,
    beginning_previous_line,
    prev_line,
    next_line,
    down,
    clear,
    hide_cursor,
    show_cursor,
    line,
    erase_line,
    cleartoend,
    move_to_line,
    change_scroll_region,
    savecursor,
    restorecursor,
    Console,
    enable!,
    disable!

const STDOUT = stdout
const STDERR = stderr

# ---------------------------------------------------------------------------- #
#                                CURSOR CONTROL                                #
# ---------------------------------------------------------------------------- #
"""
Save the current cursor position
"""
savecursor(io::IO = stdout) = write(io, "\e[s")

"""
Restore a previously saved cursor position
"""
restorecursor(io::IO = stdout) = write(io, "\e[u")

"""
Get cursor position
"""
cursor_position(io::IO = stdout) = write(io, "\e[6n")

# --------------------------------- movement --------------------------------- #

"""
Move cursor to the beginning of the previous line
"""
beginning_previous_line(io::IO = stdout) = write(io, "\e[F")

"""
Move cursor up one one or more lines
"""

prev_line(io::IO = stdout, n::Int = 1) = write(io, "\e[" * string(n) * "F")

up(io::IO = stdout, n::Int = 1) = write(io, "\e[" * string(n) * "A")

"""
Move cursor down one or more lines
"""
next_line(io::IO = stdout, n::Int = 1) = write(io, "\e[" * string(n) * "E")

down(io::IO = stdout, n::Int = 1) = write(io, "\e[" * string(n) * "B")

"""
Move cursor to a specific line
"""
move_to_line(io::IO = stdout, n::Int = 1) = write(io, "\e[" * string(n) * ";1H")

# ---------------------------------- display --------------------------------- #
"""
    clear(io::IO = stdout)

Clear terminal from anything printed in the REPL.
"""
clear(io::IO = stdout) = write(io, "\e[2J")
cleartoend(io::IO = stdout) = write(io, "\e[0J")

"""
Hide cursor
"""
hide_cursor(io::IO = stdout) = write(io, "\e[?25l")

"""
Show cursor
"""
show_cursor(io::IO = stdout) = write(io, "\e[?25h")

"""
write a new line.
"""
line(io::IO = stdout, i = 1) = write(io, "\n"^i)

"""
Erase last line in console.
"""
erase_line(io::IO = stdout) = write(io, "\e[2K")

"""
Change the position of the scrolling region in the terminal.

See: http://www.sweger.com/ansiplus/EscSeqScroll.html
"""
function change_scroll_region(io::IO = stdout, n::Int = 1)
    write(io, "\e[1;" * string(n) * "r")  # from row 1 to n, all columns
    return down(io, n)
end

# ---------------------------------------------------------------------------- #
#                                    CONSOLE                                   #
# ---------------------------------------------------------------------------- #
"""
    console_height()

Get the current console height.
"""
console_height(io::IO = stdout) = something(ACTIVE_CONSOLE_HEIGHT[], displaysize(io)[1])

"""
    console_width()

Get the current console width.
"""
console_width(io::IO = stdout) = something(ACTIVE_CONSOLE_WIDTH[], displaysize(io)[2])

struct Console
    height
    width
    default_stdout
    default_stderr
    redirected_stdout
    redirected_stderr
    pipe
end


Console(h, w) = Console(h, w, nothing, nothing, nothing, nothing, nothing)
Console(width) = Console(console_height(), width)
Console() = Console(console_height(), console_width())
Base.displaysize(c::Console) = (c.height, c_width)

function enable!(console::Console)
    ACTIVE_CONSOLE_WIDTH[] = console.width

    
    # replace stdout stderr
    console.default_stdout = stdout
    console.default_stderr = stderr

    # Redirect both the `stdout` and `stderr` streams to a single `Pipe` object.
    pipe = Pipe()
    Base.link_pipe!(pipe; reader_supports_async = true, writer_supports_async = true)
    @static if VERSION >= v"1.6.0-DEV.481" # https://github.com/JuliaLang/julia/pull/36688
        pe_stdout = IOContext(pipe.in, :displaysize=>displaysize(console))
        pe_stderr = IOContext(pipe.in, :displaysize=>displaysize(console))
    else
        pe_stdout = pipe.in
        pe_stderr = pipe.in
    end
    redirect_stdout(pe_stdout)
    redirect_stderr(pe_stderr)

    console.pe_stdout = pe_stdout
    console.pe_stderr = pe_stderr
    console.pipe = pipe

    console
end

function disable!(console::Console)
    ACTIVE_CONSOLE_WIDTH[] = nothing

    redirect_stdout(pe_stdout)
    redirect_stderr(pe_stderr)
end
end
