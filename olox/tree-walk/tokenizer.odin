package main
import "core:fmt"
import "core:unicode/utf8"

@(private = "file")
Identifiers := map[string]TokenType {
    "and"    = .AND,
    "class"  = .CLASS,
    "else"   = .ELSE,
    "false"  = .FALSE,
    "for"    = .FOR,
    "fun"    = .FUN,
    "if"     = .IF,
    "nil"    = .NIL,
    "or"     = .OR,
    "print"  = .PRINT,
    "return" = .RETURN,
    "super"  = .SUPER,
    "this"   = .THIS,
    "true"   = .TRUE,
    "var"    = .VAR,
    "while"  = .WHILE,
}
TokenType :: enum {
    //single character
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,

    // one or two character tokens
    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,

    // literals
    IDENTIFIER,
    STRING,
    NUMBER,

    // keywords
    AND,
    CLASS,
    ELSE,
    FALSE,
    FUN,
    FOR,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,
    EOF,
}

Literal :: union {
    int,
    f32,
    string,
}

Lexeme :: union {
    string,
    rune,
}
Token :: struct {
    type:    TokenType,
    line:    int,
    lexeme:  Lexeme,
    literal: Literal,
}

@(private = "file")
token_create :: proc(t: Tokenizer, type: TokenType) -> Token {
    return Token{type, t.line, 'c', 3.14}
}

token_to_string :: proc(t: Token) {
    fmt.printfln("%v", t)
}

// source needs deletion
Tokenizer :: struct {
    source:          []rune,
    start, position: int,
    line:            int,
}

tokenizer_create :: proc(src: string) -> Tokenizer {
    return Tokenizer{source = utf8.string_to_runes(src)}
}

tokenizer_destroy :: proc(t: ^Tokenizer) {
    delete(t.source)
}

tokenizer_next :: proc(t: ^Tokenizer) -> (Token, bool) {
    token: Token
    done := false
    for _ in t.source[t.position:] {
        c := advance(t)
        if type, found := scan(t, c); found {
            token = token_create(t^, type)
            done = true
            break
        }
    }
    t.start = t.position
    return token, done
}

@(private = "file")
scan_single :: proc(t: ^Tokenizer, c: rune) -> (TokenType, bool) {
    token_type: TokenType
    result := false
    switch c {
    case '(':
        result = true
        token_type = .LEFT_PAREN
    case ')':
        result = true
        token_type = .RIGHT_PAREN
    case '{':
        result = true
        token_type = .LEFT_BRACE
    case '}':
        result = true
        token_type = .RIGHT_BRACE
    case ',':
        result = true
        token_type = .COMMA
    case '.':
        result = true
        token_type = .DOT
    case '-':
        result = true
        token_type = .MINUS
    case '+':
        result = true
        token_type = .PLUS
    case ';':
        result = true
        token_type = .SEMICOLON
    case '*':
        result = true
        token_type = .STAR
    }
    return token_type, result
}

@(private = "file")
scan_double :: proc(t: ^Tokenizer, c: rune) -> (TokenType, bool) {
    token_type: TokenType
    result := false
    switch c {
    case '!':
        result = true
        token_type = check_double(t, '=', .BANG_EQUAL, .BANG)
    case '=':
        result = true
        token_type = check_double(t, '=', .EQUAL_EQUAL, .EQUAL)
    case '>':
        result = true
        token_type = check_double(t, '=', .GREATER_EQUAL, .GREATER)
    case '<':
        result = true
        token_type = check_double(t, '=', .LESS_EQUAL, .LESS)
    }
    return token_type, result
}

@(private = "file")
scan_skippables :: proc(t: ^Tokenizer, c: rune) -> (TokenType, bool) {
    token_type: TokenType
    result := false
    switch c {
    case '/':
        if !is_comment(t, c) {
            result = true
            token_type = .SLASH
        }
    case ' ':
    case '\r':
    case '\n':
        t.line += 1
    case '\t':
    }
    return token_type, result
}

@(private = "file")
scan :: proc(t: ^Tokenizer, c: rune) -> (TokenType, bool) {
    result := false
    token_type: TokenType
    if token_type, result = scan_single(t, c); result {
        return token_type, result
    }

    if token_type, result = scan_double(t, c); result {
        return token_type, result
    }

    if token_type, result = scan_skippables(t, c); result {
        return token_type, result
    }

    // scan lengthy? scan words?
    if c == '"' {
        find_string_end(t, c)
        result = true
        token_type = .STRING

    } else if is_digit(c) {
        find_number_end(t, c)
        return .NUMBER, true

    } else if is_alnum(c) {
        find_identifier_end(t, c)
        id := utf8.runes_to_string(t.source[t.start:t.position])
        defer delete(id)
        elem, ok := Identifiers[id]
        if ok {
            token_type = elem
        } else {
            token_type = .IDENTIFIER
        }
        return token_type, true

    } else {
        fmt.eprintfln("Unexpected character %v", c)
    }
    // one or two character tokens
    return token_type, result
}

@(private = "file")
find_string_end :: proc(t: ^Tokenizer, c: rune) {
    next := advance(t)
    for next != '"' {
        next = advance(t)
    }
}

@(private = "file")
find_number_end :: proc(t: ^Tokenizer, c: rune) {
    for is_digit(peek(t)) {
        advance(t)
        if peek(t) == '.' do advance(t)
    }
}

@(private = "file")
find_identifier_end :: proc(t: ^Tokenizer, c: rune) {
    for is_alnum(peek(t)) {
        advance(t)
    }
}

@(private = "file")
is_comment :: proc(t: ^Tokenizer, c: rune) -> bool {
    if match(t, '/') {
        for peek(t) != '\n' && t.position < len(t.source) {
            advance(t)
        }
        return true
    }
    return false
}

@(private = "file")
is_digit :: proc(c: rune) -> bool {
    return c >= 0 && c <= 9
}


@(private = "file")
is_alpha :: proc(c: rune) -> bool {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

@(private = "file")
is_alnum :: proc(c: rune) -> bool {
    return is_digit(c) || is_alpha(c)
}

@(private = "file")
check_double :: proc(t: ^Tokenizer, c: rune, t1, t2: TokenType) -> TokenType {
    if match(t, c) {
        advance(t)
        return t1
    }
    return t2
}

// ^tokenizer -> (rune, Error) ?
@(private = "file")
advance :: proc(t: ^Tokenizer) -> rune {
    if t.position >= len(t.source) {
        // return error indicating end of string
        return '\x00'
    }
    c := t.source[t.position]
    t.position += 1
    return c
}

@(private = "file")
match :: proc(t: ^Tokenizer, c: rune) -> bool {
    return c == t.source[t.position]
}

@(private = "file")
peek :: proc(t: ^Tokenizer) -> rune {
    return t.source[t.position]
}
