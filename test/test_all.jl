using Revise
using ResourceAdq
using PowerModels
using DataFrames
using Dates
cd("/Users/tborbath/.julia/dev/ResourceAdq/test")

samples_no = 1
seed = Int64(round(rand(1)[1]*10000))
threaded = true
case = "RTS_GMLC"
#case = "case5"

sysModel = read_test_model(case)
ENS_df = DataFrame(Case=String[], Area_A=String[], Area_B=String[], Area_C=String[], Total=String[])
LOLE_df = DataFrame(Case=String[], Area_A=String[], Area_B=String[], Area_C=String[], Total=String[])
Perf_df  = DataFrame(Case=String[],Took = Float64[], Bytes = Int64[], GC_Time=Float64[] )
for i_type in [:NTC_f,:FB_fixed,:FB_fixed_evolved, :Nodal, :Copperplate]#[:FB_fixed_evolved, :FB_fixed, :Copperplate,:QCopperplate,:Nodal,:NTC,:QNTC,:Autarky]
    smallsample = AbstractMC(samples=(threaded ? Threads.nthreads() * samples_no : samples_no), seed=seed; type = i_type, verbose = true, threaded=threaded)
    stats = @timed assess(sysModel, smallsample, Shortfall());
    x=stats.value
    push!(Perf_df,Dict([:Case => string(i_type), :Took => stats.time, :Bytes => stats.bytes, :GC_Time=>stats.gctime]) )
    push!(ENS_df, Dict(:Case => string(i_type), :Area_A => string(EUE(x[1],sysModel.regions.names[1])), :Area_B => string(EUE(x[1],sysModel.regions.names[2])), :Area_C => string(EUE(x[1],sysModel.regions.names[3])), :Total => string(EUE(x[1]))); cols = :union)
    push!(LOLE_df, Dict(:Case => string(i_type), :Area_A => string(LOLE(x[1],sysModel.regions.names[1])), :Area_B => string(LOLE(x[1],sysModel.regions.names[2])), :Area_C => string(LOLE(x[1],sysModel.regions.names[3])), :Total => string(LOLE(x[1]))); cols = :union)
end

open("Perf_debug_"*case*"_"*string(now())*".txt","w") do io
    println(io, "Simulation finished on "*string(now()))
    println(io, "Case: "*string(case))
    println(io, "Number of MC years (per thread): "*string(samples_no))
    println(io, "Randomizer Seed: "*string(seed))
    println(io, "Threaded execution: "*string(threaded))
    println(io, "Number of threads used: "*string(Threads.nthreads()))
    println(io)
    println(io, Perf_df)
    println(io)
    println(io, LOLE_df)
    println(io)
    println(io, ENS_df)
end