using Revise
using ResourceAdq
using PowerModels
using DataFrames
using Dates
using Statistics
cd("/Users/tborbath/.julia/dev/ResourceAdq/test")

samples_no = 3 #per thread
seed = Int64(round(rand(1)[1]*10000))
threaded = false
case = "RTS_GMLC"
#case = "case5"
sysModel = read_test_model(case)
i_type = :Nodal
#Case_description = "Model:"*case*" simulations with "* threaded ? "multipel threads" : "single thread" * "and "*string(samples_no)*" sample"
#ENS_df = DataFrame(Case=String[], Area_A=String[], Area_B=String[], Area_C=String[], Total=String[])
#LOLE_df = DataFrame(Case=String[], Area_A=String[], Area_B=String[], Area_C=String[], Total=String[])
#Perf_df  = DataFrame(Case=String[],Took = Float64[], Bytes = Int64[], GC_Time=Float64[] )
#for i_type in [:NTC_f,:FB_fixed,:FB_fixed_evolved, :Nodal, :Copperplate]#[:FB_fixed_evolved, :FB_fixed, :Copperplate,:QCopperplate,:Nodal,:NTC,:QNTC,:Autarky]

smallsample = AbstractMC(samples=(threaded ? Threads.nthreads() * samples_no : samples_no), seed=seed; type = i_type, verbose = true, threaded=threaded)
stats = @timed assess(sysModel, smallsample, Shortfall(), LineDual{LineLimit_forward}(), LineDual{LineLimit_backward}(), LineDualSamples{LineLimit_forward}(), LineDualSamples{LineLimit_backward}());
x=stats.value

    linedual_f = x[2]
    linedualsample_f = x[4]
    linedual_b = x[3]
    linedualsample_b = x[5]

    nlines, ntimes, nsamples = size(linedualsample_f.LineDual)
    for i_line in 1:nlines
        for i_ts in 1:ntimes
            # Recompute the period_mean based on the samples
            @assert mean(linedualsample_f.LineDual[i_line, i_ts,:]) ≈ linedual_f.LineDual_period_mean[i_ts,i_line] "Mismatch of dual on line "*string(i_line)*" - "*sysModel.lines.names[i_line]*" at timestamp "*string(i_ts)
            @assert mean(linedualsample_b.LineDual[i_line, i_ts,:]) ≈ linedual_b.LineDual_period_mean[i_ts,i_line] "Mismatch of dual on line "*string(i_line)*" - "*sysModel.lines.names[i_line]*" at timestamp "*string(i_ts)
        end
        #Compute the line dual based on the individual samples
        @assert linedual_f.LineDual_mean[i_line] ≈ sum(linedual_f.LineDual_period_mean[:,i_line]) "Mismatch of dual on line "*string(i_line)*" - "*sysModel.lines.names[i_line]
        @assert linedual_b.LineDual_mean[i_line] ≈ sum(linedual_b.LineDual_period_mean[:,i_line]) "Mismatch of dual on line "*string(i_line)*" - "*sysModel.lines.names[i_line]
    end


    #push!(Perf_df,Dict([:Case => string(i_type), :Took => stats.time, :Bytes => stats.bytes, :GC_Time=>stats.gctime]) )
    #push!(ENS_df, Dict(:Case => string(i_type), :Area_A => string(EUE(x[1],sysModel.regions.names[1])), :Area_B => string(EUE(x[1],sysModel.regions.names[2])), :Area_C => string(EUE(x[1],sysModel.regions.names[3])), :Total => string(EUE(x[1]))); cols = :union)
    #push!(LOLE_df, Dict(:Case => string(i_type), :Area_A => string(LOLE(x[1],sysModel.regions.names[1])), :Area_B => string(LOLE(x[1],sysModel.regions.names[2])), :Area_C => string(LOLE(x[1],sysModel.regions.names[3])), :Total => string(LOLE(x[1]))); cols = :union)
#end
#=
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
=#

# dy ahead doesn't clrea 24 hours ahead
# not LP in europe
