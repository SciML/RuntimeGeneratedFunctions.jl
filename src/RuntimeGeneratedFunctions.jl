module RuntimeGeneratedFunctions

using ExprTools: ExprTools, combinedef, splitdef
using SHA: SHA, SHA1_CTX, update!
using Serialization: Serialization, AbstractSerializer, deserialize, serialize

export RuntimeGeneratedFunction, @RuntimeGeneratedFunction, drop_expr

# `init` and `get_expression` are documented, downstream-relied-on entry points
# (see README and the `@autodocs` API page) that are intentionally not exported
# to keep them namespaced under `RuntimeGeneratedFunctions.`. Declare them public
# so downstream packages can qualify-access them and pass ExplicitImports'
# `check_all_qualified_accesses_are_public`.
@static if VERSION >= v"1.11"
    eval(Expr(:public, :init, :get_expression))
end

"""
    RuntimeGeneratedFunction(cache_module, context_module, function_expression;
        opaque_closures = true)

A callable function compiled from `function_expression` without a world-age
barrier. A `RuntimeGeneratedFunction` is a `Function`, so generic code that
accepts and invokes a `Function` can use it. It is not a named generic function:
it represents one callable method and does not participate in method dispatch.

# Arguments

- `cache_module::Module`: module that owns the cached expression. It must have
  been initialized with [`init`](@ref). During precompilation, pass the module
  currently being precompiled so the cache survives precompilation.
- `context_module::Module`: module in which global names in
  `function_expression` are resolved. It must have been initialized with
  [`init`](@ref).
- `function_expression::Expr`: an anonymous-function or function-definition
  expression whose body becomes the callable function.

# Keywords

- `opaque_closures = true`: convert closures and generators in
  `function_expression` to Julia opaque closures. This permits closures in the
  generated body, with Julia's opaque-closure semantics.

# Fields

- `body`: cached body expression while it is retained, or `nothing` after
  [`drop_expr`](@ref). The function remains callable after dropping its local
  expression reference because the cache owns the body.

# Serialization

`Serialization.serialize` preserves a runtime-generated function, including
after [`drop_expr`](@ref). A dropped function's expression is recovered from its
cache while serializing and remains dropped after deserialization.

# Examples

```julia
RuntimeGeneratedFunctions.init(@__MODULE__)
square = RuntimeGeneratedFunction(@__MODULE__, @__MODULE__, :(x -> x^2))
square(3)
```
"""
struct RuntimeGeneratedFunction{argnames, cache_tag, context_tag, id, B} <: Function
    body::B
    function RuntimeGeneratedFunction(cache_tag, context_tag, ex; opaque_closures = true)
        def = splitdef(ex)
        args = normalize_args(get(def, :args, Symbol[]))
        body = def[:body]
        if opaque_closures
            body = closures_to_opaque(body)
        end
        id = expr_to_id(body)
        cached_body = _cache_body(cache_tag, id, body)
        return new{Tuple(args), cache_tag, context_tag, id, typeof(cached_body)}(cached_body)
    end

    # For internal use in deserialize() - doesn't check whether the body is in the cache!
    function RuntimeGeneratedFunction{
            argnames,
            cache_tag,
            context_tag,
            id,
        }(body) where {
            argnames,
            cache_tag,
            context_tag,
            id,
        }
        return new{argnames, cache_tag, context_tag, id, typeof(body)}(body)
    end
end

_argnames(::RuntimeGeneratedFunction{a}) where {a} = a
_cache_tag(::RuntimeGeneratedFunction{a, ct}) where {a, ct} = ct
_context_tag(::RuntimeGeneratedFunction{a, ct, cx}) where {a, ct, cx} = cx
_id(::RuntimeGeneratedFunction{a, ct, cx, id}) where {a, ct, cx, id} = id

"""
    drop_expr(rgf::RuntimeGeneratedFunction)

Return a copy of `rgf` that does not retain its function body expression.
This allows the expression AST to be garbage collected while keeping the
function callable.

# Arguments

- `rgf::RuntimeGeneratedFunction`: generated function whose retained expression
  should be released.

# Returns

- A `RuntimeGeneratedFunction` with `body === nothing`. It has the same callable
  behavior as `rgf` while its cache entry remains available.

The expression can still be retrieved later using [`get_expression`](@ref) as long
as at least one `RuntimeGeneratedFunction` with the same body exists.

# Examples
```julia
ex = :((x) -> x^2)
rgf = @RuntimeGeneratedFunction(ex)
rgf_dropped = drop_expr(rgf)
rgf_dropped(2)  # Still works, returns 4
```
"""
function drop_expr(@nospecialize(rgf::RuntimeGeneratedFunction))
    # When dropping the reference to the body from an RGF, we need to upgrade
    # from a weak to a strong reference in the cache to prevent the body being
    # GC'd.
    a, ct, cx, id = _argnames(rgf), _cache_tag(rgf), _context_tag(rgf), _id(rgf)
    @lock _cache_lock begin
        cache = getfield(parentmodule(ct), _cachename)
        body = _cache_getindex(cache, id)
        if body isa WeakRef
            _cache_setindex!(cache, id, body.value)
        end
    end
    return RuntimeGeneratedFunction{a, ct, cx, id}(nothing)
end

function _check_rgf_initialized(mods...)
    for mod in mods
        if !isdefined(mod, _tagname)
            error(
                """You must use `RuntimeGeneratedFunctions.init(@__MODULE__)` at module
                top level before using runtime generated functions in $mod"""
            )
        end
    end
    return
end

function RuntimeGeneratedFunction(
        cache_module::Module, context_module::Module, code;
        opaque_closures = true
    )
    _check_rgf_initialized(cache_module, context_module)
    return RuntimeGeneratedFunction(
        getfield(cache_module, _tagname),
        getfield(context_module, _tagname),
        code;
        opaque_closures = opaque_closures
    )
end

"""
    @RuntimeGeneratedFunction(function_expression)
    @RuntimeGeneratedFunction(context_module, function_expression,
        opaque_closures = true)

Construct a [`RuntimeGeneratedFunction`](@ref) from a function expression using
the calling module as its cache module. Call [`init`](@ref) at the top level of
that module before expanding this macro.

# Arguments

- `function_expression::Expr`: an anonymous-function or function-definition
  expression to compile.
- `context_module::Module`: optional module in which global names in
  `function_expression` are resolved. By default, names resolve in the calling
  module.

# Keywords

- `opaque_closures = true`: convert closures and generators in the expression to
  Julia opaque closures.

# Examples

```julia
RuntimeGeneratedFunctions.init(@__MODULE__)
increment = @RuntimeGeneratedFunction(:(x -> x + 1))
increment(2)
```
"""
macro RuntimeGeneratedFunction(code)
    return quote
        RuntimeGeneratedFunction(@__MODULE__, @__MODULE__, $(esc(code)))
    end
end
macro RuntimeGeneratedFunction(context_module, code, opaque_closures = true)
    return quote
        RuntimeGeneratedFunction(
            @__MODULE__, $(esc(context_module)), $(esc(code));
            opaque_closures = $(esc(opaque_closures))
        )
    end
end

function Base.show(
        io::IO, ::MIME"text/plain",
        f::RuntimeGeneratedFunction{argnames, cache_tag, context_tag, id}
    ) where {
        argnames,
        cache_tag,
        context_tag,
        id,
    }
    cache_mod = parentmodule(cache_tag)
    context_mod = parentmodule(context_tag)
    func_expr = Expr(:->, Expr(:tuple, argnames...), _lookup_body(cache_tag, id))
    return print(
        io, "RuntimeGeneratedFunction(#=in $cache_mod=#, #=using $context_mod=#, ",
        repr(func_expr), ")"
    )
end

function (f::RuntimeGeneratedFunction)(args::Vararg{Any, N}) where {N}
    return generated_callfunc(f, args...)
end

# We'll generate a method of this function in every module which wants to use
# @RuntimeGeneratedFunction
function generated_callfunc end

function generated_callfunc_body(argnames, cache_tag, id, __args)
    setup = (:($(argnames[i]) = @inbounds __args[$i]) for i in 1:length(argnames))
    body = _lookup_body(cache_tag, id)
    @assert body !== nothing
    return quote
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

# `_lookup_body` runs inside the `generated_callfunc` expansion, i.e. while the
# calling thread holds Julia's compiler lock, so it must not block: a writer
# holding `_cache_lock` can itself end up waiting on that compiler lock, since
# inserting into the cache may compile a specialization. (Yielding instead of
# blocking is no better, which is why a ReentrantLock deadlocks here too.)
#
# Reads are therefore lock-free: the cache is a stack of `Dict`s, newest first,
# none of which is mutated once published, so a reader takes the stack with one
# atomic load and probes the levels in order. Writers still serialize on
# `_cache_lock` and publish a replacement stack.
#
# Copying the whole map per insert would be O(n^2) for a package that generates
# thousands of functions, so a level is merged into the one below it only once
# it reaches half that level's size (the logarithmic method). Level sizes then
# more than double going down the stack, bounding both the reader's probes and
# the entries an insert copies at O(log n).
mutable struct _BodyCache
    @atomic levels::Vector{Dict{Any, Any}}
end
_BodyCache() = _BodyCache(Dict{Any, Any}[])

struct _NotFound end

function _cache_get(cache::_BodyCache, id)
    for level in (@atomic :acquire cache.levels)
        value = get(level, id, _NotFound())
        value isa _NotFound || return value
    end
    return _NotFound()
end

function _cache_getindex(cache::_BodyCache, id)
    value = _cache_get(cache, id)
    value isa _NotFound && throw(KeyError(id))
    return value
end

# Caller must hold `_cache_lock`.
function _cache_setindex!(cache::_BodyCache, id, value)
    levels = copy(@atomic :monotonic cache.levels)
    pushfirst!(levels, Dict{Any, Any}(id => value))
    while length(levels) > 1 && 2 * length(levels[1]) >= length(levels[2])
        # The newer level wins, so that an updated entry shadows the stale one.
        merged = merge(levels[2], levels[1])
        popfirst!(levels)
        levels[1] = merged
    end
    @atomic :release cache.levels = levels
    return value
end

_cache_lock = Threads.SpinLock()
_cachename = Symbol("#_RuntimeGeneratedFunctions_cache")
_tagname = Symbol("#_RGF_ModTag")

function _cache_body(cache_tag, id, body)
    return lock(_cache_lock) do
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
        cached_body = _cache_get(cache, id)
        if cached_body isa _NotFound
            cached_body = nothing
        elseif cached_body isa WeakRef
            # `value` may be nothing here if it was previously cached but GC'd
            cached_body = cached_body.value
        end
        if isnothing(cached_body)
            cached_body = body
            # Use a WeakRef to allow `body` to be garbage collected. (After GC, the
            # cache will still contain an empty entry with key `id`.)
            _cache_setindex!(cache, id, WeakRef(cached_body))
        end
        return cached_body
    end
end

function _lookup_body(cache_tag, id)
    cache = getfield(parentmodule(cache_tag), _cachename)
    body = _cache_getindex(cache, id)
    return body isa WeakRef ? body.value : body
end

"""
    RuntimeGeneratedFunctions.init(mod)

Initialize `mod` for runtime-generated functions.

# Arguments

- `mod::Module`: module that will cache generated expression bodies and own the
  generated call method.

# Rules

Call `init` once at module top level before using
[`@RuntimeGeneratedFunction`](@ref) in `mod`, or before passing `mod` as either
the cache or context module to [`RuntimeGeneratedFunction`](@ref). Repeated calls
are idempotent. Do not call it from a local scope: it defines a generated method
in `mod` so that global names resolve in that module.

# Examples

```julia
module GeneratedFunctionsExample
using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)
end
```
"""
function init(mod)
    return lock(_cache_lock) do
        if !isdefined(mod, _cachename)
            mod.eval(
                quote
                    const $_cachename = $RuntimeGeneratedFunctions._BodyCache()
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
                                id,
                            },
                            __args...
                        ) where {
                            argnames,
                            cache_tag,
                            id,
                        }
                        return $RuntimeGeneratedFunctions.generated_callfunc_body(
                            argnames,
                            cache_tag,
                            id, __args
                        )
                    end
                end
            )
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
    return arg.args[1]
end

function expr_to_id(ex)
    ctx = SHA1_CTX()
    _hash_expr!(ctx, ex)
    return Tuple(reinterpret(UInt32, SHA.digest!(ctx)))
end

_hash_expr!(ctx, ::LineNumberNode) = nothing
const _OPEN = UInt8['(']
const _SEP = UInt8[',']
const _CLOSE = UInt8[')']

function _hash_expr!(ctx, ex::Expr)
    update!(ctx, _OPEN)
    update!(ctx, Vector{UInt8}(string(ex.head)))
    for arg in ex.args
        update!(ctx, _SEP)
        _hash_expr!(ctx, arg)
    end
    return update!(ctx, _CLOSE)
end
_hash_expr!(ctx, ex) = update!(ctx, Vector{UInt8}(string(ex)))

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
        opaque = Expr(:., Expr(:., :Base, QuoteNode(:Experimental)), QuoteNode(Symbol("@opaque")))
        _ex = Expr(:macrocall, opaque, LineNumberNode(0), combinedef(fdef))
        # TODO: emit named opaque closure for better stacktraces
        # (ref https://github.com/JuliaLang/julia/pull/40242)
        if name !== nothing
            name isa Symbol ||
                error("Unsupported function definition `$ex` in RuntimeGeneratedFunction.")
            _ex = Expr(:(=), name, _ex)
        end
        return _ex
    elseif head === :generator
        f_args = Expr(:tuple)
        f_args.args = Any[x.args[1] for x in args[2:end]]
        iters = Any[x.args[2] for x in args[2:end]]
        new_ex = Expr(
            :call, GlobalRef(Base, :Generator),
            closures_to_opaque(Expr(:(->), f_args, args[1]))
        )
        append!(new_ex.args, iters)
        return new_ex
    elseif head === :opaque_closure
        return closures_to_opaque(args[1])
    elseif head === :return && return_type !== nothing
        return Expr(
            :return,
            _tconvert(return_type, closures_to_opaque(args[1], return_type))
        )
    end
    new_ex = Expr(head)
    new_ex.args = Any[closures_to_opaque(x, return_type) for x in args]
    return new_ex
end

"""
    get_expression(rgf::RuntimeGeneratedFunction)

Retrieve the function expression from a `RuntimeGeneratedFunction`.

# Arguments

- `rgf::RuntimeGeneratedFunction`: generated function whose source expression is
  requested.

# Returns

- An anonymous-function `Expr` containing the normalized argument names and the
  cached body.

This works even if [`drop_expr`](@ref) has been called on the function, as long as
the expression is still in the cache (i.e., at least one `RuntimeGeneratedFunction`
with the same body exists).

# Examples
```julia
ex = :((x) -> x^2)
rgf = @RuntimeGeneratedFunction(ex)
RuntimeGeneratedFunctions.get_expression(rgf)
# Returns: :((x,) -> x ^ 2)
```
"""
function get_expression(
        rgf::RuntimeGeneratedFunction{
            argnames, cache_tag,
            context_tag, id, B,
        }
    ) where {
        argnames,
        cache_tag,
        context_tag,
        id,
        B,
    }
    return func_expr = Expr(:->, Expr(:tuple, argnames...), _lookup_body(cache_tag, id))
end

struct _SerializedRuntimeGeneratedFunction{argnames, cache_tag, context_tag, id, B}
    body::B
end

function Serialization.serialize(
        s::AbstractSerializer,
        ::RuntimeGeneratedFunction{
            argnames, cache_tag,
            context_tag, id, Nothing,
        }
    ) where {
        argnames,
        cache_tag,
        context_tag,
        id,
    }
    body = _lookup_body(cache_tag, id)
    proxy = _SerializedRuntimeGeneratedFunction{
        argnames, cache_tag, context_tag, id, typeof(body),
    }(body)
    return serialize(s, proxy)
end

function Serialization.deserialize(
        s::AbstractSerializer,
        ::Type{
            _SerializedRuntimeGeneratedFunction{
                argnames, cache_tag,
                context_tag, id, B,
            },
        }
    ) where {
        argnames,
        cache_tag,
        context_tag,
        id,
        B,
    }
    body = deserialize(s)
    cached_body = _cache_body(cache_tag, id, body)
    return drop_expr(
        RuntimeGeneratedFunction{argnames, cache_tag, context_tag, id}(cached_body)
    )
end

function Serialization.deserialize(
        s::AbstractSerializer,
        ::Type{
            <:RuntimeGeneratedFunction{
                argnames, cache_tag,
                context_tag, id, B,
            },
        }
    ) where {
        argnames,
        cache_tag,
        context_tag,
        id,
        B,
    }
    body = deserialize(s)
    B === Nothing && throw(
        ArgumentError(
            "cannot deserialize a dropped RuntimeGeneratedFunction; serialize it before calling drop_expr"
        )
    )
    cached_body = _cache_body(cache_tag, id, body)
    f = RuntimeGeneratedFunction{argnames, cache_tag, context_tag, id}(cached_body)
    return f
end

# Match Julia functions: runtime-generated functions are immutable callable values.
Base.deepcopy_internal(f::RuntimeGeneratedFunction, ::IdDict) = f

@specialize

using PrecompileTools: @compile_workload, @setup_workload

@setup_workload begin
    init(@__MODULE__)
    @compile_workload begin
        increment = RuntimeGeneratedFunction(@__MODULE__, @__MODULE__, :(x -> x + 1))
        increment(41)
        get_expression(increment)
        drop_expr(increment)
    end
end

end
