

struct AbstractMC <: SimulationSpec

    nsamples::Int
    seed::UInt64
    verbose::Bool
    threaded::Bool
    type::Symbol
    optimizer::Module

    function AbstractMC(;
        samples::Int=10_000, seed::Integer=rand(UInt64),
        verbose::Bool=false, threaded::Bool=true, type::Symbol, optimizer::Module=SOLVER
    )
        samples <= 0 && throw(DomainError("Sample count must be positive"))
        seed < 0 && throw(DomainError("Random seed must be non-negative"))
        new(samples, UInt64(seed), verbose, threaded, type, optimizer)
    end

end
include("OptProblem.jl")
include("SystemState.jl")
include("AbstractDispatchProblem.jl")
include("utils.jl")

function assess(
    system::SystemModel,
    method::AbstractMC,
    resultspecs::ResultSpec...
)
    threads = nthreads()
    sampleseeds = Channel{Int}(2*threads)
    results = resultchannel(method, resultspecs, threads)

    @spawn makeseeds(sampleseeds, method.nsamples)
    if method.threaded
        for _ in 1:threads
            @spawn assess(system, method, sampleseeds, results, resultspecs...)
        end
    else
        assess(system, method, sampleseeds, results, resultspecs...)
    end

    return finalize(results, system, method.threaded ? threads : 1)

end

function makeseeds(sampleseeds::Channel{Int}, nsamples::Int)

    for s in 1:nsamples
        put!(sampleseeds, s)
    end

    close(sampleseeds)

end

function assess(
    system::SystemModel{N}, method::AbstractMC,
    sampleseeds::Channel{Int},
    results::Channel{<:Tuple{Vararg{ResultAccumulator{AbstractMC}}}},
    resultspecs::ResultSpec...
) where {R<:ResultSpec, N}
    dispatchproblem = AbstractDispatchProblem(system, method)
    systemstate = SystemState(system)
    recorders = accumulator.(system, method, resultspecs)

    # TODO: Test performance of Philox vs Threefry, choice of rounds
    # Also consider implementing an efficient Bernoulli trial with direct
    # mantissa comparison
    rng = Philox4x((0, 0), 10)

    for s in sampleseeds
        method.verbose && mod(s,1) == 0 && @info "Thread with ID:  "*string(Threads.threadid())*" processing sample :"*string(s)
        
        seed!(rng, (method.seed, s))
        initialize!(rng, systemstate, system)
        for t in 1:N
            advance!(rng, systemstate, dispatchproblem, system, t)
            solve!(dispatchproblem, systemstate, system, t)
            foreach(recorder -> record!(
                        recorder, system, systemstate, dispatchproblem, s, t
                    ), recorders)

        end
        if method.verbose && !method.threaded
            rm("model.txt")
            open("model.txt","a") do io
                print(io,dispatchproblem.mdl)
            end
        end

        foreach(recorder -> reset!(recorder, s), recorders)

    end

    put!(results, recorders)

end

function initialize!(
    rng::AbstractRNG, state::SystemState, system::SystemModel{N}
) where N

        initialize_availability!(
            rng, state.gens_available, state.gens_nexttransition,
            system.generators, N)

        initialize_availability!(
            rng, state.stors_available, state.stors_nexttransition,
            system.storages, N)

        initialize_availability!(
            rng, state.genstors_available, state.genstors_nexttransition,
            system.generatorstorages, N)

        initialize_availability!(
            rng, state.lines_available, state.lines_nexttransition,
            system.lines, N)

        fill!(state.stors_energy, 0)
        fill!(state.genstors_energy, 0)

        return

end

function advance!(
    rng::AbstractRNG,
    state::SystemState,
    dispatchproblem::AbstractDispatchProblem,
    system::SystemModel{N}, t::Int) where N

    update_availability!(
        rng, state.gens_available, state.gens_nexttransition,
        system.generators, t, N)

    update_availability!(
        rng, state.stors_available, state.stors_nexttransition,
        system.storages, t, N)

    update_availability!(
        rng, state.genstors_available, state.genstors_nexttransition,
        system.generatorstorages, t, N)

    update_availability!(
        rng, state.lines_available, state.lines_nexttransition,
        system.lines, t, N)
#Here we update the problem with the soc from the previous iteration
   # update_energy!(state.stors_energy, system.storages, t)
   # update_energy!(state.genstors_energy, system.generatorstorages, t)

    update_problem!(dispatchproblem, state, system, t)

end

function solve!(
    dispatchproblem::AbstractDispatchProblem, state::SystemState,
    system::SystemModel, t::Int
)
    redirect_stdout((()->optimize!(dispatchproblem.mdl)),open("/dev/null", "w"))    
    #We could update the state with the new state for energy in stors and genstors
    #update_state!(state, dispatchproblem, system, t)
end

include("FB_utils.jl")
include("result_shortfall.jl")
include("result_availability.jl")
include("result_LineDual.jl")