module RuntimeGeneratedFunctions

using ExprTools

const function_cache = Dict{UInt64,Expr}()
struct RuntimeGeneratedFunction{uuid,argnames}
    function RuntimeGeneratedFunction(ex)
        def = splitdef(ex)
        args, body = normalize_args(def[:args]), def[:body]
        uuid = hash(body)
        function_cache[uuid] = body
        new{uuid,Tuple(args)}()
    end
end
(f::RuntimeGeneratedFunction)(args::Vararg{Any,N}) where N = generated_callfunc(f, args...)

@inline @generated function generated_callfunc(f::RuntimeGeneratedFunction{uuid,argnames},__args...) where {uuid,argnames}
    setup = (:($(argnames[i]) = @inbounds __args[$i]) for i in 1:length(argnames))
    quote
        $(setup...)
        $(function_cache[uuid])
    end
end

export RuntimeGeneratedFunction


###
### Utilities
###
normalize_args(args::Vector) = map(normalize_args, args)
normalize_args(arg::Symbol) = arg
function normalize_args(arg::Expr)
    arg.head === :(::) || error("argument malformed. Got $arg")
    arg.args[1]
end

end
