using PowerModels
const _PM = PowerModels
function PowerModelOptProblem(sys::SystemModel)
    pm_data = _PM.instantiate_model(sys.grid, DCPPowerModel, build_opf_ptdf)
    m = pm_data.model
    return m
    set_optimizer(m, SOLVER.Optimizer)
    set_optimizer_attribute(m, "OutputFlag", 0) 
    region_name_to_index = Dict([sys.regions.names[i] => i for i in 1:length(sys.regions.names)])
    lines_to_region = Dict(name => [] for name in sys.regions.names)
    lines_from_region = Dict(name => [] for name in sys.regions.names)
    for i in 1:length(sys.interfaces)
        for i_line in sys.interface_line_idxs[i]
            push!(lines_from_region[sys.regions.names[sys.interfaces.regions_from[i]]],sys.lines.names[i_line])
            push!(lines_to_region[sys.regions.names[sys.interfaces.regions_to[i]]],sys.lines.names[i_line])
        end
    end

    @variables(m, begin
        NetPosition[name in sys.regions.names]
        Curtailment[name in sys.regions.names] ≥ 0
        Supply[name in sys.regions.names] ≥ 0
        Demand[name in sys.regions.names] == 10000, Param()
        GeneratorsCapacity[Gen in sys.generators.names] == 1000, Param()
        LineCapacity_forward[Line in sys.lines.names] == 100, Param()
        LineCapacity_backward[Line in sys.lines.names] == 7, Param()
    end)
    
    @constraints(m, begin
        PowerConservation, sum(NetPosition) == 0
        NetPositionComp[name in sys.regions.names], NetPosition[name] == Supply[name] + Curtailment[name] - Demand[name]
        ExportLimit[name in sys.regions.names], NetPosition[name] ≤ sum(LineCapacity_forward[line] for line in lines_from_region[name]) + sum(LineCapacity_backward[line] for line in lines_to_region[name])
        ImportLimit[name in sys.regions.names], NetPosition[name] ≥ -(sum(LineCapacity_backward[line] for line in lines_from_region[name]) + sum(LineCapacity_forward[line] for line in lines_to_region[name]))
        AvailableSupply[name in sys.regions.names], Supply[name] ≤ sum(GeneratorsCapacity[sys.generators.names[gen_index]] for gen_index in sys.region_gen_idxs[region_name_to_index[name]])
    end)
    @objective(m, Min, sum(Curtailment[name] for name in sys.regions.names))
    return m
end
