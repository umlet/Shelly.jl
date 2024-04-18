

function lscolumns(ss::AbstractVector{<:AbstractString}; width::Int64=0, delim::AbstractString="  ", truncate_onecolcase = true)::Vector{String}
    width == 0  &&  ( width = displaysize(stdout)[2] - 1 )  # leave 1 char space on right-hand side
    width <= 0  &&  error("invalid output width '$(width)'; must be positive, or '0' for autodetect")

    RET::Vector{String} = [ (truncate_onecolcase ? first(s, width) : s) for s in ss ]
    isempty(ss)  &&  return RET

    # max_strlen = maximum(length.(ss)) + length(delim)
    # max_strlen == 0  &&  return [""]  # special case: no delimiter string, and all strings empty

    len = length(ss)
    for cols_try in countfrom(1)
        # example: 4 entries in 3 columns should be done in a (2, 2) instead of a (2, 1, 1) setup
        if mod(len, cols_try) == 0
            len_firstcols = div(len, cols_try)
        else
            len_firstcols = div(len, cols_try) + 1
        end

        SS0 = partition(ss, len_firstcols) |> collect
        SS = [ rpadmax(ss) for ss in SS0[begin:end-1] ]; push!(SS, SS0[end])

        RET_tmp::Vector{String} = []
        i_zipend = length(SS[end])
        i_end = length(SS[begin])
        for i in 1:i_zipend  # make nicer once zip_longest is available
            tmp_ss = [ ss[i] for ss in SS ]
            s = join(tmp_ss, delim)
            length(s) > width  &&  @goto break2
            push!(RET_tmp, s)
        end
        for i in (i_zipend+1):i_end
            tmp_ss = [ ss[i] for ss in SS[begin:end-1] ]
            s = join(tmp_ss, delim)
            length(s) > width  &&  @goto break2
            push!(RET_tmp, s)
        end
        RET = RET_tmp
        len_firstcols == 1  &&  break
    end
@label break2

    return RET
end

