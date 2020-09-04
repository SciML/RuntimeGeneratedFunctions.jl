module RuntimeGeneratedFunctions

const function_cache = Dict{UInt64,Expr}()
struct RuntimeGeneratedFunction{uuid,argnames}
    function RuntimeGeneratedFunction(ex)
        uuid = hash(ex.args[2])
        function_cache[uuid] = ex.args[2]
        argnames = (ex.args[1].args[2:end]...,)
        new{uuid,argnames}()
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

end
