# GeneratorAvailability

struct AMCGenAvailabilityAccumulator <:
    ResultAccumulator{AbstractMC,GeneratorAvailability}

    available::Array{Bool,3}

end

function merge!(
    x::AMCGenAvailabilityAccumulator, y::AMCGenAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::AbstractMC, ::GeneratorAvailability) = AMCGenAvailabilityAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::AbstractMC, ::GeneratorAvailability
) where {N}

    ngens = length(sys.generators)
    available = zeros(Bool, ngens, N, simspec.nsamples)

    return AMCGenAvailabilityAccumulator(available)

end

function record!(
    acc::AMCGenAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::AbstractDispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.available[:, t, sampleid] .= state.gens_available
    return

end

reset!(acc::AMCGenAvailabilityAccumulator, sampleid::Int) = nothing

function finalize(
    acc::AMCGenAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return GeneratorAvailabilityResult{N,L,T}(
        system.generators.names, system.timestamps, acc.available)

end

# StorageAvailability

struct AMCStorAvailabilityAccumulator <:
    ResultAccumulator{AbstractMC,StorageAvailability}

    available::Array{Bool,3}

end

function merge!(
    x::AMCStorAvailabilityAccumulator, y::AMCStorAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::AbstractMC, ::StorageAvailability) = AMCStorAvailabilityAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::AbstractMC, ::StorageAvailability
) where {N}

    nstors = length(sys.storages)
    available = zeros(Bool, nstors, N, simspec.nsamples)

    return AMCStorAvailabilityAccumulator(available)

end

function record!(
    acc::AMCStorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::AbstractDispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.available[:, t, sampleid] .= state.stors_available
    return

end

reset!(acc::AMCStorAvailabilityAccumulator, sampleid::Int) = nothing

function finalize(
    acc::AMCStorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return StorageAvailabilityResult{N,L,T}(
        system.storages.names, system.timestamps, acc.available)

end

# GeneratorStorageAvailability

struct AMCGenStorAvailabilityAccumulator <:
    ResultAccumulator{AbstractMC,GeneratorStorageAvailability}

    available::Array{Bool,3}

end

function merge!(
    x::AMCGenStorAvailabilityAccumulator, y::AMCGenStorAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::AbstractMC, ::GeneratorStorageAvailability) = AMCGenStorAvailabilityAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::AbstractMC, ::GeneratorStorageAvailability
) where {N}

    ngenstors = length(sys.generatorstorages)
    available = zeros(Bool, ngenstors, N, simspec.nsamples)

    return AMCGenStorAvailabilityAccumulator(available)

end

function record!(
    acc::AMCGenStorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::AbstractDispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.available[:, t, sampleid] .= state.genstors_available
    return

end

reset!(acc::AMCGenStorAvailabilityAccumulator, sampleid::Int) = nothing

function finalize(
    acc::AMCGenStorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return GeneratorStorageAvailabilityResult{N,L,T}(
        system.generatorstorages.names, system.timestamps, acc.available)

end

# LineAvailability

struct AMCLineAvailabilityAccumulator <:
    ResultAccumulator{AbstractMC,LineAvailability}

    available::Array{Bool,3}

end

function merge!(
    x::AMCLineAvailabilityAccumulator, y::AMCLineAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::AbstractMC, ::LineAvailability) = AMCLineAvailabilityAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::AbstractMC, ::LineAvailability
) where {N}

    nlines = length(sys.lines)
    available = zeros(Bool, nlines, N, simspec.nsamples)

    return AMCLineAvailabilityAccumulator(available)

end

function record!(
    acc::AMCLineAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::AbstractDispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.available[:, t, sampleid] .= state.lines_available
    return

end

reset!(acc::AMCLineAvailabilityAccumulator, sampleid::Int) = nothing

function finalize(
    acc::AMCLineAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return LineAvailabilityResult{N,L,T}(
        system.lines.names, system.timestamps, acc.available)

end
