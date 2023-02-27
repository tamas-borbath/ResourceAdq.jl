# LineDual

struct AMCLineDualAccumulator <:
    ResultAccumulator{AbstractMC,LineDual}
    nlines::Int
    #LineDual_total::MeanVariance
    #LineDual_line::Vector{MeanVariance}
    #LineDual_period::Vector{MeanVariance}
    #LineDual_lineperiod::Matrix{MeanVariance}

    # Running totals for current simulation
    # LineDual_total_currentsim::Float64
    LineDual_line::Vector{MeanVariance}
    LineDual_lineperiod_currentsim::Matrix{Float64}
end



accumulatortype(::AbstractMC, ::LineDual) = AMCLineDualAccumulator

# Initial values. Called once when the optimizaiton model is built
function accumulator(
    sys::SystemModel{N}, simspec::AbstractMC, ::LineDual
) where {N}
    # Init all the values
    nlines = length(sys.lines)

   # LineDual_total = meanvariance()
   # LineDual_line = [meanvariance() for _ in 1:nlines]
   # LineDual_period = [meanvariance() for _ in 1:N]
   # LineDual_lineperiod = [meanvariance() for _ in 1:nlines, _ in 1:N]

   # LineDual_total_currentsim = 0.0
    LineDual_line = [meanvariance() for _ in 1:nlines]
    LineDual_lineperiod_currentsim = zeros(Float64, N, nlines)
    return AMCLineDualAccumulator(nlines, LineDual_line,LineDual_lineperiod_currentsim )

end

#Triggered for each t timestep
function record!(
    acc::AMCLineDualAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::AbstractDispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    for (index, name) in [(i,system.lines.names[i]) for i in 1:length(system.lines)]
        acc.LineDual_lineperiod_currentsim[t,index] =shadow_price(problem.mdl.obj_dict[:LineLimit_forward][name]) + shadow_price(problem.mdl.obj_dict[:LineLimit_backward][name])
    end

    return

end
# Triggered at the end of the sample. when all t are collected 
function reset!(acc::AMCLineDualAccumulator, sampleid::Int)
    #compute an averege for each line and store it
    for i_line in 1:acc.nlines
        fit!(acc.LineDual_line[i_line], sum(acc.LineDual_lineperiod_currentsim[:,i_line]))
    end
    #reset the currentsim values
    acc.LineDual_lineperiod_currentsim .= 0.0
end
# Used before finalize to merge accumulators from different threads
function merge!(
    x::AMCLineDualAccumulator, y::AMCLineDualAccumulator
)
    for i_line in 1:acc.nlines
        fit!(x.LineDual_line[i_line],y.LineDual_line[i_line])
    end
    return
end

#Triggered once the simulation ended
function finalize(
    acc::AMCLineDualAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}
    l_nsamples = N
    l_lines = system.lines.names
    l_timestamps = system.timestamps
    l_LineDual_mean, l_LineDual_std = mean_std(acc.LineDual_line)
    return LineDualResult{N,L,T,P}(l_nsamples, l_lines, l_timestamps, l_LineDual_mean, l_LineDual_std)

end


# AMCLineDualSamples

struct AMCLineDualSamplesAccumulator <:
    ResultAccumulator{AbstractMC,LineDualSamples}

    LineDual::Array{Float64,3}

end

function merge!(
    x::AMCLineDualSamplesAccumulator, y::AMCLineDualSamplesAccumulator
)

    x.LineDual .+= y.LineDual
    return

end

accumulatortype(::AbstractMC, ::LineDualSamples) = AMCLineDualSamplesAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::AbstractMC, ::LineDualSamples
) where {N}

    nlines = length(sys.lines)
    LineDual = zeros(Float64, nlines, N, simspec.nsamples)

    return AMCLineDualSamplesAccumulator(LineDual)

end

function record!(
    acc::AMCLineDualSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::AbstractDispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}
    
    for (index, name) in [(i,system.lines.names[i]) for i in 1:length(system.lines)]
        acc.LineDual[index, t, sampleid] =shadow_price(problem.mdl.obj_dict[:LineLimit_forward][name]) + shadow_price(problem.mdl.obj_dict[:LineLimit_backward][name])
    end

    return

end

reset!(acc::AMCLineDualSamplesAccumulator, sampleid::Int) = nothing

function finalize(
    acc::AMCLineDualSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return LineDualSamplesResult{N,L,T,P}(
        system.lines.names, system.timestamps, acc.LineDual)

end
