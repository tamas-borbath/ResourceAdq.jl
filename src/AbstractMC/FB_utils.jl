function compute_zPTDF!(p_sysModel)
    p_sysModel.grid["zPTDF"] = p_sysModel.grid["ptdf"]*p_sysModel.grid["GSK"]
end
function add_virtual_areas_to_zPTDF!(p_sysModel)
    for (i_dcline_id,i_dcline) in p_sysModel.grid["dcline"]
        f_bus_name = p_sysModel.grid["bus"][string(i_dcline["f_bus"])]["name"]
        f_bus_ptdf_col = p_sysModel.grid["ptdf"][:,p_sysModel.grid["bus_to_idx"][f_bus_name]]
        p_sysModel.grid["zPTDF"] = [p_sysModel.grid["zPTDF"] f_bus_ptdf_col]
        push!(p_sysModel.grid["area_to_idx"], "Virtual_"*i_dcline["name"]*"_f"=>maximum(values(p_sysModel.grid["area_to_idx"]))+1)

        t_bus_name = p_sysModel.grid["bus"][string(i_dcline["t_bus"])]["name"]
        t_bus_ptdf_col = p_sysModel.grid["ptdf"][:,p_sysModel.grid["bus_to_idx"][t_bus_name]]
        p_sysModel.grid["zPTDF"] = [p_sysModel.grid["zPTDF"] t_bus_ptdf_col]
        push!(p_sysModel.grid["area_to_idx"], "Virtual_"*i_dcline["name"]*"_t"=>maximum(values(p_sysModel.grid["area_to_idx"]))+1)
        @info "Created two new areas for HVDC link "*i_dcline["name"]*" connecting bus "*f_bus_name*" to "*t_bus_name
    end
end
function compute_GSK_proportional!(p_sysModel)
    branch_to_index = Dict([i_line["name"]=> i_line["index"] for i_line in values(p_sysModel.grid["simple"]["branch"])])
    bus_to_index = Dict([i_bus["name"]=> i_bus["index"] for i_bus in values(p_sysModel.grid["simple"]["bus"])])
    gen_to_bus = Dict([i_gen["name"]=> p_sysModel.grid["simple"]["bus"][string(i_gen["gen_bus"])]["name"] for i_gen in values(p_sysModel.grid["simple"]["gen"])])
    gen_to_area = Dict([i_gen["name"]=> p_sysModel.grid["area_name"][string(p_sysModel.grid["simple"]["bus"][string(i_gen["gen_bus"])]["area"])]["name"] for i_gen in values(p_sysModel.grid["simple"]["gen"])])
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
    p_sysModel.grid["area_to_idx"] = area_to_index
end