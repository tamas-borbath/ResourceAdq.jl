function OptProblem(sys::SystemModel, method::AbstractMC)
    #build base model 
    m = Model(SOLVER.Optimizer)
    set_optimizer_attribute(m, "OutputFlag", 0)

     # Line Capacities are considered infinite
     region_name_to_index = Dict([sys.regions.names[i] => i for i in 1:length(sys.regions.names)])
     lines_to_region = Dict(name => [] for name in sys.regions.names)
     lines_from_region = Dict(name => [] for name in sys.regions.names)
     for i in 1:length(sys.interfaces)
         for i_line in sys.interface_line_idxs[i]
             push!(lines_from_region[sys.regions.names[sys.interfaces.regions_from[i]]],sys.lines.names[i_line])
             push!(lines_to_region[sys.regions.names[sys.interfaces.regions_to[i]]],sys.lines.names[i_line])
         end
     end

     ints_to_region = Dict(name => [] for name in sys.regions.names)
     ints_from_region = Dict(name => [] for name in sys.regions.names)
     interfaces = 1:length(sys.interfaces)
     for i in interfaces
        push!(ints_from_region[sys.regions.names[sys.interfaces.regions_from[i]]],i)
        push!(ints_to_region[sys.regions.names[sys.interfaces.regions_to[i]]],i)
     end
     @variables(m, begin
         NetPosition[name in sys.regions.names]
         Curtailment[name in sys.regions.names] ≥ 0
         Supply[name in sys.regions.names] ≥ 0
         Demand[name in sys.regions.names] == 10000, Param()
         GeneratorsCapacity[Gen in sys.generators.names] == 1000, Param()
         LineCapacity_forward[Line in sys.lines.names] == 100, Param()
         LineCapacity_backward[Line in sys.lines.names] == 7, Param()
         NTC_forward[Interface in interfaces] == 0.0, Param()
         NTC_backward[Interface in interfaces] == 0.0, Param()
     end)
     #Add constraint and objective based on type

    method.verbose && @info "Building a simulaiton model of type:"*string(method.type)
    if method.type == :QCopperplate
        @constraints(m, begin
            PowerConservation, sum(NetPosition) == 0
            NetPositionComp[name in sys.regions.names], NetPosition[name] == Supply[name] + Curtailment[name] - Demand[name]
            AvailableSupply[name in sys.regions.names], Supply[name] ≤ sum(GeneratorsCapacity[sys.generators.names[gen_index]] for gen_index in sys.region_gen_idxs[region_name_to_index[name]])
            end)
        
        @objective(m, Min, sum(Curtailment[name]^2 for name in sys.regions.names))
    elseif method.type == :QNTC_line
        @constraints(m, begin
            PowerConservation, sum(NetPosition) == 0
            NetPositionComp[name in sys.regions.names], NetPosition[name] == Supply[name] + Curtailment[name] - Demand[name]
            ExportLimit[name in sys.regions.names], NetPosition[name] ≤ sum(LineCapacity_forward[line] for line in lines_from_region[name]) + sum(LineCapacity_backward[line] for line in lines_to_region[name])
            ImportLimit[name in sys.regions.names], NetPosition[name] ≥ -(sum(LineCapacity_backward[line] for line in lines_from_region[name]) + sum(LineCapacity_forward[line] for line in lines_to_region[name]))
            AvailableSupply[name in sys.regions.names], Supply[name] ≤ sum(GeneratorsCapacity[sys.generators.names[gen_index]] for gen_index in sys.region_gen_idxs[region_name_to_index[name]])
            end)

        @objective(m, Min, sum(Curtailment[name]^2 for name in sys.regions.names))
    elseif method.type == :QNTC 
        @constraints(m, begin
            PowerConservation, sum(NetPosition) == 0
            NetPositionComp[name in sys.regions.names], NetPosition[name] == Supply[name] + Curtailment[name] - Demand[name]
            ExportLimit[name in sys.regions.names], NetPosition[name] ≤ sum(NTC_forward[inter] for inter in ints_from_region[name]) + sum(NTC_backward[inter] for inter in ints_to_region[name])
            ImportLimit[name in sys.regions.names], NetPosition[name] ≥ -(sum(NTC_backward[inter] for inter in ints_from_region[name]) + sum(NTC_forward[inter] for inter in ints_to_region[name]))
            AvailableSupply[name in sys.regions.names], Supply[name] ≤ sum(GeneratorsCapacity[sys.generators.names[gen_index]] for gen_index in sys.region_gen_idxs[region_name_to_index[name]])
            end)
        
        @objective(m, Min, sum(Curtailment[name]^2 for name in sys.regions.names))
    elseif method.type == :NTC 
        @constraints(m, begin
            PowerConservation, sum(NetPosition) == 0
            NetPositionComp[name in sys.regions.names], NetPosition[name] == Supply[name] + Curtailment[name] - Demand[name]
            ExportLimit[name in sys.regions.names], NetPosition[name] ≤ sum(NTC_forward[inter] for inter in ints_from_region[name]) + sum(NTC_backward[inter] for inter in ints_to_region[name])
            ImportLimit[name in sys.regions.names], NetPosition[name] ≥ -(sum(NTC_backward[inter] for inter in ints_from_region[name]) + sum(NTC_forward[inter] for inter in ints_to_region[name]))
            AvailableSupply[name in sys.regions.names], Supply[name] ≤ sum(GeneratorsCapacity[sys.generators.names[gen_index]] for gen_index in sys.region_gen_idxs[region_name_to_index[name]])
            end)
        
        @objective(m, Min, sum(Curtailment[name] for name in sys.regions.names))
    elseif method.type == :NTC_Line
        @constraints(m, begin
            PowerConservation, sum(NetPosition) == 0
            NetPositionComp[name in sys.regions.names], NetPosition[name] == Supply[name] + Curtailment[name] - Demand[name]
            ExportLimit[name in sys.regions.names], NetPosition[name] ≤ sum(LineCapacity_forward[line] for line in lines_from_region[name]) + sum(LineCapacity_backward[line] for line in lines_to_region[name])
            ImportLimit[name in sys.regions.names], NetPosition[name] ≥ -(sum(LineCapacity_backward[line] for line in lines_from_region[name]) + sum(LineCapacity_forward[line] for line in lines_to_region[name]))
            AvailableSupply[name in sys.regions.names], Supply[name] ≤ sum(GeneratorsCapacity[sys.generators.names[gen_index]] for gen_index in sys.region_gen_idxs[region_name_to_index[name]])
            end)
        
        @objective(m, Min, sum(Curtailment[name] for name in sys.regions.names))
    elseif method.type == :Autarky 
        @constraints(m, begin
            PowerConservation, sum(NetPosition) == 0
            NetPositionComp[name in sys.regions.names], NetPosition[name] == Supply[name] + Curtailment[name] - Demand[name]
            ExportLimit[name in sys.regions.names], NetPosition[name] ≤ 0.0
            ImportLimit[name in sys.regions.names], NetPosition[name] ≥ 0.0
            AvailableSupply[name in sys.regions.names], Supply[name] ≤ sum(GeneratorsCapacity[sys.generators.names[gen_index]] for gen_index in sys.region_gen_idxs[region_name_to_index[name]])
            end)
        
        @objective(m, Min, sum(Curtailment[name] for name in sys.regions.names))
    elseif method.type == :Copperplate 
        @constraints(m, begin
            PowerConservation, sum(NetPosition) == 0
            NetPositionComp[name in sys.regions.names], NetPosition[name] == Supply[name] + Curtailment[name] - Demand[name]
            AvailableSupply[name in sys.regions.names], Supply[name] ≤ sum(GeneratorsCapacity[sys.generators.names[gen_index]] for gen_index in sys.region_gen_idxs[region_name_to_index[name]])
            end)
        
        @objective(m, Min, sum(Curtailment[name] for name in sys.regions.names))
    elseif method.type == :Nodal
        buses = string.(1:length(sys.grid["bus"]))
        region_to_bus = Dict([name => [] for name in sys.regions.names])
        bus_to_area = Dict(bus =>string(sys.grid["bus"][bus]["area"]) for bus in buses)
        for bus in buses
            push!(region_to_bus[bus_to_area[bus]], bus)
        end

        regional_demand = Dict([name => 0.0 for name in sys.regions.names])

        bus_load = Dict([name => 0.0 for name in buses])
        for (load_id,load) in sys.grid["load"]
            bus_load[string(load["load_bus"])] += load["pd"]
            regional_demand[bus_to_area[string(load["load_bus"])]]+= load["pd"]
        end

        for bus in buses
            if regional_demand[bus_to_area[bus]] == 0.0 #no demand in the regional basecase. Assume equal split
                bus_load[bus] = length(region_to_bus[bus_to_area[bus]])
            else
                bus_load[bus] = bus_load[bus]/regional_demand[bus_to_area[bus]]
            end
        end

        bus_to_generator = Dict(bus => [] for bus in buses)
        for gen in sys.generators.names
            push!(bus_to_generator[split(gen,"_")[end]], gen)
        end
        @variables(m, begin
            NodalPosition[bus in buses]
            NodalInjection[bus in buses]
            NodalCurtailment[bus in buses] ≥ 0
            NodalDemand[bus in buses] ≥ 0
            NodalSupply[bus in buses] ≥ 0
            LineFlow[Line in sys.lines.names]
        end)

        #This has to be refined
        bus_to_ptdf_index = Dict([buses[i] => i for i in 1:length(buses)])
        line_to_ptdf_index = Dict()
        for i in 1:length(sys.grid["branch"])
            push!(line_to_ptdf_index, "L-"*string(sys.grid["branch"][string(i)]["f_bus"])*"_"*string(sys.grid["branch"][string(i)]["t_bus"]) => i)
        end

        @constraints(m, begin
            NodalPositionComputaiton[bus in buses], NodalPosition[bus] == NodalInjection[bus] - sum(string(sys.grid["branch"][string(line_to_ptdf_index[line])]["f_bus"]) == bus ? LineFlow[line] : 0.0  for line in sys.lines.names) +sum(string(sys.grid["branch"][string(line_to_ptdf_index[line])]["t_bus"]) == bus ? LineFlow[line] : 0.0  for line in sys.lines.names)
            NodalInjectionComputaiton[bus in buses], NodalInjection[bus] == NodalSupply[bus] + NodalCurtailment[bus] - NodalDemand[bus]
            NodalSupplyCOmputaiton[bus in buses], NodalSupply[bus] ≤ sum(GeneratorsCapacity[gen] for gen in bus_to_generator[bus])
            NodalDemandShare[bus in buses], NodalDemand[bus] == bus_load[bus]*Demand[bus_to_area[bus]]
            NodalCurtailmentCap[bus in buses], NodalCurtailment[bus] ≤ NodalDemand[bus]
            ZonalPosition[region_name in sys.regions.names], NetPosition[region_name] == sum(NodalPosition[bus] for bus in region_to_bus[region_name])
            ZonalCurtailment[region_name in sys.regions.names], Curtailment[region_name] == sum(NodalCurtailment[bus] for bus in region_to_bus[region_name])
            PowerConservation, sum(NetPosition) == 0
            LineLimit_forward[line in sys.lines.names], LineFlow[line] ≤ LineCapacity_forward[line]
            LineLimit_backward[line in sys.lines.names], -LineFlow[line] ≤ LineCapacity_backward[line]
            LineFlowComp[line in sys.lines.names], LineFlow[line] == sum(sys.grid["ptdf"][line_to_ptdf_index[line], bus_to_ptdf_index[bus]]* NodalInjection[bus] for bus in buses)
            AvailableSupply[name in sys.regions.names], Supply[name] ≤ sum(GeneratorsCapacity[sys.generators.names[gen_index]] for gen_index in sys.region_gen_idxs[region_name_to_index[name]])
            end)
        
        @objective(m, Min, sum(Curtailment[name] for name in sys.regions.names))
    else
        @error "Unrecognized method type: "*string(method.type)
    end
    return m
end

#line_to_ptdf_index[line]