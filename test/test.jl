using Revise
using ResourceAdq
using PowerModels
using DataFrames
cd("/Users/tborbath/.julia/dev/ResourceAdq/test")
ResourceAdq.greet()
#rts_sys = read_XLSX("test_inputs/rts.xlsx")
#write_XLSX(rts_sys, "test_inputs/output_new.XLSX")

#RTS test
#resultspecs = (Shortfall())

#rts = SystemModel("test_inputs/rts.pras")

#Read Input Data

case5 = read_XLSX("test_inputs/case5/case5.xlsx")
pm_input = PowerModels.make_basic_network(PowerModels.parse_file("test_inputs/case5/case5.m"))
pm_input["ptdf"] = PowerModels.calc_basic_ptdf_matrix(pm_input)
merge!(case5.grid,pm_input)
validate(case5)

ENS_df = DataFrame(Case=String[], Area_1=String[], Area_2=String[], Area_3=String[], Total=String[])
LOLE_df = DataFrame(Case=String[])
for i_type in [:Nodal]#[:Copperplate,:QCopperplate,:Nodal,:NTC,:QNTC,:Autarky]
    smallsample = AbstractMC(samples=10, seed=10232; type = i_type, verbose = true, threaded=false)
    @time x = assess(case5, smallsample, Shortfall());
    push!(ENS_df, Dict(:Case => string(i_type), :Area_1 => string(EUE(x[1],"1")), :Area_2 => string(EUE(x[1],"2")), :Area_3 => string(EUE(x[1],"3")), :Total => string(EUE(x[1]))); cols = :union)
    push!(LOLE_df, Dict(:Case => string(i_type), :Area_1 => string(LOLE(x[1],"1")), :Area_2 => string(LOLE(x[1],"2")), :Area_3 => string(LOLE(x[1],"3")), :Total => string(LOLE(x[1]))); cols = :union)
    @info "This is case:"*string(i_type)
    println("    1: "*string(EUE(x[1],"1")))
    println("    2: "*string(EUE(x[1],"2")))
    println("    3: "*string(EUE(x[1],"3")))
    println("Total: "*string(EUE(x[1])))
    println(" ")

    println("    1: "*string(LOLE(x[1],"1")))
    println("    2: "*string(LOLE(x[1],"2")))
    println("    3: "*string(LOLE(x[1],"3")))
    println("Total: "*string(LOLE(x[1])))
end

open("debug/ENS_debug.txt","w") do io
    print(io, ENS_df)
end

open("debug/LOLE_debug.txt","w") do io
    print(io, LOLE_df)
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
