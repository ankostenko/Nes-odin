package helpers

// Data with a cursor
RawBytesWithCursor :: struct {
    data: []byte
    cursor: u64
}

read_bytes :: proc(rbwc: ^RawBytesWithCursor, n: u64) -> []byte {
    assert(rbwc.cursor + n <= cast(u64)len(rbwc.data), "Size of requested bytes is larger than the size of the data")
    result := rbwc.data[rbwc.cursor:rbwc.cursor+n]
    rbwc.cursor += n
    return result
}

read_one_byte :: proc(rbwc: ^RawBytesWithCursor) -> byte {
    result := rbwc.data[rbwc.cursor:rbwc.cursor+1][0]
    rbwc.cursor += 1
    return result
}
