module ResourceAdq

using ParameterJuMP,JuMP, Gurobi
const SOLVER = Gurobi


#using PRAS
#import PRAS: SequentialMonteCarlo, GeneratorAvailability, assess
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
import Decimals: Decimal, decimal
#import Distributions: DiscreteNonParametric, probs, support
#import OnlineStatsBase: EqualWeight, fit!, Mean, value, Variance
#import OnlineStats: Series
import Printf: @sprintf
import Random: AbstractRNG, rand, seed!
import Random123: Philox4x
#import StatsBase: mean, std, stderror
#import TimeZones: ZonedDateTime, @tz_str
import PRAS.ResourceAdequacy: Result, ResultSpec, SimulationSpec, ResultAccumulator, MeanVariance, meanvariance, fit!, mean_std

#import PRAS.ResourceAdequacy: SimulationSpec, FlowProblem, Result, ResultSpec,  ResultAccumulator, MeanVariance,  Utilization, UtilizationSamples, MinCostFlows, StorageEnergy, GeneratorStorageEnergy, StorageEnergySamples, StorageEnergySamples, GeneratorStorageEnergySamples, StorageAvailability, GeneratorStorageAvailability, LineAvailability
#import PRAS.ResourceAdequacy: finalize, updateinjection!, solveflows!, fit!

#utils 
#import PRAS.ResourceAdequacy:mean_std, findfirstunique_directional, findfirstunique, assetgrouplist, colsum, meanvariance
using PRAS.ResourceAdequacy



#include("./montecarloAPI/MonteCarloAPI.jl")

include("./PRASBase/PRASBase.jl")
include("./ResourceAdequacy/metrics.jl")
include("./ResourceAdequacy/results/results.jl")
include("./AbstractMC/AbstractMC.jl")
include("./PowerModelMC/PowerModelMC.jl")

#Imported directly from PRAS
#SystemModel = _P.SystemModel
export SystemModel, SequentialMonteCarlo, assess, MonteCarloAPI, AbstractMC, PowerModelMC
export Shortfall, Surplus, Flow, Utilization, ShortfallSamples, SurplusSamples, FlowSamples, UtilizationSamples, GeneratorAvailability
export LOLE, EUE
#Shortfall(), GeneratorAvailability()
end
