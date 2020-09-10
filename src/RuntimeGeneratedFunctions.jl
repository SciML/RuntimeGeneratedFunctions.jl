module RuntimeGeneratedFunctions

using ExprTools, Serialization, SHA

export @RuntimeGeneratedFunction


"""
    RuntimeGeneratedFunction

This type should be constructed via the macro @RuntimeGeneratedFunction.
"""
struct RuntimeGeneratedFunction{moduletag,id,argnames}
    function RuntimeGeneratedFunction(moduletag, ex)
        def = splitdef(ex)
        args, body = normalize_args(def[:args]), def[:body]
        id = expr2bytes(body)
        _cache_body(moduletag, id, body)
        new{moduletag,id,Tuple(args)}()
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
    body = _lookup_body(moduletag, id)
    mod = parentmodule(moduletag)
    print(io, "RuntimeGeneratedFunction(#=in $mod=#, :(", :(($(argnames...),)->$body), "))")
end

(f::RuntimeGeneratedFunction)(args::Vararg{Any,N}) where N = generated_callfunc(f, args...)

@inline @generated function generated_callfunc(f::RuntimeGeneratedFunction{moduletag, id, argnames},__args...) where {moduletag,id,argnames}
    setup = (:($(argnames[i]) = @inbounds __args[$i]) for i in 1:length(argnames))
    quote
        $(setup...)
        $(_lookup_body(moduletag, id))
    end
end

### Function body caching and lookup
#
# Caching the body of a RuntimeGeneratedFunction is a little complicated
# because we want the `id=>body` mapping to survive precompilation. This means
# we need to store the cache of mappings which are created by a module in that
# module itself.
#
# For that, we need a way to lookup the correct module from an instance of
# RuntimeGeneratedFunction.  Modules can't be type parameters, but we can use
# any type which belongs to the module as a proxy "tag" for the module.
#
# (We could even abuse `typeof(__module__.eval)` for the tag, though this is a
# little non-robust to weird special cases like Main.eval being
# Base.MainInclude.eval.)

_cachename = Symbol("#_RuntimeGeneratedFunctions_cache")
_tagname = Symbol("#_RuntimeGeneratedFunctions_ModTag")

function _cache_body(moduletag, id, body)
    getfield(parentmodule(moduletag), _cachename)[id] = body
end

function _lookup_body(moduletag, id)
    getfield(parentmodule(moduletag), _cachename)[id]
end

function _ensure_cache_exists!(mod)
    if !isdefined(mod, _cachename)
        mod.eval(quote
            const $_cachename = Dict{Tuple,Expr}()
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
