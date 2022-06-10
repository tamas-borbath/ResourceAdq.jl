module ResourceAdq

using ParameterJuMP,JuMP, Gurobi
const SOLVER = Gurobi


#using PRAS
import PRAS: SystemModel, SequentialMonteCarlo, Shortfall, GeneratorAvailability, assess
#const _P=PRAS
#Alive?
greet() = print("HelloWorld2")

#Excel interface for models
include("xlsx_io.jl")
export read_XLSX
export write_XLSX


import Base: -, broadcastable, getindex, merge!
import Base.Threads: nthreads, @spawn
#import Dates: DateTime, Period
#import Decimals: Decimal, decimal
#import Distributions: DiscreteNonParametric, probs, support
#import OnlineStatsBase: EqualWeight, fit!, Mean, value, Variance
#import OnlineStats: Series
#import Printf: @sprintf
import Random: AbstractRNG, rand, seed!
import Random123: Philox4x
#import StatsBase: mean, std, stderror
#import TimeZones: ZonedDateTime, @tz_str


import PRAS: -, AbstractAssets, Lines, Generators
import PRAS.ResourceAdequacy: SimulationSpec, FlowProblem, ResultSpec,  ResultAccumulator, MeanVariance, ShortfallSamples, Utilization, UtilizationSamples, MinCostFlows, StorageEnergy, GeneratorStorageEnergy, StorageEnergySamples, StorageEnergySamples, GeneratorStorageEnergySamples, StorageAvailability, GeneratorStorageAvailability, LineAvailability
import PRAS.ResourceAdequacy: resultchannel, finalize, updateinjection!, solveflows!, conversionfactor, fit!

#utils 
import PRAS.ResourceAdequacy:mean_std, findfirstunique_directional, findfirstunique, assetgrouplist, colsum, meanvariance
using PRAS.ResourceAdequacy



#include("./montecarloAPI/MonteCarloAPI.jl")

include("./AbstractMC/AbstractMC.jl")

function resultchannel(
    method::SimulationSpec, results::T, threads::Int
) where T <: Tuple{Vararg{ResultSpec}}

    types = accumulatortype.(method, results)
    return Channel{Tuple{types...}}(threads)

end

merge!(xs::T, ys::T) where T <: Tuple{Vararg{ResultAccumulator}} =
    foreach(merge!, xs, ys)


function finalize(
    results::Channel{<:Tuple{Vararg{ResultAccumulator}}},
    system::SystemModel{N,L,T,P,E},
    threads::Int
) where {N,L,T,P,E}

    total_result = take!(results)

    for _ in 2:threads
        thread_result = take!(results)
        merge!(total_result, thread_result)
    end
    close(results)

    return finalize.(total_result, system)

end


#Imported directly from PRAS
#SystemModel = _P.SystemModel
export SystemModel, SequentialMonteCarlo, assess, MonteCarloAPI, AbstractMC
export Shortfall, Surplus, Flow, Utilization, ShortfallSamples, SurplusSamples, FlowSamples, UtilizationSamples, GeneratorAvailability
import PRAS.ResourceAdequacy: ShortfallResult, SurplusResult, FlowResult, UtilizationResult, ShortfallSamplesResult, SurplusSamplesResult, FlowSamplesResult, UtilizationSamplesResult, GeneratorAvailabilityResult
export LOLE, EUE
#Shortfall(), GeneratorAvailability()
end
