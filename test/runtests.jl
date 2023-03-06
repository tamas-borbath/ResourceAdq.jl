using Test
using ResourceAdq
using PowerModels
using DataFrames
using Dates
using Statistics


samples_no = 10 #per thread
seed = Int64(round(rand(1)[1]*10000))
threaded = false
#case = "RTS_GMLC"
case = "case5"

sysModel = read_test_model(case)

samples_no = 3 #per thread
seed = Int64(round(rand(1)[1]*10000))
threaded = false
#case = "RTS_GMLC"
case = "case5"
sysModel = read_test_model(case)
i_type = :Nodal
Case_description = String("Model:"*case*" simulations with "* string(samples_no)*" samples, threaded:"*string(threaded))

smallsample = AbstractMC(samples=(threaded ? Threads.nthreads() * samples_no : samples_no), seed=seed; type = i_type, verbose = false, threaded=threaded)
stats = @timed assess(sysModel, smallsample, Shortfall(), LineDual{LineLimit_forward}(), LineDual{LineLimit_backward}(), LineDualSamples{LineLimit_forward}(), LineDualSamples{LineLimit_backward}());
x=stats.value


@testset "$Case_description" begin
    linedual_f = x[2]
    linedualsample_f = x[4]
    linedual_b = x[3]
    linedualsample_b = x[5]

    nlines, ntimes, nsamples = size(linedualsample_f.LineDual)
    
    @testset "Line Dual for line $i_line - $(sysModel.lines.names[i_line])" for i_line in 1:nlines
        @testset "- for period $i_ts" for i_ts in 1:ntimes
            # Recompute the period_mean based on the samples
            @test mean(linedualsample_f.LineDual[i_line, i_ts,:]) ≈ linedual_f.LineDual_period_mean[i_ts,i_line]# "Mismatch of dual on line "*string(i_line)*" - "*sysModel.lines.names[i_line]*" at timestamp "*string(i_ts)
            @test mean(linedualsample_b.LineDual[i_line, i_ts,:]) ≈ linedual_b.LineDual_period_mean[i_ts,i_line]# "Mismatch of dual on line "*string(i_line)*" - "*sysModel.lines.names[i_line]*" at timestamp "*string(i_ts)
        end
        #Compute the line dual based on the individual samples
        @test linedual_f.LineDual_mean[i_line] ≈ sum(linedual_f.LineDual_period_mean[:,i_line])# "Mismatch of dual on line "*string(i_line)*" - "*sysModel.lines.names[i_line]
        @test linedual_b.LineDual_mean[i_line] ≈ sum(linedual_b.LineDual_period_mean[:,i_line])# "Mismatch of dual on line "*string(i_line)*" - "*sysModel.lines.names[i_line]
    end
end