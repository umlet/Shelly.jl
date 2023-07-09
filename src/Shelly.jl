module Shelly

using Base.Iterators




################################################################################
# prompt
function setprompt(f::Function=prompt_dir_julia)
    Base.active_repl.interface.modes[1].prompt = () -> "$(basename(pwd()))/::julia> "
    return nothing
end
prompt_dir_julia() = "$(basename(pwd()))/::julia> "




################################################################################
# ls
function rpadmax(ss::AbstractVector{<:AbstractString})::Vector{String}
    max_strlen = maximum(length, ss)
    return [ rpad(s, max_strlen) for s in ss ]
end
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


function llline2name(s::AbstractString, lldotline::AbstractString)
    !endswith(lldotline, " .")  &&  error("invalid reference ll-line: '$(lldotline)'")
    offset = length(lldotline) - 1
    RET = drop(s, offset) |> collect |> String
    ss = split(RET, " -> ")  # symlink!
    length(ss) == 2  &&  return ss[1]
    return RET
end

function _ls_win(; showhidden::Bool=false, quiet::Bool=false, returnnames::Bool=false)
    RET::Vector{String} = []
    s = read(`cmd /c dir`, String)
    ss0 = split(s, "\r\n")
    ss0[end] == ""  &&  pop!(ss0)

    ss0 = ss0[6:end-2]

    ss::Vector{String} = []
    ss1 = rpadmax(ss0)
    i = 1
    for (s, s_pad) in zip(ss0, ss1)
        name = llline2name(s, ss0[1])
        !showhidden  &&  name != "."  &&  name != ".."  &&  startswith(name, ".")  &&  continue

        push!(RET, name)

        s_typeind = isdir(name)  ?  "cd"  :  ""
        push!(ss, "$(s_pad)   $(i)$(s_typeind)")
        i += 1
    end

    !quiet  &&  foreach(println, ss)

    returnnames  &&  return RET
    return nothing    
end

function _ls(; long::Bool=false, showhidden::Bool=false, quiet::Bool=false, returnnames::Bool=false)
    Sys.iswindows()  &&  return _ls_win(; quiet=quiet, returnnames=returnnames)

    RET::Vector{String} = []

    if long
        s = read(`ls -a -l --group-directories-first`, String)  
        ss0 = split(s, '\n')
        ss0[end] == ""  &&  pop!(ss0)
        startswith(ss0[1], "total ")  &&  popfirst!(ss0)
    else
        s = read(`ls -a --group-directories-first`, String)
        ss0 = split(s, '\n')
        ss0[end] == ""  &&  pop!(ss0)
    end

    ss::Vector{String} = []
    if long
        ss1 = rpadmax(ss0)
        i = 1
        for (s, s_pad) in zip(ss0, ss1)
            name = llline2name(s, ss0[1])
            !showhidden  &&  name != "."  &&  name != ".."  &&  startswith(name, ".")  &&  continue

            push!(RET, name)

            s_typeind = isdir(name)  ?  "cd"  :  ""
            push!(ss, "$(s_pad)   $(i)$(s_typeind)")
            i += 1
        end
    else
        i = 1
        for name in ss0
            !showhidden  &&  name != "."  &&  name != ".."  &&  startswith(name, ".")  &&  continue

            push!(RET, name)

            s_typeind = isdir(name)  ?  "°"  :  " "
            push!(ss, "$(string(i))$(s_typeind) $(name)")
            i += 1
        end
        ss = lscolumns(ss)
    end

    !quiet  &&  foreach(println, ss)

    returnnames  &&  return RET
    return nothing
end


function _df(; quiet=false, returnnames=false)
    RET::Vector{String} = []

    s = read(`df`, String)  
    ss0 = split(s, '\n')
    ss0[end] == ""  &&  pop!(ss0)
    startswith(ss0[1], "Filesystem ")  &&  popfirst!(ss0)

    ss::Vector{String} = []
    ss1 = rpadmax(ss0)
    for (i,(s, s_pad)) in enumerate(zip(ss0, ss1))
        fname = split(s, ' ')[end]
        push!(RET, fname)

        s_typeind = "cd"
        push!(ss, "$(s_pad)   $(-i)$(s_typeind)")
    end

    !quiet  &&  foreach(println, ss)

    returnnames  &&  return RET
    return nothing
end


function toname(i::Int64; must_be_file=false, must_be_dir=false)
    i == 0  &&  return homedir()


    # mounts
    if i < 0
        i = -i
        names = _df(quiet=true, returnnames=true)
        if i > length(names)
            println(stderr, "ERROR: $(i): No such mount index; run 'df'")
            return nothing
        end
        name = names[i]
        return name
    end


    # current dir
    names = _ls(quiet=true, returnnames=true)
    if i > length(names)
        println(stderr, "ERROR: $(i): No such file system index; run 'll'")
        return nothing
    end
    name = names[i]
    if must_be_file  &&  !isfile(name)
        println(stderr, "ERROR: $(i)='$(name)': Not a file")
        return nothing
    end
    if must_be_dir  &&  !isdir(name)
        println(stderr, "ERROR: $(i)='$(name)': Not a directory")
        return nothing
    end
    return name
end


################################################################################
# cd
function _cd(i::Int64)
    dname = toname(i; must_be_dir=true)
    dname === nothing  &&  return  # error already shown
    cd(dname)
end


################################################################################
# 1-arg file op
function _fileop(i::Int64, scmd::String)
    fname = toname(i; must_be_file=true)
    fname === nothing  &&  return  # error already shown
    run(Cmd([scmd, fname]))
end








################################################################################
# shortcuts

abstract type AbstractShortcut end
_show(io::IO, x::AbstractShortcut) = atshow(x)


# ps1
struct ShortcutPs1 <: AbstractShortcut end
atshow(_::ShortcutPs1) = setprompt()
const ps1 = ShortcutPs1()


# ls
struct ShortcutLs <: AbstractShortcut end
atshow(_::ShortcutLs) = _ls()
const ls = ShortcutLs()
# ll
struct ShortcutLl <: AbstractShortcut end
atshow(_::ShortcutLl) = _ls(; long=true)
const ll = ShortcutLl()

const dir = ll
# # lsa
# struct ShortcutLsa <: AbstractShortcut end
# atshow(_::ShortcutLsa) = _ls(; showhidden=true)
# const lsa = ShortcutLsa()
# # lla
# struct ShortcutLla <: AbstractShortcut end
# atshow(_::ShortcutLla) = _ls(; long=true, showhidden=true)
# const lla = ShortcutLla()


# cd
struct ShortcutCd <: AbstractShortcut i::Int64 end
atshow(x::ShortcutCd) = _cd(x.i)
const ° = cd
const cc = ShortcutCd(2)


# 1-arg file op, for cat, head, tail..
struct ShortcutFileOp <: AbstractShortcut i::Int64; scmd::String end
atshow(x::ShortcutFileOp) = _fileop(x.i, x.scmd)
# head
struct ShortcutHead end      # not of type AbstractShortcut, as no atshow needed; just used in mult dispatch
const head = ShortcutHead()
# tail
struct ShortcutTail end
const tail = ShortcutTail()
# wc
struct ShortcutWc end
const wc = ShortcutWc()


# df
struct ShortcutDf <: AbstractShortcut end
atshow(_::ShortcutDf) = _df()
const df = ShortcutDf()




# TODO
# rm<-WRITE
# 0cd, 2cd write

include("Shelly.jl_base")
include("Shelly.jl_exports")
include("Shelly.jl_docs")
end

