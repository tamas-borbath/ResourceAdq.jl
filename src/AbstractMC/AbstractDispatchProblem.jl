"""

    AbstractDispatchProblem(sys::SystemModel)

Create a mathematical optimization aiming to compute the ENS amount.

"""
struct AbstractDispatchProblem

    mdl::JuMP.Model
    
    # Node labels
    region_nodes::UnitRange{Int}
    #=storage_discharge_nodes::UnitRange{Int}
    storage_charge_nodes::UnitRange{Int}
    genstorage_inflow_nodes::UnitRange{Int}
    genstorage_discharge_nodes::UnitRange{Int}
    genstorage_togrid_nodes::UnitRange{Int}
    genstorage_charge_nodes::UnitRange{Int}
    slack_node::Int

    # Edge labels
    region_unserved_edges::UnitRange{Int}
    region_unused_edges::UnitRange{Int}
    interface_forward_edges::UnitRange{Int}
    interface_reverse_edges::UnitRange{Int}
    storage_discharge_edges::UnitRange{Int}
    storage_dischargeunused_edges::UnitRange{Int}
    storage_charge_edges::UnitRange{Int}
    storage_chargeunused_edges::UnitRange{Int}
    genstorage_dischargegrid_edges::UnitRange{Int}
    genstorage_dischargeunused_edges::UnitRange{Int}
    genstorage_inflowgrid_edges::UnitRange{Int}
    genstorage_totalgrid_edges::UnitRange{Int}
    genstorage_gridcharge_edges::UnitRange{Int}
    genstorage_inflowcharge_edges::UnitRange{Int}
    genstorage_chargeunused_edges::UnitRange{Int}
    genstorage_inflowunused_edges::UnitRange{Int}

    min_chargecost::Int
    max_dischargecost::Int
=#
    function AbstractDispatchProblem(
        sys::SystemModel; unlimited::Int=999_999_999)

        nregions = length(sys.regions)
 #=       nifaces = length(sys.interfaces)
        nstors = length(sys.storages)
        ngenstors = length(sys.generatorstorages)

        maxchargetime, maxdischargetime = maxtimetocharge_discharge(sys)
        min_chargecost = - maxchargetime - 1
        max_dischargecost = - min_chargecost + maxdischargetime + 1
        shortagepenalty = 10 * (nifaces + max_dischargecost)

        stor_regions = assetgrouplist(sys.region_stor_idxs)
        genstor_regions = assetgrouplist(sys.region_genstor_idxs)
=#
        region_nodes = 1:nregions
 #=       stor_discharge_nodes = indices_after(region_nodes, nstors)
        stor_charge_nodes = indices_after(stor_discharge_nodes, nstors)
        genstor_inflow_nodes = indices_after(stor_charge_nodes, ngenstors)
        genstor_discharge_nodes = indices_after(genstor_inflow_nodes, ngenstors)
        genstor_togrid_nodes = indices_after(genstor_discharge_nodes, ngenstors)
        genstor_charge_nodes = indices_after(genstor_togrid_nodes, ngenstors)
        slack_node = nnodes = last(genstor_charge_nodes) + 1

        region_unservedenergy = 1:nregions
        region_unusedcapacity = indices_after(region_unservedenergy, nregions)
        iface_forward = indices_after(region_unusedcapacity, nifaces)
        iface_reverse = indices_after(iface_forward, nifaces)
        stor_dischargeused = indices_after(iface_reverse, nstors)
        stor_dischargeunused = indices_after(stor_dischargeused, nstors)
        stor_chargeused = indices_after(stor_dischargeunused, nstors)
        stor_chargeunused = indices_after(stor_chargeused, nstors)
        genstor_dischargegrid = indices_after(stor_chargeunused, ngenstors)
        genstor_dischargeunused = indices_after(genstor_dischargegrid, ngenstors)
        genstor_inflowgrid = indices_after(genstor_dischargeunused, ngenstors)
        genstor_totalgrid = indices_after(genstor_inflowgrid, ngenstors)
        genstor_gridcharge = indices_after(genstor_totalgrid, ngenstors)
        genstor_inflowcharge = indices_after(genstor_gridcharge, ngenstors)
        genstor_chargeunused = indices_after(genstor_inflowcharge, ngenstors)
        genstor_inflowunused = indices_after(genstor_chargeunused, ngenstors)
        nedges = last(genstor_inflowunused)

        nodesfrom = Vector{Int}(undef, nedges)
        nodesto = Vector{Int}(undef, nedges)
        costs = zeros(Int, nedges)
        limits = fill(unlimited, nedges)
        injections = zeros(Int, nnodes)

        function initedges(idxs::UnitRange{Int}, from::AbstractVector{Int}, to::AbstractVector{Int})
            nodesfrom[idxs] = from
            nodesto[idxs] = to
        end

        function initedges(idxs::UnitRange{Int}, from::AbstractVector{Int}, to::Int)
            nodesfrom[idxs] = from
            nodesto[idxs] .= to
        end

        function initedges(idxs::UnitRange{Int}, from::Int, to::AbstractVector{Int})
            nodesfrom[idxs] .= from
            nodesto[idxs] = to
        end

        # Unserved energy edges
        initedges(region_unservedenergy, slack_node, region_nodes)
        costs[region_unservedenergy] .= shortagepenalty

        # Unused generation edges
        initedges(region_unusedcapacity, region_nodes, slack_node)

        # Transmission edges
        initedges(iface_forward, sys.interfaces.regions_from, sys.interfaces.regions_to)
        costs[iface_forward] .= 1
        initedges(iface_reverse, sys.interfaces.regions_to, sys.interfaces.regions_from)
        costs[iface_reverse] .= 1

        # Storage discharging / charging
        initedges(stor_dischargeused, stor_discharge_nodes, stor_regions)
        initedges(stor_dischargeunused, stor_discharge_nodes, slack_node)
        initedges(stor_chargeused, stor_regions, stor_charge_nodes)
        initedges(stor_chargeunused, slack_node, stor_charge_nodes)

        # GeneratorStorage discharging / grid injections
        initedges(genstor_dischargegrid, genstor_discharge_nodes, genstor_togrid_nodes)
        initedges(genstor_dischargeunused, genstor_discharge_nodes, slack_node)
        initedges(genstor_inflowgrid, genstor_inflow_nodes, genstor_togrid_nodes)
        initedges(genstor_totalgrid, genstor_togrid_nodes, genstor_regions)

        # GeneratorStorage charging
        initedges(genstor_gridcharge, genstor_regions, genstor_charge_nodes)
        initedges(genstor_inflowcharge, genstor_inflow_nodes, genstor_charge_nodes)
        initedges(genstor_chargeunused, slack_node, genstor_charge_nodes)

        initedges(genstor_inflowunused, genstor_inflow_nodes, slack_node)
=#
        return new(

            OptProblem(sys),

            region_nodes#=, stor_discharge_nodes, stor_charge_nodes,
            genstor_inflow_nodes, genstor_discharge_nodes,
            genstor_togrid_nodes, genstor_charge_nodes, slack_node,

            region_unservedenergy, region_unusedcapacity,
            iface_forward, iface_reverse,
            stor_dischargeused, stor_dischargeunused,
            stor_chargeused, stor_chargeunused,
            genstor_dischargegrid, genstor_dischargeunused, genstor_inflowgrid,
            genstor_totalgrid,
            genstor_gridcharge, genstor_inflowcharge, genstor_chargeunused,
            genstor_inflowunused, min_chargecost, max_dischargecost=#
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
    #Update Lines available supply
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
    # Update Demand
    for i_region in 1:length(system.regions.names)
        set_value(Mdl.obj_dict[:Demand][system.regions.names[i_region]], system.regions.load[i_region,t])
    end
    #=@show state
    # Update regional net available injection / withdrawal (from generators)
    for (r, gen_idxs) in zip(problem.region_nodes, system.region_gen_idxs)
        @show r, gen_idxs
        region_node = fp.nodes[r]

        region_netgenavailable = available_capacity(
            state.gens_available, system.generators, gen_idxs, t
            ) - system.regions.load[r, t]

        updateinjection!(region_node, slack_node, region_netgenavailable)

    end

    # Update bidirectional interface limits (from lines)
    for (i, line_idxs) in enumerate(system.interface_line_idxs)

        interface_forwardedge = fp.edges[problem.interface_forward_edges[i]]
        interface_backwardedge = fp.edges[problem.interface_reverse_edges[i]]

        lines_capacity_forward, lines_capacity_backward =
            available_capacity(state.lines_available, system.lines, line_idxs, t)

        interface_capacity_forward = min(
            lines_capacity_forward, system.interfaces.limit_forward[i,t])
        updateflowlimit!(interface_forwardedge, interface_capacity_forward)

        interface_capacity_backward = min(
            lines_capacity_backward, system.interfaces.limit_backward[i,t])
        updateflowlimit!(interface_backwardedge, interface_capacity_backward)

    end

    # Update Storage charge/discharge limits and priorities
    for (i, (charge_node, charge_edge, discharge_node, discharge_edge)) in
        enumerate(zip(
        problem.storage_charge_nodes, problem.storage_charge_edges,
        problem.storage_discharge_nodes, problem.storage_discharge_edges))

        stor_online = state.stors_available[i]
        stor_energy = state.stors_energy[i]
        maxenergy = system.storages.energy_capacity[i, t]

        # Update discharging

        maxdischarge = stor_online * system.storages.discharge_capacity[i, t]
        dischargeefficiency = system.storages.discharge_efficiency[i, t]
        energydischargeable = stor_energy * dischargeefficiency

        if iszero(maxdischarge)
            timetodischarge = N + 1
        else
            timetodischarge = round(Int, energydischargeable / maxdischarge)
        end

        discharge_capacity =
            min(maxdischarge, floor(Int, energytopower(
                energydischargeable, E, L, T, P)))
        updateinjection!(
            fp.nodes[discharge_node], slack_node, discharge_capacity)

        # Largest time-to-discharge = highest priority (discharge first)
        dischargecost = problem.max_dischargecost - timetodischarge # Positive cost
        updateflowcost!(fp.edges[discharge_edge], dischargecost)

        # Update charging

        maxcharge = stor_online * system.storages.charge_capacity[i, t]
        chargeefficiency = system.storages.charge_efficiency[i, t]
        energychargeable = (maxenergy - stor_energy) / chargeefficiency

        charge_capacity =
            min(maxcharge, floor(Int, energytopower(
                energychargeable, E, L, T, P)))
        updateinjection!(
            fp.nodes[charge_node], slack_node, -charge_capacity)

        # Smallest time-to-discharge = highest priority (charge first)
        chargecost = problem.min_chargecost + timetodischarge # Negative cost
        updateflowcost!(fp.edges[charge_edge], chargecost)

    end

    # Update GeneratorStorage inflow/charge/discharge limits and priorities
    for (i, (charge_node, gridcharge_edge, inflowcharge_edge,
            discharge_node, dischargegrid_edge, totalgrid_edge,
            inflow_node)) in enumerate(zip(
        problem.genstorage_charge_nodes, problem.genstorage_gridcharge_edges,
        problem.genstorage_inflowcharge_edges, problem.genstorage_discharge_nodes,
        problem.genstorage_dischargegrid_edges, problem.genstorage_totalgrid_edges,
        problem.genstorage_inflow_nodes))

        stor_online = state.genstors_available[i]
        stor_energy = state.genstors_energy[i]
        maxenergy = system.generatorstorages.energy_capacity[i, t]

        # Update inflow and grid injection / withdrawal limits

        inflow_capacity = stor_online * system.generatorstorages.inflow[i, t]
        updateinjection!(
            fp.nodes[inflow_node], slack_node, inflow_capacity)

        gridinjection_capacity = system.generatorstorages.gridinjection_capacity[i, t]
        updateflowlimit!(fp.edges[totalgrid_edge], gridinjection_capacity)

        gridwithdrawal_capacity = system.generatorstorages.gridwithdrawal_capacity[i, t]
        updateflowlimit!(fp.edges[gridcharge_edge], gridwithdrawal_capacity)

        # Update discharging

        maxdischarge = stor_online * system.generatorstorages.discharge_capacity[i, t]
        dischargeefficiency = system.generatorstorages.discharge_efficiency[i, t]
        energydischargeable = stor_energy * dischargeefficiency

        if iszero(maxdischarge)
            timetodischarge = N + 1
        else
            timetodischarge = round(Int, energydischargeable / maxdischarge)
        end

        discharge_capacity =
            min(maxdischarge, floor(Int, energytopower(
                energydischargeable, E, L, T, P)))
        updateinjection!(
            fp.nodes[discharge_node], slack_node, discharge_capacity)

        # Largest time-to-discharge = highest priority (discharge first)
        dischargecost = problem.max_dischargecost - timetodischarge # Positive cost
        updateflowcost!(fp.edges[dischargegrid_edge], dischargecost)

        # Update charging

        maxcharge = stor_online * system.generatorstorages.charge_capacity[i, t]
        chargeefficiency = system.generatorstorages.charge_efficiency[i, t]
        energychargeable = (maxenergy - stor_energy) / chargeefficiency

        charge_capacity =
            min(maxcharge, floor(Int, energytopower(
                energychargeable, E, L, T, P)))
        updateinjection!(
            fp.nodes[charge_node], slack_node, -charge_capacity)

        # Smallest time-to-discharge = highest priority (charge first)
        chargecost = problem.min_chargecost + timetodischarge # Negative cost
        updateflowcost!(fp.edges[gridcharge_edge], chargecost)
        updateflowcost!(fp.edges[inflowcharge_edge], chargecost)

    end=#

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
