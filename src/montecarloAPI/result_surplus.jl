# Surplus

mutable struct MCASurplusAccumulator <: ResultAccumulator{MonteCarloAPI,Surplus}

    # Cross-simulation surplus mean/variances
    surplus_period::Vector{MeanVariance}
    surplus_regionperiod::Matrix{MeanVariance}

end

function merge!(
    x::MCASurplusAccumulator, y::MCASurplusAccumulator
)

    foreach(merge!, x.surplus_period, y.surplus_period)
    foreach(merge!, x.surplus_regionperiod, y.surplus_regionperiod)

    return

end

accumulatortype(::MonteCarloAPI, ::Surplus) = MCASurplusAccumulator

function accumulator(
    sys::SystemModel{N}, ::MonteCarloAPI, ::Surplus
) where {N}

    nregions = length(sys.regions)

    surplus_period = [meanvariance() for _ in 1:N]
    surplus_regionperiod = [meanvariance() for _ in 1:nregions, _ in 1:N]

    return MCASurplusAccumulator(
        surplus_period, surplus_regionperiod)

end

function record!(
    acc::MCASurplusAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    totalsurplus = 0
    edges = problem.fp.edges

    for (r, e_idx) in enumerate(problem.region_unused_edges)

        regionsurplus = edges[e_idx].flow

        for s in system.region_stor_idxs[r]
            se_idx = problem.storage_dischargeunused_edges[s]
            regionsurplus += edges[se_idx].flow
        end

        for gs in system.region_genstor_idxs[r]

            gse_discharge_idx = problem.genstorage_dischargeunused_edges[gs]
            gse_inflow_idx = problem.genstorage_inflowunused_edges[gs]

            grid_limit = system.generatorstorages.gridinjection_capacity[gs, t]
            total_unused = edges[gse_discharge_idx].flow + edges[gse_inflow_idx].flow

            regionsurplus += min(grid_limit, total_unused)

        end

        fit!(acc.surplus_regionperiod[r,t], regionsurplus)
        totalsurplus += regionsurplus

    end

    fit!(acc.surplus_period[t], totalsurplus)

    return

end

reset!(acc::MCASurplusAccumulator, sampleid::Int) = nothing

function finalize(
    acc::MCASurplusAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    _, period_std = mean_std(acc.surplus_period)
    regionperiod_mean, regionperiod_std = mean_std(acc.surplus_regionperiod)

    nsamples = first(first(acc.surplus_period).stats).n

    return SurplusResult{N,L,T,P}(
        nsamples, system.regions.names, system.timestamps,
        regionperiod_mean, period_std, regionperiod_std)

end

# SurplusSamples

struct MCASurplusSamplesAccumulator <:
    ResultAccumulator{MonteCarloAPI,SurplusSamples}

    surplus::Array{Int,3}

end

function merge!(
    x::MCASurplusSamplesAccumulator, y::MCASurplusSamplesAccumulator
)

    x.surplus .+= y.surplus
    return

end

accumulatortype(::MonteCarloAPI, ::SurplusSamples) = MCASurplusSamplesAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::MonteCarloAPI, ::SurplusSamples
) where {N}

    nregions = length(sys.regions)
    surplus = zeros(Int, nregions, N, simspec.nsamples)

    return MCASurplusSamplesAccumulator(surplus)

end

function record!(
    acc::MCASurplusSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    for (r, e) in enumerate(problem.region_unused_edges)

        regionsurplus = problem.fp.edges[e].flow

        for s in system.region_stor_idxs[r]
            se_idx = problem.storage_dischargeunused_edges[s]
            regionsurplus += edges[se_idx].flow
        end

        for gs in system.region_genstor_idxs[r]

            gse_discharge_idx = problem.genstorage_dischargeunused_edges[gs]
            gse_inflow_idx = problem.genstorage_inflowunused_edges[gs]

            grid_limit = system.generatorstorages.gridinjection_capacity[gs, t]
            total_unused = edges[gse_discharge_idx].flow + edges[gse_inflow_idx].flow

            regionsurplus += min(grid_limit, total_unused)

        end

        acc.surplus[r, t, sampleid] = regionsurplus

    end

    return

end

reset!(acc::MCASurplusSamplesAccumulator, sampleid::Int) = nothing

function finalize(
    acc::MCASurplusSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return SurplusSamplesResult{N,L,T,P}(
        system.regions.names, system.timestamps, acc.surplus)

end
