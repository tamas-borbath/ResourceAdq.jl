"""

    AbstractDispatchProblem(sys::SystemModel)

Create a mathematical optimization aiming to compute the ENS amount.

"""
struct AbstractDispatchProblem

    mdl::JuMP.Model
    region_nodes::UnitRange{Int}
    
    function AbstractDispatchProblem(
        sys::SystemModel, method::SimulationSpec)
        nregions = length(sys.regions)
        region_nodes = 1:nregions
        return new(

            OptProblem(sys, method),
            region_nodes
        )

    end

end

indices_after(lastset::UnitRange{Int}, setsize::Int) =
    last(lastset) .+ (1:setsize)

function update_problem!(
    problem::AbstractDispatchProblem, state::SystemState,
    system::SystemModel{N,L,T,P,E}, t::Int
) where {N,L,T,P,E}

    Mdl = problem.mdl
    #Update Generators available supply
    for i_gen in 1:length(system.generators.names)
        if state.gens_available[i_gen]
            set_value(Mdl.obj_dict[:GeneratorsCapacity][system.generators.names[i_gen]], system.generators.capacity[i_gen,t])
        else 
            #@info "Preiod: "*string(t)*" Unavailable Gen: "*system.generators.names[i_gen]
            set_value(Mdl.obj_dict[:GeneratorsCapacity][system.generators.names[i_gen]], 0.0)
            #print(Mdl)
        end
    end
    #Update Lines availablility
    for i_line in 1:length(system.lines.names)
        if state.lines_available[i_line]
            set_value(Mdl.obj_dict[:LineCapacity_forward][system.lines.names[i_line]], system.lines.forward_capacity[i_line,t])
            set_value(Mdl.obj_dict[:LineCapacity_backward][system.lines.names[i_line]], system.lines.backward_capacity[i_line,t])
        else 
            #@info "Preiod: "*string(t)*" Unavailable Line: "*system.lines.names[i_line]
            set_value(Mdl.obj_dict[:LineCapacity_forward][system.lines.names[i_line]], 0.0)
            set_value(Mdl.obj_dict[:LineCapacity_backward][system.lines.names[i_line]], 0.0)
            print(Mdl)
        end
    end
    #Update Interface limits
    for i_inter in 1:length(system.interfaces)
        set_value(Mdl.obj_dict[:NTC_forward][i_inter], system.interfaces.limit_forward[i_inter,t])
        set_value(Mdl.obj_dict[:NTC_backward][i_inter], system.interfaces.limit_backward[i_inter,t])
    end
    # Update Demand
    for i_region in 1:length(system.regions.names)
        set_value(Mdl.obj_dict[:Demand][system.regions.names[i_region]], system.regions.load[i_region,t])
    end
end

function update_state!(
    state::SystemState, problem::AbstractDispatchProblem,
    system::SystemModel{N,L,T,P,E}, t::Int
) where {N,L,T,P,E}

    edges = problem.fp.edges
    p2e = conversionfactor(L, T, P, E)

    for (i, e) in enumerate(problem.storage_discharge_edges)
        energy = state.stors_energy[i]
        energy_drop = ceil(Int, edges[e].flow * p2e /
                                system.storages.discharge_efficiency[i, t])
        state.stors_energy[i] = max(0, energy - energy_drop)

    end

    for (i, e) in enumerate(problem.storage_charge_edges)
        state.stors_energy[i] +=
            ceil(Int, edges[e].flow * p2e * system.storages.charge_efficiency[i, t])
    end

    for (i, e) in enumerate(problem.genstorage_dischargegrid_edges)
        energy = state.genstors_energy[i]
        energy_drop = ceil(Int, edges[e].flow * p2e /
                                system.generatorstorages.discharge_efficiency[i, t])
        state.genstors_energy[i] = max(0, energy - energy_drop)
    end

    for (i, (e1, e2)) in enumerate(zip(problem.genstorage_gridcharge_edges,
                                       problem.genstorage_inflowcharge_edges))
        totalcharge = (edges[e1].flow + edges[e2].flow) * p2e
        state.genstors_energy[i] +=
            ceil(Int, totalcharge * system.generatorstorages.charge_efficiency[i, t])
    end

end
