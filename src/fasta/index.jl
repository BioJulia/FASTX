# FASTA Index
# ===========
#
# Index for random access to FASTA files.
#
# This file is a part of BioJulia.
# License is MIT: https://github.com/BioJulia/BioSequences.jl/blob/master/LICENSE.md

# http://www.htslib.org/doc/faidx.html
struct Index
    # offset for the record's sequence by header: See above specification
    names::Dict{String, Int}
    lengths::Vector{Int}
    offsets::Vector{Int}
    linebases::Vector{Int}
    linewidths::Vector{Int}
end

function Index(filepath::AbstractString)
    return open(read_faidx, filepath)
end

function read_faidx(input::IO)
    names = Dict{String, Int}()
    lengths = Int[]
    offsets = Int[]
    linebases = Int[]
    linewidths = Int[]
    for (i, line) in enumerate(eachline(input))
        values = split(chomp(line), '\t')
        name = values[1]
        length = parse(Int, values[2])
        offset = parse(Int, values[3])
        linebase = parse(Int, values[4])
        linewidth = parse(Int, values[5])
        names[name] = i
        push!(lengths, length)
        push!(offsets, offset)
        push!(linebases, linebase)
        push!(linewidths, linewidth)
    end
    return Index(names, lengths, offsets, linebases, linewidths)
end

function Base.getindex(index::Index, name::AbstractString)
    i = get(index.names, convert(String, name), nothing)
    if i === nothing
        throw(ArgumentError("sequence \"$(name)\" is not in the index"))
    elseif i == 1
        offset = 0
    # Else, we go to the previous one and calculate the length of the previous
    # sequence in bytes, then seek to right after that one.
    else
        prev_offset = index.offsets[i - 1]
        prev_len = index.lengths[i - 1]
        prev_linebase = index.linebases[i - 1]
        prev_linewidth = index.linewidths[i - 1]

        newline_len = prev_linewidth - prev_linebase
        len = cld(prev_len, prev_linebase) * newline_len + prev_len
        offset = prev_offset + len
    end
    return i
end

# Set the reading position of `input` to the starting position of the record `name`.
# TODO: Return the seek position to be consistent with Base?
function seekrecord(input::IO, index::Index, name::AbstractString)
    i = index[name]
    if i == 1
        offset = 0
    # Else, we go to the previous one and calculate the length of the previous
    # sequence in bytes, then seek to right after that one.
    else
        prev_offset = index.offsets[i - 1]
        prev_len = index.lengths[i - 1]
        prev_linebase = index.linebases[i - 1]
        prev_linewidth = index.linewidths[i - 1]

        # Note: newline_len may differ between sequences in the same file, as per
        # the specification.
        newline_len = prev_linewidth - prev_linebase
        len = cld(prev_len, prev_linebase) * newline_len + prev_len
        offset = prev_offset + len
    end
    seek(input, offset)
    return nothing
end
