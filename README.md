# Shelly.jl: `cd`, `ls` and `ll` in Julia

Julia's REPL and its modes are superb. They also offer a variety of ways to interact with the underlying file system--the `cd("somedir")` function, a full-blown shell mode, macro capabilities, etc. Yet all involve just a *tiny* bit more typing of (often shifted) chars, or a mode switch.

Shelly provides a modeless and minimal-keystroke way of navigating the file system with `cd`, `ls`, and `ll`, along with some additional Unix shortcuts.

Shelly does not hack the REPL. Instead, it just uses `show` on custom types, and it overloads multiplication in what we humbly designate the *multiply and conquer* paradigm shift. Find out how it works below the examples.

<br>
<br>




### Example: `ll`, `cd` and `ls`

Say our current directory is the "Shelly.jl" one:

```
# Note: - we are in Julia's native REPL mode
#       - the output of 'll' here is written directly to the console

julia> ll
drwxr-xr-x 3 martin martin 4096 Jun 20 17:28 .           1cd
drwxr-xr-x 6 martin martin 4096 Jun 20 11:01 ..          2cd
-rw-r--r-- 1 martin martin  753 Jun 20 17:08 README.md   3
drwxr-xr-x 2 martin martin 4096 Jun 20 17:28 src         4cd
```

We can now, still in the Julia REPL mode, change the current dir to `src`:

```
julia> 4cd

julia> pwd()
"/home/martin/Shelly.jl/src"   # we have indeed moved!
```

Let's look around here:

```
julia> ll
drwxr-xr-x 2 martin martin 4096 Jun 20 17:28 .                   1cd
drwxr-xr-x 3 martin martin 4096 Jun 20 17:28 ..                  2cd
-rw-r--r-- 1 martin martin 4861 Jun 20 17:45 shelly.jl           3
-rw-r--r-- 1 martin martin  227 Jun 20 16:23 shelly.jl_base      4
-rw-r--r-- 1 martin martin  132 Jun 20 17:09 shelly.jl_exports   5
```

And now move back up:

```
julia> 2cd

julia> ll
drwxr-xr-x 3 martin martin 4096 Jun 20 17:28 .           1cd
drwxr-xr-x 6 martin martin 4096 Jun 20 11:01 ..          2cd
-rw-r--r-- 1 martin martin  753 Jun 20 17:08 README.md   3
drwxr-xr-x 2 martin martin 4096 Jun 20 17:28 src         4cd
```

<br>
<br>

The same works with `ls`. To save space and be lighter on the eye, a `°`-suffix instead of `cd` denotes dirs. Both strings work when trying to change directory:

```
julia> ls
1° .  2° ..  3  README.md  4° src

julia> 4cd
julia> pwd()
"/home/martin/Shelly.jl/src"

julia> 2cd
julia> pwd()
"/home/martin/Shelly.jl"

julia> 4°
julia> pwd()
"/home/martin/Shelly.jl/src"

julia> 2°
julia> pwd()
"/home/martin/Shelly.jl"
```

<br>
<br>

There is even a third, prefix-based way to change dir via `!`:
```
julia> !2   # is same as '2cd' or '2°'
```
(Alas, it seems to be impossible to alias the `!` operator for now..)

<br>
<br>




### Example: `cat`, `head`, `tail`, `wc`

```
julia> ls
1° .  2° ..  3  shelly.jl  4  shelly.jl_base  5  shelly.jl_exports

julia> 3cat
module Shelly

using Base.Iterators
...
...
```
These would also work:
```
julia> 3head
..
julia> 3tail
..
julia> 3wc
..
```
<br>
<br>




### Example: `df`

We can show our mounts with the usual `df`:
```
julia> df
/dev/sdb        263174212    8247948 241488108   4% /                      -1cd
tmpfs             6448660          0   6448660   0% /mnt/wsl               -2cd
tools           498750460  172976384 325774076  35% /init                  -3cd
```
To `cd` to a mount, use negative indizes:
```
julia> -2cd
```

<br>
<br>


### The short-shortcut `cc`, and Some More Hints

* You don't have to use `ls` before running a `cd` shortcut, especially if you remember the index
* `0cd` goes to your home directory
* `2cd` always means `cd ..`
* ..but because we want a shortcut for that shortcut, you can use `cc` instead!
* If some of the exported names collide with your functions, selectively `import` the ones you like

<br>
<br>


### And One More Hint: `ps1`

As you'll gallivant around your file system more promiscuously now, you might want to tune the REPL prompt:

```
julia> ps1
Shelly.jl/::julia>   # the new prompt shows the current dir now
```

<br>
<br>



## How Does it Work?

*   Shortcuts like `ls` and `ll` are simple--they are just values:
    ```
    struct ShortcutLs <: AbstractShortcut end

    const ls = ShortcutLs()
    ```
    The `Base.show` method calls `Shelly.atshow` for all `AbstractShortcut`s, where the actual `ls` printing takes place:
    ```
    atshow(_::ShortcutLs) = _ls()
    ```
    Note: following the above logic, you can easily define your own shortcuts!

*   Shortcuts that require an argument, like `cd`, work differently.

    First, Julia provides a neat way of parsing multiplication without the `*` operator:
    ```
    julia> x = 21
    julia> 2x
    42
    ```
    If x is of some new, custom type, we can override the multiplication operation:
    ```
    Base.:*(i::Int64, _::SomeNewType) = ...
    ```
    But here we want to use the string `cd`, which is an already-defined Julia function. Luckily, we don't even have to dispatch on functions in general, but we can dispatch on the `cd`s singleton type as seen in:
    ```
    julia> typeof(cd)
    typeof(cd) (singleton type of function cd, subtype of Function)
    ```
    We can thus use:
    ```
    Base.:*(i::Int64, _::typeof(cd)) = ShortcutCd(i)
    ```
    And underneath, the same logic as above is then at work:
    ```
    atshow(x::ShortcutCd) = _cd(x.i)
    ```

<br>
<br>

## TODOs
Windows support; code cleanup; more commands?; docstrings; register..

