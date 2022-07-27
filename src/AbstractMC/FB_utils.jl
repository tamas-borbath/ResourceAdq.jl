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
function compute_NTCs!(sys)
    minram = 1
    NTCs = DataFrame()
    br_limits = Dict([sys.lines.names[i] => sys.lines.forward_capacity[i,1] for i in 1:length(sys.lines)])
    for i_int in 1:length(sys.interfaces)
        from_area = sys.regions.names[sys.interfaces.regions_from[i_int]]
        to_area = sys.regions.names[sys.interfaces.regions_to[i_int]]
        push!(NTCs, Dict(:Name=>from_area*">"*to_area, :F_area => from_area, :T_area=>to_area), cols = :union)
        push!(NTCs, Dict(:Name=>to_area*">"*from_area, :F_area => to_area, :T_area=>from_area), cols = :union)
    end
    for i in 1:length(sys.grid["dcline"])
        from_area = "Virtual_"*sys.grid["dcline"][string(i)]["name"]*"_f"
        to_area = "Virtual_"*sys.grid["dcline"][string(i)]["name"]*"_t"
        push!(NTCs, Dict(:Name=>from_area*">"*to_area, :F_area => from_area, :T_area=>to_area), cols = :union)
        push!(NTCs, Dict(:Name=>to_area*">"*from_area, :F_area => to_area, :T_area=>from_area), cols = :union)
    end
    n_NTC = size(NTCs)[1]
    zPTDF = sys.grid["zPTDF"]
    n_cnec = size(zPTDF)[1]
    ztzPTDF = zeros(n_cnec, n_NTC)
    ztzPTDF_o = zeros(n_cnec, n_NTC)
    NTC_to_idx = Dict()
    for i in 1:n_NTC
        i_NTC = NTCs[i,:]
        from_idx = sys.grid["area_to_idx"][i_NTC[:F_area]]
        to_idx = sys.grid["area_to_idx"][i_NTC[:T_area]]
        ztzPTDF[:,i] = max.(0,zPTDF[:,from_idx]-zPTDF[:,to_idx])
        ztzPTDF_o[:,i] = max.(0,-(zPTDF[:,from_idx]-zPTDF[:,to_idx]))
        push!(NTC_to_idx, i_NTC[:Name]=>i)
    end
    @show NTC_to_idx
    RAM = zeros(n_cnec)
    for (br_name, br_id) in sys.grid["br_to_idx"]
        RAM[br_id] = minram * br_limits[br_name]
    end
    RAM = [RAM; RAM]
    ztzPTDF = [ztzPTDF; ztzPTDF_o]
    n_cnec = n_cnec *2 
    #add HVDC limits
    for i_NTC in eachrow(NTCs)
        if split(i_NTC[:F_area],"_")[1] == "Virtual"
            n_cnec +=1
            ztz = zeros(n_NTC)
            ztz[NTC_to_idx[i_NTC[:Name]]] = 1
            ztzPTDF = [ztzPTDF; transpose(ztz)]
            RAM = [RAM; 100]
        end
    end
    ATC = ones(n_NTC) 
    for i in 1:10
        #@info "Iteration "*string(1)*" :"*string(ATC)
        RAM_ATC = RAM - ztzPTDF*ATC
        increment = ones(n_NTC)*500
        for i_cnec in 1:n_cnec
            n_non_zero_borders = sum([value == 0.0 ? 0 : 1 for value in ztzPTDF[i_cnec,:]])
            share = RAM_ATC[i_cnec]/n_non_zero_borders
            for i_area in 1:n_NTC
                if ztzPTDF[i_cnec, i_area] != 0.0 
                    increment[i_area] = min(increment[i_area],share/ztzPTDF[i_cnec, i_area])
                end
            end
        end
        delta = sum(increment)
        ATC = ATC + increment
        #@info "Changes after this iteration:"*string(increment)        
        if delta <0.001
           # @info "Converged"
            ATC = round.(ATC)
            break
        end
        
    end
    sys.grid["NTC"] = ATC
    sys.grid["NTC_to_idx"] = NTC_to_idx
end