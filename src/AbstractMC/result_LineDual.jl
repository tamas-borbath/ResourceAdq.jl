# LineDual

struct AMCLineDualAccumulator <:
    ResultAccumulator{AbstractMC,LineDual}
    type :: Symbol
    nlines::Int
    ntimes::Int
    #LineDual_total::MeanVariance
    #LineDual_line::Vector{MeanVariance}
    #LineDual_period::Vector{MeanVariance}
    #LineDual_lineperiod::Matrix{MeanVariance}

    # Running totals for current simulation
    # LineDual_total_currentsim::Float64
    LineDual_line::Vector{MeanVariance}
    LineDual_lineperiod::Matrix{MeanVariance}

    LineDual_lineperiod_currentsim::Matrix{Float64}
end



accumulatortype(::AbstractMC, ::LineDual) = AMCLineDualAccumulator

# Initial values. Called once when the optimizaiton model is built
function accumulator(
    sys::SystemModel{N}, simspec::AbstractMC, ::LineDual{C}
) where {N,C}
    # Init all the values
    nlines = length(sys.lines)
    ntimes = N
    ntype = unitsymbol(C)
   # LineDual_total = meanvariance()
   # LineDual_line = [meanvariance() for _ in 1:nlines]
   # LineDual_period = [meanvariance() for _ in 1:N]
   # LineDual_lineperiod = [meanvariance() for _ in 1:nlines, _ in 1:N]

   # LineDual_total_currentsim = 0.0
    LineDual_line = [meanvariance() for _ in 1:nlines]
    LineDual_lineperiod = [meanvariance() for _ in 1:nlines, _ in 1:N]
    LineDual_lineperiod_currentsim = zeros(Float64, N, nlines)
    return AMCLineDualAccumulator(ntype, nlines, ntimes, LineDual_line, LineDual_lineperiod, LineDual_lineperiod_currentsim )

end

#Triggered for each t timestep
function record!(
    acc::AMCLineDualAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::AbstractDispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    for (index, name) in [(i,system.lines.names[i]) for i in 1:length(system.lines)]
        acc.LineDual_lineperiod_currentsim[t,index] = shadow_price(problem.mdl.obj_dict[acc.type][name])
    end

    return

end
# Triggered at the end of the sample. when all t are collected 
function reset!(acc::AMCLineDualAccumulator, sampleid::Int)
    #compute an averege for each line and store it
    for i_line in 1:acc.nlines
        fit!(acc.LineDual_line[i_line], sum(acc.LineDual_lineperiod_currentsim[:,i_line]))
        for t in 1:acc.ntimes
            fit!(acc.LineDual_lineperiod[i_line,t], acc.LineDual_lineperiod_currentsim[t,i_line])
        end
    end
    #reset the currentsim values
    acc.LineDual_lineperiod_currentsim .= 0.0
end
# Used before finalize to merge accumulators from different threads
function merge!(
    x::AMCLineDualAccumulator, y::AMCLineDualAccumulator
)
    for i_line in 1:x.nlines
        fit!(x.LineDual_line[i_line],y.LineDual_line[i_line])
        for t in 1:x.ntimes
            fit!(x.LineDual_lineperiod[i_line,t],y.LineDual_lineperiod[i_line,t])
        end
    end
    return
end

#Triggered once the simulation ended
function finalize(
    acc::AMCLineDualAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}
    l_nsamples = first(acc.LineDual_line[1].stats).n
    l_lines = system.lines.names
    l_timestamps = system.timestamps
    l_LineDual_mean, l_LineDual_std = mean_std(acc.LineDual_line)
    l_LineDual_period_mean = zeros(Float64, acc.ntimes, acc.nlines)
    l_LineDual_period_std = zeros(Float64, acc.ntimes, acc.nlines)
    for i_line in 1:acc.nlines
        l_LineDual_period_mean[:,i_line], l_LineDual_period_std[:,i_line] = mean_std(acc.LineDual_lineperiod[i_line,:])
    end
    return LineDualResult{N,L,T,P}(acc.type,l_nsamples, l_lines, l_timestamps, l_LineDual_mean, l_LineDual_std, l_LineDual_period_mean, l_LineDual_period_std)

end


# AMCLineDualSamples

struct AMCLineDualSamplesAccumulator <:
    ResultAccumulator{AbstractMC,LineDualSamples}
    type :: Symbol
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
    sys::SystemModel{N}, simspec::AbstractMC, ::LineDualSamples{C}
) where {N, C}

    ntype = unitsymbol(C)
    nlines = length(sys.lines)
    LineDual = zeros(Float64, nlines, N, simspec.nsamples)

    return AMCLineDualSamplesAccumulator(ntype, LineDual)

end

function record!(
    acc::AMCLineDualSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::AbstractDispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}
    
    for (index, name) in [(i,system.lines.names[i]) for i in 1:length(system.lines)]
        acc.LineDual[index, t, sampleid] =shadow_price(problem.mdl.obj_dict[acc.type][name])
    end

    return

end

reset!(acc::AMCLineDualSamplesAccumulator, sampleid::Int) = nothing

function finalize(
    acc::AMCLineDualSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return LineDualSamplesResult{N,L,T,P}(acc.type,
        system.lines.names, system.timestamps, acc.LineDual)

end
