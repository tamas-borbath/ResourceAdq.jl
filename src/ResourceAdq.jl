module ResourceAdq

using ParameterJuMP, JuMP, Gurobi
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
import Decimals: Decimal, decimal
import Printf: @sprintf
import Random: AbstractRNG, rand, seed!
import Random123: Philox4x
import PRAS.ResourceAdequacy: Result, ResultSpec, SimulationSpec, ResultAccumulator, MeanVariance, meanvariance, fit!, mean_std
using PRAS.ResourceAdequacy



#include("./montecarloAPI/MonteCarloAPI.jl")

include("./PRASBase/PRASBase.jl")
include("./ResourceAdequacy/metrics.jl")
include("./ResourceAdequacy/results/results.jl")
include("./AbstractMC/AbstractMC.jl")
include("./PowerModelMC/PowerModelMC.jl")

export SystemModel, SequentialMonteCarlo, assess, MonteCarloAPI, AbstractMC, PowerModelMC
export Shortfall, Surplus, Flow, Utilization, ShortfallSamples, SurplusSamples, FlowSamples, UtilizationSamples, GeneratorAvailability
export LOLE, EUE
end
