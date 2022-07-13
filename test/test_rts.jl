using Revise
using ResourceAdq
using PowerModels
using DataFrames
using Dates
cd("/Users/tborbath/.julia/dev/ResourceAdq/test")
ResourceAdq.greet()
#rts_sys = read_XLSX("test_inputs/rts.xlsx")
#write_XLSX(rts_sys, "test_inputs/output_new.XLSX")

#RTS test
#resultspecs = (Shortfall())

#rts = SystemModel("test_inputs/rts.pras")

#Read Input Data

samples_no = 100
seed = 10232
threaded = true
case = "RTS_GMLC"

rts = read_XLSX("test_inputs/RTS_GMLC/RTS_GMLC.xlsx")
pm_input = PowerModels.make_basic_network(PowerModels.parse_file("test_inputs/rts_gmlc/RTS_GMLC.m"))
pm_input["ptdf"] = PowerModels.calc_basic_ptdf_matrix(pm_input)
merge!(rts.grid,pm_input)
validate(rts)

ENS_df = DataFrame(Case=String[], Area_A=String[], Area_B=String[], Area_C=String[], Total=String[])
LOLE_df = DataFrame(Case=String[], Area_A=String[], Area_B=String[], Area_C=String[], Total=String[])
Perf_df  = DataFrame(Case=String[],Took = Float64[], Bytes = Int64[], GC_Time=Float64[] )
for i_type in [:Copperplate,:QCopperplate,:Nodal,:NTC,:QNTC,:Autarky]
    smallsample = AbstractMC(samples=samples_no, seed=seed; type = i_type, verbose = true, threaded=threaded)
    stats = @timed assess(rts, smallsample, Shortfall());
    x=stats.value
    push!(Perf_df,Dict([:Case => string(i_type), :Took => stats.time, :Bytes => stats.bytes, :GC_Time=>stats.gctime]) )
    push!(ENS_df, Dict(:Case => string(i_type), :Area_A => string(EUE(x[1],"A")), :Area_B => string(EUE(x[1],"B")), :Area_C => string(EUE(x[1],"C")), :Total => string(EUE(x[1]))); cols = :union)
    push!(LOLE_df, Dict(:Case => string(i_type), :Area_A => string(LOLE(x[1],"A")), :Area_B => string(LOLE(x[1],"B")), :Area_C => string(LOLE(x[1],"C")), :Total => string(LOLE(x[1]))); cols = :union)
    @info "This is case:"*string(i_type)
    println("    1: "*string(EUE(x[1],"A")))
    println("    2: "*string(EUE(x[1],"B")))
    println("    3: "*string(EUE(x[1],"C")))
    println("Total: "*string(EUE(x[1])))
    println(" ")

    println("    1: "*string(LOLE(x[1],"A")))
    println("    2: "*string(LOLE(x[1],"B")))
    println("    3: "*string(LOLE(x[1],"C")))
    println("Total: "*string(LOLE(x[1])))
end

open("ENS_debug_rts.txt","w") do io
    print(io, ENS_df)
end

open("LOLE_debug_rts.txt","w") do io
    print(io, LOLE_df)
end
open("Perf_debug_rts.txt","w") do io
    println(io, "Simulation finished on "*string(now()))
    println(io, "Case: "*string(case))
    println(io, "Number of MC years: "*string(samples_no))
    println(io, "Randomizer Seed: "*string(seed))
    println(io, "Threaded execution: "*string(threaded))
    println(io, "Number of threads used: "*string(Threads.nthreads()))
    print(io, Perf_df)
end
#=
#smallsample = MonteCarloAPI(samples=100, seed=10233; verbose = true, threaded=false)

smallsample = AbstractMC(samples=100, seed=10233; verbose = true, threaded=false)

resultspecs = (Shortfall(), Surplus(), Flow(), Utilization(),
ShortfallSamples(), SurplusSamples(),
FlowSamples(), UtilizationSamples(),
GeneratorAvailability())
#@time x = assess(rts, smallsample, resultspecs...);
@time x = assess(rts, smallsample, Shortfall());
=#
