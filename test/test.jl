using Revise
using ResourceAdq
using PowerModels
cd("/Users/tborbath/.julia/dev/ResourceAdq/test")
ResourceAdq.greet()
#rts_sys = read_XLSX("test_inputs/rts.xlsx")
#write_XLSX(rts_sys, "test_inputs/output_new.XLSX")

#RTS test
#resultspecs = (Shortfall())

#rts = SystemModel("test_inputs/rts.pras")

#Read Input Data
#=
case5 = read_XLSX("test_inputs/case5/case5.xlsx")
pm_input = PowerModels.parse_file("test_inputs/case5/case5.m")
merge!(case5.grid,pm_input)=#

for i_type in [:Copperplate,:NTC,:QCopperplate,:QNTC,:Autarky]
    smallsample = AbstractMC(samples=50, seed=10232; type = i_type, verbose = false, threaded=true)
    @time x = assess(case5, smallsample, Shortfall());
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
