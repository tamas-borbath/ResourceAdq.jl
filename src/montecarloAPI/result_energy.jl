# StorageEnergy

mutable struct MCAStorageEnergyAccumulator <:
    ResultAccumulator{MonteCarloAPI,StorageEnergy}

    # Cross-simulation energy mean/variances
    energy_period::Vector{MeanVariance}
    energy_storageperiod::Matrix{MeanVariance}

end

function merge!(
    x::MCAStorageEnergyAccumulator, y::MCAStorageEnergyAccumulator
)

    foreach(merge!, x.energy_period, y.energy_period)
    foreach(merge!, x.energy_storageperiod, y.energy_storageperiod)

    return

end

accumulatortype(::MonteCarloAPI, ::StorageEnergy) = MCAStorageEnergyAccumulator

function accumulator(
    sys::SystemModel{N}, ::MonteCarloAPI, ::StorageEnergy
) where {N}

    nstorages = length(sys.storages)

    energy_period = [meanvariance() for _ in 1:N]
    energy_storageperiod = [meanvariance() for _ in 1:nstorages, _ in 1:N]

    return MCAStorageEnergyAccumulator(
        energy_period, energy_storageperiod)

end

function record!(
    acc::MCAStorageEnergyAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    totalenergy = 0
    nstorages = length(system.storages)

    for s in 1:nstorages

        storageenergy = state.stors_energy[s]
        fit!(acc.energy_storageperiod[s,t], storageenergy)
        totalenergy += storageenergy

    end

    fit!(acc.energy_period[t], totalenergy)

    return

end

reset!(acc::MCAStorageEnergyAccumulator, sampleid::Int) = nothing

function finalize(
    acc::MCAStorageEnergyAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    _, period_std = mean_std(acc.energy_period)
    storageperiod_mean, storageperiod_std = mean_std(acc.energy_storageperiod)

    nsamples = first(first(acc.energy_period).stats).n

    return StorageEnergyResult{N,L,T,E}(
        nsamples, system.storages.names, system.timestamps,
        storageperiod_mean, period_std, storageperiod_std)

end

# GeneratorStorageEnergy

mutable struct MCAGenStorageEnergyAccumulator <:
    ResultAccumulator{MonteCarloAPI,GeneratorStorageEnergy}

    # Cross-simulation energy mean/variances
    energy_period::Vector{MeanVariance}
    energy_genstorperiod::Matrix{MeanVariance}

end

function merge!(
    x::MCAGenStorageEnergyAccumulator, y::MCAGenStorageEnergyAccumulator
)

    foreach(merge!, x.energy_period, y.energy_period)
    foreach(merge!, x.energy_genstorperiod, y.energy_genstorperiod)

    return

end

accumulatortype(::MonteCarloAPI, ::GeneratorStorageEnergy) =
    MCAGenStorageEnergyAccumulator

function accumulator(
    sys::SystemModel{N}, ::MonteCarloAPI, ::GeneratorStorageEnergy
) where {N}

    ngenstors = length(sys.generatorstorages)

    energy_period = [meanvariance() for _ in 1:N]
    energy_genstorperiod = [meanvariance() for _ in 1:ngenstors, _ in 1:N]

    return MCAGenStorageEnergyAccumulator(
        energy_period, energy_genstorperiod)

end

function record!(
    acc::MCAGenStorageEnergyAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    totalenergy = 0
    ngenstors = length(system.generatorstorages)

    for s in 1:ngenstors

        genstorenergy = state.genstors_energy[s]
        fit!(acc.energy_genstorperiod[s,t], genstorenergy)
        totalenergy += genstorenergy

    end

    fit!(acc.energy_period[t], totalenergy)

    return

end

reset!(acc::MCAGenStorageEnergyAccumulator, sampleid::Int) = nothing

function finalize(
    acc::MCAGenStorageEnergyAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    _, period_std = mean_std(acc.energy_period)
    genstorperiod_mean, genstorperiod_std = mean_std(acc.energy_genstorperiod)

    nsamples = first(first(acc.energy_period).stats).n

    return GeneratorStorageEnergyResult{N,L,T,E}(
        nsamples, system.generatorstorages.names, system.timestamps,
        genstorperiod_mean, period_std, genstorperiod_std)

end

# StorageEnergySamples

struct MCAStorageEnergySamplesAccumulator <:
    ResultAccumulator{MonteCarloAPI,StorageEnergySamples}

    energy::Array{Float64,3}

end

function merge!(
    x::MCAStorageEnergySamplesAccumulator, y::MCAStorageEnergySamplesAccumulator
)

    x.energy .+= y.energy
    return

end

accumulatortype(::MonteCarloAPI, ::StorageEnergySamples) =
    MCAStorageEnergySamplesAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::MonteCarloAPI, ::StorageEnergySamples
) where {N}

    nstors = length(sys.storages)
    energy = zeros(Int, nstors, N, simspec.nsamples)

    return MCAStorageEnergySamplesAccumulator(energy)

end

function record!(
    acc::MCAStorageEnergySamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.energy[:, t, sampleid] .= state.stors_energy
    return

end

reset!(acc::MCAStorageEnergySamplesAccumulator, sampleid::Int) = nothing

function finalize(
    acc::MCAStorageEnergySamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return StorageEnergySamplesResult{N,L,T,E}(
        system.storages.names, system.timestamps, acc.energy)

end

# GeneratorStorageEnergySamples

struct MCAGenStorageEnergySamplesAccumulator <:
    ResultAccumulator{MonteCarloAPI,GeneratorStorageEnergySamples}

    energy::Array{Float64,3}

end

function merge!(
    x::MCAGenStorageEnergySamplesAccumulator,
    y::MCAGenStorageEnergySamplesAccumulator
)

    x.energy .+= y.energy
    return

end

accumulatortype(::MonteCarloAPI, ::GeneratorStorageEnergySamples) =
    MCAGenStorageEnergySamplesAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::MonteCarloAPI, ::GeneratorStorageEnergySamples
) where {N}

    ngenstors = length(sys.generatorstorages)
    energy = zeros(Int, ngenstors, N, simspec.nsamples)

    return MCAGenStorageEnergySamplesAccumulator(energy)

end

function record!(
    acc::MCAGenStorageEnergySamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.energy[:, t, sampleid] .= state.genstors_energy
    return

end

reset!(acc::MCAGenStorageEnergySamplesAccumulator, sampleid::Int) = nothing

function finalize(
    acc::MCAGenStorageEnergySamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return GeneratorStorageEnergySamplesResult{N,L,T,E}(
        system.generatorstorages.names, system.timestamps, acc.energy)

end
