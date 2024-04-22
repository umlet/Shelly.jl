module Shelly

using Base.Iterators: drop, countfrom, partition

abstract type TraitOS end
struct Linux <: TraitOS end
struct MacOS <: TraitOS end
struct Windows <: TraitOS end
OS::TraitOS = Sys.iswindows()  ?  Windows()  :  ( Sys.isapple()  ?  MacOS()  :  Linux() )

include("lscolumns.jl")
include("ls_cd_df.jl")



################################################################################
# prompt
prompt_dir_julia() = "$(basename(pwd()))/::julia> "
function setprompt(f::Function=prompt_dir_julia)
    Base.active_repl.interface.modes[1].prompt = f
    return nothing
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
const ps1 = ShortcutPs1()
atshow(_::ShortcutPs1) = setprompt()


# ls(a)
struct ShortcutLs <: AbstractShortcut end
const ls = ShortcutLs()
atshow(_::ShortcutLs)  = printlistfiles(; long=false, showhidden=false)

struct ShortcutLsa <: AbstractShortcut end
const lsa = ShortcutLsa()
atshow(_::ShortcutLsa) = printlistfiles(; long=false, showhidden=true)

# ll(a)
struct ShortcutLl <: AbstractShortcut end
const ll = ShortcutLl()
atshow(_::ShortcutLl)  = printlistfiles(; long=true, showhidden=false)

struct ShortcutLla <: AbstractShortcut end
const lla = ShortcutLla()
atshow(_::ShortcutLla) = printlistfiles(; long=true, showhidden=true)


const dir = ll
const dira = lla


# cd
struct ShortcutCd <: AbstractShortcut i::Int64 end
const ° = cd
const cc = ShortcutCd(2)
atshow(x::ShortcutCd) = _cd(x.i)


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
const df = ShortcutDf()
const ldf = ShortcutDf()  # less likely to name-clash
atshow(_::ShortcutDf) = printlistmounts()





include("Shelly.jl_base")
include("Shelly.jl_exports")
include("Shelly.jl_docs")
end # module


#=
TODO:
- OS-ify listmount
- README & version
- top level dir on Windows does not return ".." entry
- Windows drive letters -- use isdir insteal of deprecated wmic
- let strings escape via pipe op (also for df?)
- copmplete help; ps1..
- explicit iter imports [DONE]
=#
