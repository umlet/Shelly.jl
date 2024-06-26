

# helper: isdir can fail with exception
isnicedir(s) = try  isdir(s)  catch;  false  end




let
    lastshowhidden::Bool = false
    global setlastshowhidden(x::Bool) = ( lastshowhidden = x )
    global getlastshowhidden() = lastshowhidden  # only read by 'cd'-logic
end

struct ListfilesStruct
    lines_raw_long::Vector{String}
    names::Vector{String}

    outs_long::Vector{String}
    outs_short::Vector{String}
end

function rpadmax(ss::AbstractVector{<:AbstractString})::Vector{String}
    maxlength = maximum(length, ss)
    return [ rpad(s, maxlength) for s in ss ]
end
function getoffset_line2name(dotline::AbstractString)::Int64
    !endswith(dotline, " .")  &&  error("invalid dot/reference line: '$(dotline)'")
    return length(dotline) - 1
end
function line2name(s::AbstractString, offset::Int64, _::Union{Linux, MacOS})
    RET = drop(s, offset) |> collect |> String
    ss = split(RET, " -> ")  # symlink!
    length(ss) == 2  &&  return ss[1]
    return RET    
end
function line2name(s::AbstractString, offset::Int64, _::Windows)
    RET = drop(s, offset) |> collect |> String
    ss = split(RET, " [")  # dir /a..
    length(ss) == 2  &&  return ss[1]
    return RET    
end

# On Linuxy systems, we want '.' and '..' entries; we remove other hidden files ourselves
listfilecmd(         _::Bool, _::Linux)   = `ls -l -a --group-directories-first`
listfilecmd(         _::Bool, _::MacOS)   = `ls -l -a`
listfilecmd(showhidden::Bool, _::Windows) = showhidden  ?  `cmd /c dir /a /o:g`  :  `cmd /c dir /o:g`

function _llraw(showhidden::Bool, os::Union{Linux, MacOS})
    cmd = listfilecmd(showhidden, os)
    s = read(cmd, String)
    ss = split(s, '\n')
    ss[end] == ""  &&  pop!(ss)

    # at least '.' and '..' expected..
    length(ss) < 2  &&  error("unexpected 'ls' result; too few entries")
    startswith(ss[1], "total ")  &&  popfirst!(ss)
    return ss
end
function _llraw(showhidden::Bool, os::Windows)
    RET = let
        cmd = listfilecmd(showhidden, os)
        s = read(cmd, String)
        ss = split(s, "\r\n")
        ss[end] == ""  &&  pop!(ss)

        # prefix of 5, suffix of 2 lines expected
        length(ss) < 7  &&  error("unexpected 'dir' result; too few entries")
        ss[6:end-2]
    end

    # special cases: root dir & seemingly odd/'.'-less folder output
    # get '.' and '..' lines from homedir
    if length(RET) == 0  ||  !endswith(RET[1], " .")
        s = read(`cmd /c dir $(homedir())`, String)
        ss = split(s, "\r\n")
        pushfirst!(RET, ss[7])
        pushfirst!(RET, ss[6])
    end
    return RET
end

function listfiles(showhidden::Bool, os::Union{Linux, MacOS})
    lines_raw_long = _llraw(true, os)

    names = let
        i = getoffset_line2name(lines_raw_long[1])
        [ line2name(s, i, os) for s in lines_raw_long ]
    end

    if showhidden == false
        inds = findall(x -> x in (".", "..") || !startswith(x, "."), names)
        lines_raw_long = lines_raw_long[inds]
        names = names[inds]
    end

    outs_long  = [ (isnicedir(name) ? "$(s)   $(i)cd" : "$(s)   $(i)")    for (s, name, i) in zip(rpadmax(lines_raw_long), names, countfrom(1)) ]
    outs_short = [ (isnicedir(name) ? "$(i)° $(name)" : "$(i)  $(name)")  for    (name, i) in zip(                         names, countfrom(1)) ]
    return ListfilesStruct(lines_raw_long, names, outs_long, outs_short)
end
function listfiles(showhidden::Bool, os::Windows)
    lines_raw_long = _llraw(showhidden, os)

    names = let
        i = getoffset_line2name(lines_raw_long[1])
        [ line2name(s, i, os) for s in lines_raw_long ]
    end

    outs_long  = [ (isnicedir(name) ? "$(s)   $(i)cd" : "$(s)   $(i)")    for (s, name, i) in zip(rpadmax(lines_raw_long), names, countfrom(1)) ]
    outs_short = [ (isnicedir(name) ? "$(i)° $(name)" : "$(i)  $(name)")  for    (name, i) in zip(                         names, countfrom(1)) ]
    return ListfilesStruct(lines_raw_long, names, outs_long, outs_short)
end

function listfiles(showhidden::Bool)
    setlastshowhidden(showhidden)
    listfiles(showhidden, OS)
end

function printlistfiles(; long::Bool, showhidden::Bool)
    S = listfiles(showhidden)
    if long
        foreach(println, S.outs_long)
        return nothing
    end
    ss = lscolumns(S.outs_short)
    foreach(println, ss)
end




struct ListmountsStruct
    lines_raw::Vector{String}
    names::Vector{String}

    outs::Vector{String}
end

function listmounts(_::Union{Linux, MacOS})
    lines_raw = let
        s = read(`df`, String)  
        ss = split(s, '\n')
        ss[end] == ""  &&  pop!(ss)

        length(ss) < 1  &&  error("unexpected 'df' result; too few entries")
        startswith(ss[1], "Filesystem ")  &&  popfirst!(ss)
        ss
    end

    names = [ split(x, ' ')[end] for x in lines_raw ]

    outs = [ "$(s)   $(-i)cd" for (s,i) in zip(rpadmax(lines_raw), countfrom(1)) ]

    return ListmountsStruct(lines_raw, names, outs)
end
function listmounts(_::Windows)
    lines_raw = String[]
    for c in 'A':'Z'
        drive = c * ':'
        !isnicedir(drive)  &&  continue
        push!(lines_raw, drive)
    end
    outs = [ "$(s)   $(-i)cd" for (s,i) in zip(lines_raw, countfrom(1)) ]
    return ListmountsStruct(lines_raw, lines_raw, outs)
end
listmounts() = listmounts(OS)
function printlistmounts()
    S = listmounts()
    foreach(println, S.outs)
end




function toname(i::Int64; must_be_file=false, must_be_dir=false)
    i == 0  &&  return homedir()


    # mounts
    if i < 0
        i = -i
        names = listmounts().names
        if i > length(names)
            println(stderr, "ERROR: $(i): No such mount index; run 'df'")
            return nothing
        end
        return names[i]
    end


    # current dir
    names = listfiles(getlastshowhidden()).names
    if i > length(names)
        println(stderr, "ERROR: no file entry index: $(i)")
        return nothing
    end
    name = names[i]
    if must_be_file  &&  !isfile(name)
        println(stderr, "ERROR: $(i)='$(name)': mot a file")
        return nothing
    end
    if must_be_dir  &&  !isnicedir(name)
        println(stderr, "ERROR: $(i)='$(name)': not a dir")
        return nothing
    end
    return name
end

