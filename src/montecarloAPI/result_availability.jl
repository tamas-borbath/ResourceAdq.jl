# GeneratorAvailability

struct MCAGenAvailabilityAccumulator <:
    ResultAccumulator{MonteCarloAPI,GeneratorAvailability}

    available::Array{Bool,3}

end

function merge!(
    x::MCAGenAvailabilityAccumulator, y::MCAGenAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::MonteCarloAPI, ::GeneratorAvailability) = MCAGenAvailabilityAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::MonteCarloAPI, ::GeneratorAvailability
) where {N}

    ngens = length(sys.generators)
    available = zeros(Bool, ngens, N, simspec.nsamples)

    return MCAGenAvailabilityAccumulator(available)

end

function record!(
    acc::MCAGenAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.available[:, t, sampleid] .= state.gens_available
    return

end

reset!(acc::MCAGenAvailabilityAccumulator, sampleid::Int) = nothing

function finalize(
    acc::MCAGenAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return GeneratorAvailabilityResult{N,L,T}(
        system.generators.names, system.timestamps, acc.available)

end

# StorageAvailability

struct MCAStorAvailabilityAccumulator <:
    ResultAccumulator{MonteCarloAPI,StorageAvailability}

    available::Array{Bool,3}

end

function merge!(
    x::MCAStorAvailabilityAccumulator, y::MCAStorAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::MonteCarloAPI, ::StorageAvailability) = MCAStorAvailabilityAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::MonteCarloAPI, ::StorageAvailability
) where {N}

    nstors = length(sys.storages)
    available = zeros(Bool, nstors, N, simspec.nsamples)

    return MCAStorAvailabilityAccumulator(available)

end

function record!(
    acc::MCAStorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.available[:, t, sampleid] .= state.stors_available
    return

end

reset!(acc::MCAStorAvailabilityAccumulator, sampleid::Int) = nothing

function finalize(
    acc::MCAStorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return StorageAvailabilityResult{N,L,T}(
        system.storages.names, system.timestamps, acc.available)

end

# GeneratorStorageAvailability

struct MCAGenStorAvailabilityAccumulator <:
    ResultAccumulator{MonteCarloAPI,GeneratorStorageAvailability}

    available::Array{Bool,3}

end

function merge!(
    x::MCAGenStorAvailabilityAccumulator, y::MCAGenStorAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::MonteCarloAPI, ::GeneratorStorageAvailability) = MCAGenStorAvailabilityAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::MonteCarloAPI, ::GeneratorStorageAvailability
) where {N}

    ngenstors = length(sys.generatorstorages)
    available = zeros(Bool, ngenstors, N, simspec.nsamples)

    return MCAGenStorAvailabilityAccumulator(available)

end

function record!(
    acc::MCAGenStorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.available[:, t, sampleid] .= state.genstors_available
    return

end

reset!(acc::MCAGenStorAvailabilityAccumulator, sampleid::Int) = nothing

function finalize(
    acc::MCAGenStorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return GeneratorStorageAvailabilityResult{N,L,T}(
        system.generatorstorages.names, system.timestamps, acc.available)

end

# LineAvailability

struct MCALineAvailabilityAccumulator <:
    ResultAccumulator{MonteCarloAPI,LineAvailability}

    available::Array{Bool,3}

end

function merge!(
    x::MCALineAvailabilityAccumulator, y::MCALineAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::MonteCarloAPI, ::LineAvailability) = MCALineAvailabilityAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::MonteCarloAPI, ::LineAvailability
) where {N}

    nlines = length(sys.lines)
    available = zeros(Bool, nlines, N, simspec.nsamples)

    return MCALineAvailabilityAccumulator(available)

end

function record!(
    acc::MCALineAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.available[:, t, sampleid] .= state.lines_available
    return

end

reset!(acc::MCALineAvailabilityAccumulator, sampleid::Int) = nothing

function finalize(
    acc::MCALineAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return LineAvailabilityResult{N,L,T}(
        system.lines.names, system.timestamps, acc.available)

end
