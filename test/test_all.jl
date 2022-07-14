using Revise
using ResourceAdq
using PowerModels
using DataFrames
using Dates
cd("/Users/tborbath/.julia/dev/ResourceAdq/test")

samples_no = 3
seed = 10232
threaded = true
case = "RTS_GMLC"
case = "case5"
function read_model(p_case)
    if p_case=="RTS_GMLC"
        sys = read_XLSX("test_inputs/RTS_GMLC/RTS_GMLC.xlsx")
        pm_input =PowerModels.parse_file("test_inputs/rts_gmlc/RTS_GMLC.m")
    elseif p_case == "case5"
        sys = read_XLSX("test_inputs/case5/case5.xlsx")
        pm_input =PowerModels.parse_file("test_inputs/case5/case5.m")
    else 
        @error "Unrecognized test case with name: "*p_case
    end
    pm_input_simple =  PowerModels.make_basic_network(pm_input)
    pm_input["ptdf"] = PowerModels.calc_basic_ptdf_matrix(pm_input_simple)
    merge!(sys.grid,pm_input)
    validate(sys)
    return sys
end
sysModel = read_model(case)

ENS_df = DataFrame(Case=String[], Area_A=String[], Area_B=String[], Area_C=String[], Total=String[])
LOLE_df = DataFrame(Case=String[], Area_A=String[], Area_B=String[], Area_C=String[], Total=String[])
Perf_df  = DataFrame(Case=String[],Took = Float64[], Bytes = Int64[], GC_Time=Float64[] )
for i_type in [:Nodal]#Copperplate,:QCopperplate,:Nodal,:NTC,:QNTC,:Autarky]
    smallsample = AbstractMC(samples=samples_no, seed=seed; type = i_type, verbose = true, threaded=threaded)
    stats = @timed assess(sysModel, smallsample, Shortfall());
    x=stats.value
    push!(Perf_df,Dict([:Case => string(i_type), :Took => stats.time, :Bytes => stats.bytes, :GC_Time=>stats.gctime]) )
    push!(ENS_df, Dict(:Case => string(i_type), :Area_A => string(EUE(x[1],sysModel.regions.names[1])), :Area_B => string(EUE(x[1],sysModel.regions.names[2])), :Area_C => string(EUE(x[1],sysModel.regions.names[3])), :Total => string(EUE(x[1]))); cols = :union)
    push!(LOLE_df, Dict(:Case => string(i_type), :Area_A => string(LOLE(x[1],sysModel.regions.names[1])), :Area_B => string(LOLE(x[1],sysModel.regions.names[2])), :Area_C => string(LOLE(x[1],sysModel.regions.names[3])), :Total => string(LOLE(x[1]))); cols = :union)
end

open("Perf_debug_"*case*".txt","w") do io
    println(io, "Simulation finished on "*string(now()))
    println(io, "Case: "*string(case))
    println(io, "Number of MC years: "*string(samples_no))
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