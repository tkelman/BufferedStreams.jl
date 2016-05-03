# Empty Stream
# ============

"""
`EmptyStream` is a dummy stream to allow a buffered stream to wrap an
array without additional buffering.
"""
immutable EmptyStream end

Base.close(::EmptyStream) = nothing

Base.position(stream::BufferedInputStream{EmptyStream}) = stream.position - 1
Base.position(stream::BufferedOutputStream{EmptyStream}) = stream.position - 1


# Buffered input stream
# ---------------------

function BufferedInputStream(data::Vector{UInt8}, len::Integer=endof(data))
    return BufferedInputStream{EmptyStream}(EmptyStream(), data, 1, len, 0)
end

function fillbuffer!(stream::BufferedInputStream{EmptyStream})
    return 0
end

function Base.eof(stream::BufferedInputStream{EmptyStream})
    return stream.position > stream.available
end

function Base.read(stream::BufferedInputStream{EmptyStream}, ::Type{UInt8})
    if eof(stream)
        throw(EOFError())
    end
    byte = stream.buffer[stream.position]
    stream.position += 1
    return byte
end

function Base.seek(stream::BufferedInputStream{EmptyStream}, pos::Integer)
    upanchor!(stream)
    if 1 <= pos + 1 <= stream.available
        stream.position = pos + 1
    else
        throw(BoundsError)
    end
end


# Buffered output stream
# ----------------------

function BufferedOutputStream()
    return BufferedOutputStream{EmptyStream}(
        EmptyStream(), Vector{UInt8}(1024), 1)
end

function flushbuffer!(::BufferedOutputStream{EmptyStream}, eof::Bool=false)
    return
end

function Base.write(stream::BufferedOutputStream{EmptyStream}, byte::UInt8)
    if stream.position > endof(stream.buffer)
        resize!(stream.buffer, 2 * length(stream.buffer))
    end
    stream.buffer[stream.position] = byte
    stream.position += 1
    return 1
end

function Base.write(stream::BufferedOutputStream{EmptyStream}, data::Vector{UInt8})
    n = length(data)
    n_avail = endof(stream.buffer) - stream.position + 1
    if n > n_avail
        resize!(stream.buffer, nextpow2(n + stream.position - 1))
    end
    copy!(stream.buffer, stream.position, data, 1)
    stream.position += n
    return n
end

# Faster append for vector-backed output streams.
@inline function Base.append!(stream::BufferedOutputStream{EmptyStream},
                              data::Vector{UInt8}, start::Int, stop::Int)
    n = stop - start + 1
    if stream.position + n > length(stream.buffer)
        resize!(stream.buffer, max(n, max(1024, 2 * length(stream.buffer))))
    end
    copy!(stream.buffer, stream.position, data, start, n)
    stream.position += n
end

function Base.takebuf_array(stream::BufferedOutputStream{EmptyStream})
    # TODO: benchmark resizing stream.buffer, returning it, and replacing it
    # with an zero-length array, which might be fast in the common case of
    # building just one array/string.
    chunk = stream.buffer[1:stream.position-1]
    stream.position = 1
    return chunk
end

function Base.takebuf_string(stream::BufferedOutputStream{EmptyStream})
    chunk = takebuf_array(stream)
    return isvalid(ASCIIString, chunk) ? ASCIIString(chunk) : UTF8String(chunk)
end

function Base.empty!(stream::BufferedOutputStream{EmptyStream})
    return stream.position = 1
end

function Base.isempty(stream::BufferedOutputStream{EmptyStream})
    return stream.position == 1
end

function Base.length(stream::BufferedOutputStream{EmptyStream})
    return stream.position - 1
end

function Base.(:(==))(a::BufferedOutputStream{EmptyStream},
                      b::BufferedOutputStream{EmptyStream})
    if a.position == b.position
        return ccall(:memcmp, Cint, (Ptr{Void}, Ptr{Void}, Csize_t),
                     a.buffer, b.buffer, a.position - 1) == 0
    else
        return false
    end
end