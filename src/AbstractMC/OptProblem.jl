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
        buses = keys(sys.grid["bus"])
        region_to_bus = Dict([name => [] for name in sys.regions.names])
        @show region_to_bus
        for bus in buses
            push!(region_to_bus[string(sys.grid["bus"][bus]["area"])], bus)
        end

        @variables(m, begin
            NodalPosition[bus in buses]
            NodalCurtailment[bus in buses] ≥ 0
        end)

        @constraints(m, begin
            ZonalPosition[region_name in sys.regions.names], NetPosition[region_name] == sum(NodalPosition[bus] for bus in region_to_bus[region_name])
            PowerConservation, sum(NetPosition) == 0
            NetPositionComp[name in sys.regions.names], NetPosition[name] == Supply[name] + Curtailment[name] - Demand[name]
            AvailableSupply[name in sys.regions.names], Supply[name] ≤ sum(GeneratorsCapacity[sys.generators.names[gen_index]] for gen_index in sys.region_gen_idxs[region_name_to_index[name]])
            end)
        
        @objective(m, Min, sum(Curtailment[name] for name in sys.regions.names))
    else
        @error "Unrecognized method type: "*string(method.type)
    end
    rm("model.txt")
    open("model.txt","a") do io
        print(io,m)
    end
    return m
end