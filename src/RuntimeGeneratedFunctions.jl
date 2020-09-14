module RuntimeGeneratedFunctions

using ExprTools, Serialization, SHA

export @RuntimeGeneratedFunction


"""
    RuntimeGeneratedFunction

This type should be constructed via the macro @RuntimeGeneratedFunction.
"""
mutable struct RuntimeGeneratedFunction{moduletag,id,argnames}
    body::Expr
    function RuntimeGeneratedFunction(moduletag, ex)
        id = expr2bytes(ex)
        def = splitdef(ex)
        args, body = normalize_args(def[:args]), def[:body]
        f = new{moduletag,id,Tuple(args)}(body)
        _cache_self(moduletag, id, f)
        return f
    end
end

"""
    @RuntimeGeneratedFunction(function_expression)

Construct a function from `function_expression` which can be called immediately
without world age problems. Somewhat like using `eval(function_expression)` and
then calling the resulting function. The differences are:

* The result can be called immediately (immune to world age errors)
* The result is not a named generic function, and doesn't participate in
  generic function dispatch; it's more like a callable method.

# Examples
```
function foo()
    expression = :((x,y)->x+y+1) # May be generated dynamically
    f = @RuntimeGeneratedFunction(expression)
    f(1,2) # May be called immediately
end
```
"""
macro RuntimeGeneratedFunction(ex)
    _ensure_cache_exists!(__module__)
    quote
        RuntimeGeneratedFunction(
            $(esc(_tagname)),
            $(esc(ex))
        )
    end
end

function Base.show(io::IO, f::RuntimeGeneratedFunction{moduletag, id, argnames}) where {moduletag,id,argnames}
    mod = parentmodule(moduletag)
    func_expr = Expr(:->, Expr(:tuple, argnames...), f.body)
    print(io, "RuntimeGeneratedFunction(#=in $mod=#, ", repr(func_expr), ")")
end

(f::RuntimeGeneratedFunction)(args::Vararg{Any,N}) where N = generated_callfunc(f, args...)

@inline @generated function generated_callfunc(f::RuntimeGeneratedFunction{moduletag, id, argnames}, __args...) where {moduletag,id,argnames}
    setup = (:($(argnames[i]) = @inbounds __args[$i]) for i in 1:length(argnames))
    f_value = _lookup_self(moduletag, id)
    quote
        $(setup...)
        $(f_value.body)
    end
end

### Function caching and lookup
#
# Looking up a RuntimeGeneratedFunction based on the id is a little complicated
# because we want the `id=>func` mapping to survive precompilation. This means
# we need to store the mapping created by a module in that module itself.
#
# For that, we need a way to lookup the correct module from an instance of
# RuntimeGeneratedFunction. Modules can't be type parameters, but we can use
# any type which belongs to the module as a proxy "tag" for the module.
#
# (We could even abuse `typeof(__module__.eval)` for the tag, though this is a
# little non-robust to weird special cases like Main.eval being
# Base.MainInclude.eval.)

_cachename = Symbol("#_RuntimeGeneratedFunctions_cache")
_tagname = Symbol("#_RuntimeGeneratedFunctions_ModTag")

function _cache_self(moduletag, id, f)
    # Use a WeakRef to allow `f` to be garbage collected. (After GC the cache
    # will still contain an empty entry with key `id`.)
    getfield(parentmodule(moduletag), _cachename)[id] = WeakRef(f)
end

function _lookup_self(moduletag, id)
    getfield(parentmodule(moduletag), _cachename)[id].value
end

function _ensure_cache_exists!(mod)
    if !isdefined(mod, _cachename)
        mod.eval(quote
            const $_cachename = Dict()
            struct $_tagname
            end
        end)
    end
end

###
### Utilities
###
normalize_args(args::Vector) = map(normalize_args, args)
normalize_args(arg::Symbol) = arg
function normalize_args(arg::Expr)
    arg.head === :(::) || error("argument malformed. Got $arg")
    arg.args[1]
end

function expr2bytes(ex)
    io = IOBuffer()
    Serialization.serialize(io, ex)
    return Tuple(sha512(take!(io)))
end

end
