function OptProblem(sys::SystemModel, method::AbstractMC)
    #build base model 
    m = Model(method.optimizer)

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
    elseif method.type == :NTC_f
        areas = sys.grid["zPTDF"].axes[2]
        maxnp  = JuMP.Containers.DenseAxisArray(zeros(length(areas)), areas)
        minnp  = JuMP.Containers.DenseAxisArray(zeros(length(areas)), areas)
        for i_ntc in eachrow(sys.grid["NTC_df"])
            maxnp[i_ntc[:F_area]] += i_ntc[:Value]
            minnp[i_ntc[:T_area]] += i_ntc[:Value]
        end
        @constraints(m, begin
            PowerConservation, sum(NetPosition) == 0
            NetPositionComp[name in sys.regions.names], NetPosition[name] == Supply[name] + Curtailment[name] - Demand[name]
            ExportLimit[area in sys.regions.names], NetPosition[area] ≤ maxnp[area]
            ImportLimit[area in sys.regions.names], NetPosition[area] ≥ -minnp[area]
            AvailableSupply[name in sys.regions.names], Supply[name] ≤ sum(GeneratorsCapacity[sys.generators.names[gen_index]] for gen_index in sys.region_gen_idxs[region_name_to_index[name]])
            end)
        
        @objective(m, Min, sum(Curtailment[name] for name in sys.regions.names))

    elseif method.type == :QNTC_f
        areas = sys.grid["zPTDF"].axes[2]
        maxnp  = JuMP.Containers.DenseAxisArray(zeros(length(areas)), areas)
        minnp  = JuMP.Containers.DenseAxisArray(zeros(length(areas)), areas)
        for i_ntc in eachrow(sys.grid["NTC_df"])
            maxnp[i_ntc[:F_area]] += i_ntc[:Value]
            minnp[i_ntc[:T_area]] += i_ntc[:Value]
        end
        @constraints(m, begin
            PowerConservation, sum(NetPosition) == 0
            NetPositionComp[name in sys.regions.names], NetPosition[name] == Supply[name] + Curtailment[name] - Demand[name]
            ExportLimit[area in sys.regions.names], NetPosition[area] ≤ maxnp[area]
            ImportLimit[area in sys.regions.names], NetPosition[area] ≥ -minnp[area]
            AvailableSupply[name in sys.regions.names], Supply[name] ≤ sum(GeneratorsCapacity[sys.generators.names[gen_index]] for gen_index in sys.region_gen_idxs[region_name_to_index[name]])
            end)
        
        @objective(m, Min, sum(Curtailment[name]^2 for name in sys.regions.names))
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
        buses = [string(sys.grid["bus"][string(i)]["name"]) for i in keys(sys.grid["bus"])]#string.(1:length(sys.grid["bus"]))
        bus_name_to_number = Dict([bus["name"]=>id for (id,bus) in sys.grid["bus"]])
        region_to_bus = Dict([name => [] for name in sys.regions.names])
        bus_to_area = Dict(bus =>string(sys.grid["area_name"][string(sys.grid["bus"][bus_name_to_number[bus]]["area"])]["name"]) for bus in buses)
        for bus in buses
            push!(region_to_bus[bus_to_area[bus]], bus)
        end

        regional_demand = Dict([name => 0.0 for name in sys.regions.names])

        bus_load = Dict([name => 0.0 for name in buses])
        for (load_id,load) in sys.grid["load"]
            bus_load[sys.grid["bus"][string(load["load_bus"])]["name"]] += load["pd"]
            regional_demand[bus_to_area[sys.grid["bus"][string(load["load_bus"])]["name"]]]+= load["pd"]
        end

        for bus in buses
            if regional_demand[bus_to_area[bus]] == 0.0 #no demand in the regional basecase. Assume equal split
                bus_load[bus] = length(region_to_bus[bus_to_area[bus]])
            else
                bus_load[bus] = bus_load[bus]/regional_demand[bus_to_area[bus]]
            end
        end
        bus_to_generator = Dict(bus => [] for bus in buses)
        for gen in values(sys.grid["gen"])
            push!(bus_to_generator[sys.grid["bus"][string(gen["gen_bus"])]["name"]], string(gen["name"]))
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
            push!(line_to_ptdf_index, sys.grid["branch"][string(i)]["name"] => i)
        end

        ACLines = String[]
        for i in 1:length(sys.lines.categories)
            if split(sys.lines.categories[i],"_")[end]=="AC"
                push!(ACLines, sys.lines.names[i])
            end
        end
        DCLines = String[]
        for i in 1:length(sys.lines.categories)
            if split(sys.lines.categories[i],"_")[end]=="DC"
                push!(DCLines, sys.lines.names[i])
            end
        end
        dcline_to_bus = Dict()
        for dcline in DCLines
            for (i_dcline,pm_dcline) in sys.grid["dcline"]
                if pm_dcline["name"] == dcline
                    push!(dcline_to_bus, dcline => (string(sys.grid["bus"][string(pm_dcline["f_bus"])]["name"]), string(sys.grid["bus"][string(pm_dcline["t_bus"])]["name"])))
                    break 
                end
            end
        end

        @constraints(m, begin
            NodalPositionComputaiton[bus in buses], NodalPosition[bus] == NodalInjection[bus] - sum(sys.grid["bus"][string(sys.grid["branch"][string(line_to_ptdf_index[line])]["f_bus"])]["name"] == bus ? LineFlow[line] : 0.0  for line in ACLines) +sum(sys.grid["bus"][string(sys.grid["branch"][string(line_to_ptdf_index[line])]["t_bus"])]["name"] == bus ? LineFlow[line] : 0.0  for line in ACLines)
            NodalInjectionComputaiton[bus in buses], NodalInjection[bus] == NodalSupply[bus] + NodalCurtailment[bus] - NodalDemand[bus]
            NodalSupplyComputaiton[bus in buses], NodalSupply[bus] ≤ sum(GeneratorsCapacity[gen] for gen in bus_to_generator[bus])
            NodalDemandShare[bus in buses], NodalDemand[bus] == bus_load[bus]*Demand[bus_to_area[bus]]
            NodalCurtailmentCap[bus in buses], NodalCurtailment[bus] ≤ NodalDemand[bus]
            ZonalPosition[region_name in sys.regions.names], NetPosition[region_name] == sum(NodalPosition[bus] for bus in region_to_bus[region_name])
            ZonalCurtailment[region_name in sys.regions.names], Curtailment[region_name] == sum(NodalCurtailment[bus] for bus in region_to_bus[region_name])
            PowerConservation, sum(NetPosition) == 0
            LineLimit_forward[line in sys.lines.names], LineFlow[line] ≤ LineCapacity_forward[line]
            LineLimit_backward[line in sys.lines.names], -LineFlow[line] ≤ LineCapacity_backward[line]
            LineFlowComp[line in ACLines], LineFlow[line] == sum(sys.grid["nPTDF"][line,bus]* NodalInjection[bus] for bus in buses) - sum(sys.grid["nPTDF"][line,dcline_to_bus[dcline][2]]*LineFlow[dcline] - sys.grid["nPTDF"][line,dcline_to_bus[dcline][1]]*LineFlow[dcline] for dcline in DCLines) 
            AvailableSupply[name in sys.regions.names], Supply[name] ≤ sum(GeneratorsCapacity[sys.generators.names[gen_index]] for gen_index in sys.region_gen_idxs[region_name_to_index[name]])
            end)
        
        @objective(m, Min, sum(Curtailment[name] for name in sys.regions.names))
    elseif method.type == :FB_fixed
        CNECs = sys.grid["zPTDF_f"].axes[1]
        @constraints(m, begin
            FB[CNEC in CNECs], sum(sys.grid["zPTDF_f"][CNEC, area]*NetPosition[area] for area in sys.regions.names)  ≤ sys.grid["RAM_f"][CNEC]
            PowerConservation, sum(NetPosition) == 0
            NetPositionComp[name in sys.regions.names], NetPosition[name] == Supply[name] + Curtailment[name] - Demand[name]
            AvailableSupply[name in sys.regions.names], Supply[name] ≤ sum(GeneratorsCapacity[sys.generators.names[gen_index]] for gen_index in sys.region_gen_idxs[region_name_to_index[name]])
        end)

        @objective(m, Min, sum(Curtailment[name]^2 for name in sys.regions.names))
    elseif method.type == :FB_fixed_evolved
        @show DClines = [string(i_dcline["name"]) for (i_id, i_dcline) in sys.grid["dcline"]]
        CNECs = sys.grid["zPTDF_f"].axes[1]

        @variables(m, begin
              HVDC_f[dcline in DClines]
        end)
        @constraints(m, begin
            HVDC_f_cap[dcline in DClines], HVDC_f[dcline] ≤ LineCapacity_forward[dcline]
            HVDC_f_cap_n[dcline in DClines], -HVDC_f[dcline] ≤ LineCapacity_forward[dcline]
            FB[CNEC in CNECs], sum(sys.grid["zPTDF_f"][CNEC, area]*NetPosition[area] for area in sys.regions.names)  + sum(sys.grid["zPTDF_f"][CNEC, "Virtual_"*dcline]*HVDC_f[dcline] for dcline in DClines) ≤ sys.grid["RAM_f"][CNEC]
            PowerConservation, sum(NetPosition) == 0
            NetPositionComp[name in sys.regions.names], NetPosition[name] == Supply[name] + Curtailment[name] - Demand[name]
            AvailableSupply[name in sys.regions.names], Supply[name] ≤ sum(GeneratorsCapacity[sys.generators.names[gen_index]] for gen_index in sys.region_gen_idxs[region_name_to_index[name]])
        end)

        @objective(m, Min, sum(Curtailment[name]^2 for name in sys.regions.names))
    else
        @error "Unrecognized method type: "*string(method.type)
    end
    return m
end

#line_to_ptdf_index[line]