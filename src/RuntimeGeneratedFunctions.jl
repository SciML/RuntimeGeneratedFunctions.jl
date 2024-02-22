module RuntimeGeneratedFunctions

using ExprTools, Serialization, SHA

export RuntimeGeneratedFunction, @RuntimeGeneratedFunction, drop_expr

const _rgf_docs = """
    @RuntimeGeneratedFunction(function_expression)
    @RuntimeGeneratedFunction(context_module, function_expression, opaque_closures=true)

    RuntimeGeneratedFunction(cache_module, context_module, function_expression; opaque_closures=true)

Construct a function from `function_expression` which can be called immediately
without world age problems. Somewhat like using `eval(function_expression)` and
then calling the resulting function. The differences are:

* The result can be called immediately (immune to world age errors)
* The result is not a named generic function, and doesn't participate in
  generic function dispatch; it's more like a callable method.

You need to use `RuntimeGeneratedFunctions.init(your_module)` a single time at
the top level of `your_module` before any other uses of the macro.

If provided, `context_module` is the module in which symbols within
`function_expression` will be looked up. By default, this is the module in which
`@RuntimeGeneratedFunction` is expanded.

`cache_module` is the module where the expression `code` will be cached. If
`RuntimeGeneratedFunction` is used during precompilation, this must be a module
which is currently being precompiled. Normally this would be set to
`@__MODULE__` using one of the macro constructors.

If `opaque_closures` is `true`, all closures in `function_expression` are
converted to
[opaque closures](https://github.com/JuliaLang/julia/pull/37849#issue-496641229).
This allows for the use of closures and generators inside the generated function,
but may not work in all cases due to slightly different semantics. This feature
requires Julia 1.7.

# Examples
```
RuntimeGeneratedFunctions.init(@__MODULE__) # Required at module top-level

function foo()
    expression = :((x,y)->x+y+1) # May be generated dynamically
    f = @RuntimeGeneratedFunction(expression)
    f(1,2) # May be called immediately
end
```
"""

"$_rgf_docs"
struct RuntimeGeneratedFunction{argnames, cache_tag, context_tag, id, B} <: Function
    body::B
    function RuntimeGeneratedFunction(cache_tag, context_tag, ex; opaque_closures = true)
        def = splitdef(ex)
        args = normalize_args(get(def, :args, Symbol[]))
        body = def[:body]
        if opaque_closures && isdefined(Base, :Experimental) &&
           isdefined(Base.Experimental, Symbol("@opaque"))
            body = closures_to_opaque(body)
        end
        id = expr_to_id(body)
        cached_body = _cache_body(cache_tag, id, body)
        new{Tuple(args), cache_tag, context_tag, id, typeof(cached_body)}(cached_body)
    end

    # For internal use in deserialize() - doesen't check whether the body is in the cache!
    function RuntimeGeneratedFunction{
            argnames,
            cache_tag,
            context_tag,
            id
    }(body) where {
            argnames,
            cache_tag,
            context_tag,
            id
    }
        new{argnames, cache_tag, context_tag, id, typeof(body)}(body)
    end
end

function drop_expr(::RuntimeGeneratedFunction{
        a,
        cache_tag,
        c,
        id
}) where {a, cache_tag, c,
        id}
    # When dropping the reference to the body from an RGF, we need to upgrade
    # from a weak to a strong reference in the cache to prevent the body being
    # GC'd.
    lock(_cache_lock) do
        cache = getfield(parentmodule(cache_tag), _cachename)
        body = cache[id]
        if body isa WeakRef
            cache[id] = body.value
        end
    end
    RuntimeGeneratedFunction{a, cache_tag, c, id}(nothing)
end

function _check_rgf_initialized(mods...)
    for mod in mods
        if !isdefined(mod, _tagname)
            error("""You must use `RuntimeGeneratedFunctions.init(@__MODULE__)` at module
                  top level before using runtime generated functions in $mod""")
        end
    end
end

function RuntimeGeneratedFunction(cache_module::Module, context_module::Module, code;
        opaque_closures = true)
    _check_rgf_initialized(cache_module, context_module)
    RuntimeGeneratedFunction(getfield(cache_module, _tagname),
        getfield(context_module, _tagname),
        code;
        opaque_closures = opaque_closures)
end

"$_rgf_docs"
macro RuntimeGeneratedFunction(code)
    quote
        RuntimeGeneratedFunction(@__MODULE__, @__MODULE__, $(esc(code)))
    end
end
macro RuntimeGeneratedFunction(context_module, code, opaque_closures = true)
    quote
        RuntimeGeneratedFunction(@__MODULE__, $(esc(context_module)), $(esc(code));
            opaque_closures = $(esc(opaque_closures)))
    end
end

function Base.show(io::IO, ::MIME"text/plain",
        f::RuntimeGeneratedFunction{argnames, cache_tag, context_tag, id}) where {
        argnames,
        cache_tag,
        context_tag,
        id
}
    cache_mod = parentmodule(cache_tag)
    context_mod = parentmodule(context_tag)
    func_expr = Expr(:->, Expr(:tuple, argnames...), _lookup_body(cache_tag, id))
    print(io, "RuntimeGeneratedFunction(#=in $cache_mod=#, #=using $context_mod=#, ",
        repr(func_expr), ")")
end

function (f::RuntimeGeneratedFunction)(args::Vararg{Any, N}) where {N}
    generated_callfunc(f, args...)
end

# We'll generate a method of this function in every module which wants to use
# @RuntimeGeneratedFunction
function generated_callfunc end

function generated_callfunc_body(argnames, cache_tag, id, __args)
    setup = (:($(argnames[i]) = @inbounds __args[$i]) for i in 1:length(argnames))
    body = _lookup_body(cache_tag, id)
    @assert body !== nothing
    quote
        $(setup...)
        $(body)
    end
end

### Body caching and lookup
#
# Looking up the body of a RuntimeGeneratedFunction based on the id is a little
# complicated because we want the `id=>body` mapping to survive precompilation.
# This means we need to store the mapping created by a module in that module
# itself.
#
# For that, we need a way to lookup the correct module from an instance of
# RuntimeGeneratedFunction. Modules can't be type parameters, but we can use
# any type which belongs to the module as a proxy "tag" for the module.
#
# (We could even abuse `typeof(__module__.eval)` for the tag, though this is a
# little non-robust to weird special cases like Main.eval being
# Base.MainInclude.eval.)

# It appears we can't use a ReentrantLock here, as contention seems to lead to
# deadlock. Perhaps because it triggers a task switch while compiling the
# @generated function.
_cache_lock = Threads.SpinLock()
_cachename = Symbol("#_RuntimeGeneratedFunctions_cache")
_tagname = Symbol("#_RGF_ModTag")

function _cache_body(cache_tag, id, body)
    lock(_cache_lock) do
        cache = getfield(parentmodule(cache_tag), _cachename)
        # Caching is tricky when `id` is the same for different AST instances:
        #
        # 1. If a function body with the same `id` was cached previously, we need
        # to use that older instance of the body AST as the canonical one
        # rather than `body`. This ensures the lifetime of the body in the
        # cache will always cover the lifetime of all RGFs which share the same
        # `id`.
        #
        # 2. Unless we hold a separate reference to `cache[id].value`, the GC
        # can collect it (causing it to become `nothing`). So root it in a
        # local variable first.
        #
        cached_body = get(cache, id, nothing)
        if !isnothing(cached_body)
            if cached_body isa WeakRef
                # `value` may be nothing here if it was previously cached but GC'd
                cached_body = cached_body.value
            end
        end
        if isnothing(cached_body)
            cached_body = body
            # Use a WeakRef to allow `body` to be garbage collected. (After GC, the
            # cache will still contain an empty entry with key `id`.)
            cache[id] = WeakRef(cached_body)
        end
        return cached_body
    end
end

function _lookup_body(cache_tag, id)
    lock(_cache_lock) do
        cache = getfield(parentmodule(cache_tag), _cachename)
        body = cache[id]
        body isa WeakRef ? body.value : body
    end
end

"""
    RuntimeGeneratedFunctions.init(mod)

Use this at top level to set up your module `mod` before using
`@RuntimeGeneratedFunction`.
"""
function init(mod)
    lock(_cache_lock) do
        if !isdefined(mod, _cachename)
            mod.eval(quote
                const $_cachename = Dict()
                struct $_tagname end

                # We create method of `generated_callfunc` in the user's module
                # so that any global symbols within the body will be looked up
                # in the user's module scope.
                #
                # This is straightforward but clunky.  A neater solution should
                # be to explicitly expand in the user's module and return a
                # CodeInfo from `generated_callfunc`, but it seems we'd need
                # `jl_expand_and_resolve` which doesn't exist until Julia 1.3
                # or so. See:
                #   https://github.com/JuliaLang/julia/pull/32902
                #   https://github.com/NHDaly/StagedFunctions.jl/blob/master/src/StagedFunctions.jl#L30
                @inline @generated function $RuntimeGeneratedFunctions.generated_callfunc(
                        f::$RuntimeGeneratedFunctions.RuntimeGeneratedFunction{
                            argnames,
                            cache_tag,
                            $_tagname,
                            id
                        },
                        __args...) where {
                        argnames,
                        cache_tag,
                        id
                }
                    $RuntimeGeneratedFunctions.generated_callfunc_body(argnames,
                        cache_tag,
                        id, __args)
                end
            end)
        end
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

function expr_to_id(ex)
    io = IOBuffer()
    Serialization.serialize(io, ex)
    return Tuple(reinterpret(UInt32, sha1(take!(io))))
end

@nospecialize

closures_to_opaque(x, _ = nothing) = x
_tconvert(T, x) = Expr(:(::), Expr(:call, GlobalRef(Base, :convert), T, x), T)
function closures_to_opaque(ex::Expr, return_type = nothing)
    head, args = ex.head, ex.args
    fdef = splitdef(ex; throw = false)
    if fdef !== nothing
        body = get(fdef, :body, nothing)
        if haskey(fdef, :rtype)
            body = _tconvert(fdef[:rtype], closures_to_opaque(body, fdef[:rtype]))
            delete!(fdef, :rtype)
        else
            body = closures_to_opaque(body)
        end
        fdef[:head] = :(->)
        fdef[:body] = body
        name = get(fdef, :name, nothing)
        name !== nothing && delete!(fdef, :name)
        _ex = Expr(:opaque_closure, combinedef(fdef))
        # TODO: emit named opaque closure for better stacktraces
        # (ref https://github.com/JuliaLang/julia/pull/40242)
        if name !== nothing
            name isa Symbol ||
                error("Unsupported function definition `$ex` in RuntimeGeneratedFunction.")
            _ex = Expr(:(=), name, _ex)
        end
        return _ex
    elseif head === :generator
        f_args = Expr(:tuple, Any[x.args[1] for x in args[2:end]]...)
        iters = Any[x.args[2] for x in args[2:end]]
        return Expr(:call,
            GlobalRef(Base, :Generator),
            closures_to_opaque(Expr(:(->), f_args, args[1])),
            iters...)
    elseif head === :opaque_closure
        return closures_to_opaque(args[1])
    elseif head === :return && return_type !== nothing
        return Expr(:return,
            _tconvert(return_type, closures_to_opaque(args[1], return_type)))
    end
    return Expr(head, Any[closures_to_opaque(x, return_type) for x in args]...)
end

# We write an explicit serialize() and deserialize() here to manage caching of
# the body on a remote node when using Serialization.jl (in Distributed.jl
# and elsewhere)
function Serialization.serialize(s::AbstractSerializer,
        rgf::RuntimeGeneratedFunction{argnames, cache_tag,
            context_tag, id, B}) where {
        argnames,
        cache_tag,
        context_tag,
        id,
        B
}
    body = _lookup_body(cache_tag, id)
    Serialization.serialize_type(s,
        RuntimeGeneratedFunction{argnames, cache_tag, context_tag,
            id, B})
    serialize(s, body)
end

function Serialization.deserialize(s::AbstractSerializer,
        ::Type{
            <:RuntimeGeneratedFunction{argnames, cache_tag,
            context_tag, id, B}}) where {
        argnames,
        cache_tag,
        context_tag,
        id,
        B
}
    body = deserialize(s)
    cached_body = _cache_body(cache_tag, id, body)
    f = RuntimeGeneratedFunction{argnames, cache_tag, context_tag, id}(cached_body)
    B === Nothing ? drop_expr(f) : f
end

@specialize

end
