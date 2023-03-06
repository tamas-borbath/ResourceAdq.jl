abstract type LineConstraintType
 end # The name has to match the internal jum name of the constraint indexed by lines 
struct LineLimit_forward <: LineConstraintType
 end
struct LineLimit_backward <: LineConstraintType
 end
unitsymbol(T::Type{<:LineConstraintType}) = Symbol(T)

struct LineDual{T<:LineConstraintType} <: ResultSpec end
abstract type AbstractLineDualResult{N,L,T} <: Result{N,L,T} end

# Colon indexing

getindex(x::AbstractLineDualResult, ::Colon) =
    getindex.(x, x.lines)

getindex(x::AbstractLineDualResult, ::Colon, t::ZonedDateTime) =
    getindex.(x, x.lines, t)

getindex(x::AbstractLineDualResult, i::String, ::Colon) =
    getindex.(x, i, x.timestamps)

getindex(x::AbstractLineDualResult, ::Colon, ::Colon) =
    getindex.(x, x.lines, permutedims(x.timestamps))

# Sample-averaged LineDual data

struct LineDualResult{N,L,T<:Period,P<:PowerUnit} <: AbstractLineDualResult{N,L,T}
    Constraint_Type :: Symbol
    nsamples::Union{Int64,Nothing}
    lines::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    LineDual_mean::Vector{Float64}
    LineDual_std::Vector{Float64}

    LineDual_period_mean::Matrix{Float64}
    LineDual_period_std::Matrix{Float64}

    #LineDual_line_std::Vector{Float64}
    #LineDual_lineperiod_std::Matrix{Float64}

end
#=
function getindex(x::LineDualResult, i::Pair{<:AbstractString,<:AbstractString})
    i_i, reverse = findfirstunique_directional(x.lines, i)
    LineDual = mean(view(x.LineDual_mean, i_i, :))
    return reverse ? -LineDual : LineDual, x.LineDual_line_std[i_i]
end

function getindex(x::LineDualResult, i::Pair{<:AbstractString,<:AbstractString}, t::ZonedDateTime)
    i_i, reverse = findfirstunique_directional(x.lines, i)
    i_t = findfirstunique(x.timestamps, t)
    LineDual = x.LineDual_mean[i_i, i_t]
    return reverse ? -LineDual : LineDual, x.LineDual_lineperiod_std[i_i, i_t]
end
=#
# Full LineDual data

struct LineDualSamples{T<:LineConstraintType} <: ResultSpec end

struct LineDualSamplesResult{N,L,T<:Period,P<:PowerUnit} <: AbstractLineDualResult{N,L,T}
    Constraint_Type :: Symbol
    lines::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    LineDual::Array{Float64,3}

end

function getindex(x::LineDualSamplesResult, i::AbstractString)
    i_i = findfirstunique(x.lines, i)
    LineDual = vec(mean(view(x.LineDual, i_i, :, :), dims=1))
    return LineDual
end


function getindex(x::LineDualSamplesResult, i::AbstractString, t::ZonedDateTime)
    i_i = findfirstunique(x.lines, i)
    i_t = findfirstunique(x.timestamps, t)
    LineDual = vec(x.LineDual[i_i, i_t, :])
    return LineDual
end
