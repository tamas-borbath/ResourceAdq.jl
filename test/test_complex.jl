using Revise
using ResourceAdq
using PowerModels
cd("/Users/tborbath/.julia/dev/ResourceAdq/test")
ResourceAdq.greet()
#rts_sys = read_XLSX("test_inputs/rts.xlsx")
#write_XLSX(rts_sys, "test_inputs/output_new.XLSX")

#RTS test
#resultspecs = (Shortfall())

rts = SystemModel("test_inputs/rts.pras")

pm_input = PowerModels.parse_file("test_inputs/powermodel/rts.m")

for (k,v) in pm_input["gen"]
    @show k,v
    @show v["name"]
    pmax =  v["pmax"]
    pm_input["gen"][k]["model"] = 2
    pm_input["gen"][k]["ncost"] = 1
    pm_input["gen"][k]["cost"] = [0.0,0.0]
end

for (k,v) in pm_input["dcline"]
    @show k,v
    pm_input["dcline"][k]["model"] = 2
    pm_input["dcline"][k]["ncost"] = 1
    pm_input["dcline"][k]["cost"] = [0.0,0.0]
end
merge!(rts.grid,pm_input)

print(ResourceAdq.PowerModelOptProblem(rts))
#rts = read_XLSX("test_inputs/small.xlsx")
#=
PowerMsample = PowerModelMC(samples=100, seed=10234; verbose = true, threaded=true)
AbstractMsample = AbstractMC(samples=100, seed=10234; verbose = true, threaded=true)
@time x = assess(rts, PowerMsample, Shortfall());
@show EUE(x[1])
@show LOLE(x[1])
@time x = assess(rts, AbstractMsample, Shortfall());
@show EUE(x[1])
@show LOLE(x[1])=#
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

