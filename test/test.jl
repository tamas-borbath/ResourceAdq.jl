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
case5 = read_XLSX("test_inputs/case5/case5.xlsx")
pm_input = PowerModels.parse_file("test_inputs/case5/case5.m")
merge!(case5.grid,pm_input)

smallsample = AbstractMC(samples=100, seed=10234; verbose = true, threaded=true)
@time x = assess(case5, smallsample, Shortfall());
@show EUE(x[1])
@show LOLE(x[1])
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
