using Revise
using ResourceAdq
using PowerModels
using DataFrames
using Dates
cd("/Users/tborbath/.julia/dev/ResourceAdq/test")

samples_no = 3
seed = 10232
threaded = true
case = "RTS_GMLC"
case = "case5"
function read_model(p_case)
    if p_case=="RTS_GMLC"
        sys = read_XLSX("test_inputs/RTS_GMLC/RTS_GMLC.xlsx")
        pm_input =PowerModels.parse_file("test_inputs/rts_gmlc/RTS_GMLC.m")
    elseif p_case == "case5"
        sys = read_XLSX("test_inputs/case5/case5.xlsx")
        pm_input =PowerModels.parse_file("test_inputs/case5/case5.m")
    else 
        @error "Unrecognized test case with name: "*p_case
    end
    pm_input_simple =  PowerModels.make_basic_network(pm_input)
    pm_input["ptdf"] = PowerModels.calc_basic_ptdf_matrix(pm_input_simple)
    merge!(sys.grid,pm_input)
    validate(sys)
    return sys
end

function update_input!(p_input, p_sys, p_ts)
    #Update generator availability
    gen_name_to_id = Dict([i_gen["name"]=> i_gen_id for (i_gen_id, i_gen) in p_sys.grid["gen"]])
    for i in 1:length(p_sys.generators)
        p_input["gen"][gen_name_to_id[p_sys.generators.names[i]]]["pmin"] = 0.0
        p_input["gen"][gen_name_to_id[p_sys.generators.names[i]]]["pmax"]= p_sys.generators.capacity[i,p_ts]
    end
    regional_demand = Dict([name => 0.0 for name in p_sys.regions.names])
    buses = [p_sys.grid["bus"][string(i)]["name"] for i in keys(p_sys.grid["bus"])]#string.(1:length(sys.grid["bus"]))
    bus_name_to_number = Dict([bus["name"]=>id for (id,bus) in p_sys.grid["bus"]])
    bus_to_area = Dict(bus =>string(p_sys.grid["area_name"][string(p_sys.grid["bus"][bus_name_to_number[bus]]["area"])]["name"]) for bus in buses)
    area_name_to_id =Dict([p_sys.regions.names[i]=>i for i in 1:length(p_sys.regions)])
    region_to_bus = Dict([name => [] for name in p_sys.regions.names])
    for bus in buses
        push!(region_to_bus[bus_to_area[bus]], bus)
    end
    bus_load = Dict([name => 0.0 for name in buses])
    for (load_id,load) in p_sys.grid["load"]
        bus_load[p_sys.grid["bus"][string(load["load_bus"])]["name"]] += load["pd"]
        regional_demand[bus_to_area[p_sys.grid["bus"][string(load["load_bus"])]["name"]]]+= load["pd"]
    end

    for bus in buses
        if regional_demand[bus_to_area[bus]] == 0.0 #no demand in the regional basecase. Assume equal split
            bus_load[bus] = length(region_to_bus[bus_to_area[bus]])
        else
            bus_load[bus] = bus_load[bus]/regional_demand[bus_to_area[bus]]
        end
    end
    bus_name_to_load_id = Dict([p_sys.grid["bus"][string(i_load["load_bus"])]["name"]=>i_load_id for (i_load_id, i_load) in p_sys.grid["load"]])
    for bus in buses
        p_input["load"][bus_name_to_load_id[bus]]["pd"]=bus_load[bus] *p_sys.regions.load[area_name_to_id[bus_to_area[bus]], p_ts]/100
    end
    return p_input
end

function compute_net_positions(p_solution, p_input)
    NetPositions = zeros(3)
    for (i_gen_id, i_gen) in p_input["gen"]
        NetPositions[p_input["bus"][string(i_gen["gen_bus"])]["area"]]+=p_solution["solution"]["gen"][i_gen_id]["pg"]
    end
    for (i_load_id, i_load) in p_input["load"]
        NetPositions[p_input["bus"][string(i_load["load_bus"])]["area"]]-=p_input["load"][i_load_id]["pd"]
    end
    @assert abs(sum(NetPositions))< 0.01 "Net position mismatch"
    return Dict([p_input["area_name"][string(i)]["name"]=> NetPositions[i]*100 for i in 1:length(p_input["area_name"])])
end

function compute_basecase_flows_and_NPs(p_sysModel)
    base_Flows = DataFrame(TimeStamp = Int64[])
    base_NPs = DataFrame(TimeStamp = Int64[])
    input = deepcopy(p_sysModel.grid)
    for ts in 1:size(p_sysModel.regions.load)[2]
        @info "Running basecase powerflow for timestep: "*string(ts)
        input = update_input!(input, p_sysModel, ts)
        solution = PowerModels.solve_dc_opf(input, Gurobi.Optimizer)
        i_flows = Dict([p_sysModel.grid["branch"][i_line_id]["name"] => i_line["pf"]*100 for (i_line_id, i_line) in solution["solution"]["branch"]])
        if haskey(solution,"dcline")
            merge!(i_flows,Dict([p_sysModel.grid["dcline"][i_line_id]["name"] => i_line["pf"]*100 for (i_line_id, i_line) in solution["solution"]["dcline"]]))
        end
        push!(base_Flows, merge(Dict("TimeStamp"=>ts), i_flows), cols=:union)
        push!(base_NPs,merge(Dict("TimeStamp"=>ts),compute_net_positions(solution, input)), cols=:union)
    end
    return base_Flows, base_NPs
end
#sysModel = read_model(case)
#df_Flows, df_NPs = compute_basecase_flows_and_NPs(sysModel)
function get_GSK_proportional!(p_sysModel)
    branch_to_index = Dict([i_line["name"]=> i_line["index"] for i_line in values(p_sysModel.grid["branch"])])
    bus_to_index = Dict([i_bus["name"]=> i_bus["index"] for i_bus in values(p_sysModel.grid["bus"])])
    gen_to_bus = Dict([i_gen["name"]=> p_sysModel.grid["bus"][string(i_gen["gen_bus"])]["name"] for i_gen in values(p_sysModel.grid["gen"])])
    gen_to_area = Dict([i_gen["name"]=> p_sysModel.grid["area_name"][string(p_sysModel.grid["bus"][string(i_gen["gen_bus"])]["area"])]["name"] for i_gen in values(p_sysModel.grid["gen"])])
    area_to_index = Dict([i_area["name"]=> i_area["index"] for i_area in values(p_sysModel.grid["area_name"])])
    n_area = length(p_sysModel.grid["area_name"])
    n_bus = size(p_sysModel.grid["ptdf"])[2]
    GSK = zeros(n_bus, n_area)
    for i_gen in values(p_sysModel.grid["gen"])
        g_name = string(i_gen["name"])
        #Here some non price responsive generators could be filtered out
        GSK[bus_to_index[gen_to_bus[g_name]], area_to_index[gen_to_area[g_name]]] += i_gen["pg"]
    end
    area_gen = zeros(n_area)
    for i_col in 1:n_area
        area_gen[i_col] = sum(GSK[:,i_col])
    end
    for i_col in 1:n_area
        for i_row in 1:n_bus
            GSK[i_row, i_col] = GSK[i_row, i_col]/area_gen[i_col]
        end
    end
    p_sysModel.grid["GSK"] = GSK
    p_sysModel.grid["br_to_idx"] = branch_to_index
    p_sysModel.grid["bus_to_idx"] = bus_to_index
end

function compute_zPTDF!(p_sysModel)
    p_sysModel.grid["zPTDF"] = p_sysModel.grid["ptdf"]*p_sysModel.grid["GSK"]
end
function add_virtual_areas_to_zptdf(p_sysModel)
end

get_GSK_proportional!(sysModel)
compute_zPTDF!(sysModel)
sysModel.grid
#=

=#

#sysModel_rts = read_model("RTS_GMLC")




