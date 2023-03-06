function compute_NTCs!(sys)
    NTCs = DataFrame()
    for i_int in 1:length(sys.interfaces)
        from_area = sys.regions.names[sys.interfaces.regions_from[i_int]]
        to_area = sys.regions.names[sys.interfaces.regions_to[i_int]]
        push!(NTCs, Dict(:Name=>from_area*">"*to_area, :F_area => from_area, :T_area=>to_area), cols = :union)
        push!(NTCs, Dict(:Name=>to_area*">"*from_area, :F_area => to_area, :T_area=>from_area), cols = :union)
    end
    n_NTC = size(NTCs)[1]
    
    #take the AC flow domain
    zPTDF = sys.grid["zPTDF"]
    RAM = sys.grid["RAM"]
    cnecs = RAM.axes[1]
    cnecs_f = [cnecs; cnecs.*"_Opposite"]
    RAM_f = JuMP.Containers.DenseAxisArray([RAM.data;RAM.data],cnecs_f) 
    borders = NTCs[!,:Name]
    zPTDF_f = JuMP.Containers.DenseAxisArray([zPTDF;-zPTDF],cnecs_f, zPTDF.axes[2])    
    ztzPTDF = JuMP.Containers.DenseAxisArray(zeros(length(cnecs_f), length(borders)), cnecs_f, borders)
    for i in 1:n_NTC
        border = NTCs[i,:Name]
        from = NTCs[i,:F_area]
        to = NTCs[i,:T_area]
        ztzPTDF[:,border] = max.(0,zPTDF_f[:,from].data-zPTDF_f[:,to].data)
    end
    sys.grid["ztzPTDF"] = ztzPTDF
    sys.grid["RAM_ztz"] = RAM_f
    ATC = zeros(n_NTC) 
    for i in 1:10
     #   @info "Iteration "*string(i)
        RAM_ATC = RAM_f.data - ztzPTDF.data*ATC
        increment = ones(n_NTC)*500
        Constraining_element = string.(zeros(n_NTC))
        for i_cnec in 1:length(cnecs_f)     
            n_non_zero_borders = sum([value == 0.0 ? 0 : 1 for value in ztzPTDF[cnecs_f[i_cnec],:].data])
            share = RAM_ATC[i_cnec]/n_non_zero_borders
            for i_border in 1:length(borders)
                if ztzPTDF[cnecs_f[i_cnec], borders[i_border]] != 0.0 
                    max_bil = share/ztzPTDF[cnecs_f[i_cnec], borders[i_border]]
                    if max_bil<increment[i_border]
                        Constraining_element[i_border] = cnecs_f[i_cnec]
        #                @info "CNEC "*RAM_name[i_cnec]*" constrains the max billateral increase, on  "*NTCs[i_border, :Name]*" to: "*string(max_bil)
                        increment[i_border] = max_bil
                    end
                end
            end
        end
        increment = max.(0.0, increment)
        delta = sum(abs.(increment))
        ATC = ATC + increment
       # @info "Changes after this iteration:"*string(increment)
        new_NTCs = deepcopy(NTCs)
        new_NTCs[!,:Value] = ATC
        new_NTCs[!,:Increment] = increment
        new_NTCs[!,:Constrained_by] = Constraining_element
     #   @show new_NTCs
        if delta <0.001
         #   @info "Converged"
            ATC = round.(ATC)
            break
        end
        
    end
    NTCs[!,:Value] = ATC
    sys.grid["NTC"] = ATC
    sys.grid["NTC_df"] = NTCs
end

function compute_nPTDF!(p_sys)
    p_sys.grid["simple"] =  PowerModels.make_basic_network(p_sys.grid)
    ptdf = PowerModels.calc_basic_ptdf_matrix(p_sys.grid["simple"])
    branches = [string(p_sys.grid["simple"]["branch"][string(i)]["name"]) for i in 1:length(p_sys.grid["simple"]["branch"])]
    buses = [string(p_sys.grid["simple"]["bus"][string(i)]["name"]) for i in 1:length(p_sys.grid["simple"]["bus"])]
    p_sys.grid["nPTDF"] = JuMP.Containers.DenseAxisArray(ptdf, branches, buses)
end

function compute_GSK_proportional!(p_sysModel)
    buses = p_sysModel.grid["nPTDF"].axes[2]
    areas = [string(p_sysModel.grid["area_name"][string(i)]["name"]) for i in 1:length(p_sysModel.grid["area_name"])]
    GSK = JuMP.Containers.DenseAxisArray(zeros(length(buses), length(areas)), buses, areas)
    gen_to_area = Dict([i_gen["name"]=> string(p_sysModel.grid["area_name"][string(p_sysModel.grid["simple"]["bus"][string(i_gen["gen_bus"])]["area"])]["name"]) for i_gen in values(p_sysModel.grid["simple"]["gen"])])
    gen_to_bus = Dict([i_gen["name"]=> string(p_sysModel.grid["simple"]["bus"][string(i_gen["gen_bus"])]["name"]) for i_gen in values(p_sysModel.grid["simple"]["gen"])])
  
    for i_gen in values(p_sysModel.grid["gen"])
        g_name = string(i_gen["name"])
        #Here some non price responsive generators could be filtered out
        GSK[gen_to_bus[g_name], gen_to_area[g_name]] += i_gen["pg"]
    end

    area_gen = zeros(length(areas))
    for i_area in 1:length(areas)
        area_gen[i_area] = sum(GSK[:,areas[i_area]])
    end

    for i_area in 1:length(areas)
        for i_bus in buses
            GSK[i_bus, areas[i_area]] =  GSK[i_bus, areas[i_area]]/area_gen[i_area]
        end
    end
    p_sysModel.grid["GSK"] = GSK
end

function compute_zPTDF_and_RAM!(p_sysModel)
    areas = p_sysModel.grid["GSK"].axes[2]
    cnecs = [string(p_sysModel.grid["CNECs"][string(i)]["name"]) for i in 1:length(p_sysModel.grid["CNECs"])]
    cnecs_to_cne = Dict([string(p_sysModel.grid["CNECs"][string(i)]["name"])=>string(p_sysModel.grid["CNECs"][string(i)]["CNE"]) for i in 1:length(p_sysModel.grid["CNECs"])])
    buses = p_sysModel.grid["GSK"].axes[1]
    zPTDF = JuMP.Containers.DenseAxisArray(zeros(length(cnecs), length(areas)), cnecs, areas)
    br_limits = Dict([p_sysModel.lines.names[i] => p_sysModel.lines.forward_capacity[i,1] for i in 1:length(p_sysModel.lines)])
    RAM = JuMP.Containers.DenseAxisArray(zeros(length(cnecs)), cnecs)
   
    for i_cnec in cnecs
        newline = JuMP.Containers.DenseAxisArray(zeros(length(areas)), areas)
        for i_bus in buses
            for i_area in areas
                newline[i_area] += p_sysModel.grid["GSK"][i_bus, i_area]* p_sysModel.grid["nPTDF"][cnecs_to_cne[i_cnec], i_bus]
            end
        end
        zPTDF[i_cnec,:] = newline
        RAM[i_cnec] = p_sysModel.grid["minram"] * br_limits[cnecs_to_cne[i_cnec]]
    end
    p_sysModel.grid["zPTDF"]=zPTDF
    p_sysModel.grid["RAM"] = RAM
    p_sysModel.grid["cnecs_to_cne"]= cnecs_to_cne
end

function add_virtual_areas_to_zPTDF!(p_sysModel)
    areas = p_sysModel.grid["zPTDF"].axes[2]
    cnecs = p_sysModel.grid["zPTDF"].axes[1]
    for (i_dcline_id,i_dcline) in p_sysModel.grid["dcline"]
        f_bus_name = string(p_sysModel.grid["bus"][string(i_dcline["f_bus"])]["name"])
        t_bus_name = string(p_sysModel.grid["bus"][string(i_dcline["t_bus"])]["name"])
        new_col = JuMP.Containers.DenseAxisArray(zeros(length(cnecs)), cnecs)
        for i_cnec in cnecs
            new_col[i_cnec] =  p_sysModel.grid["nPTDF"][p_sysModel.grid["cnecs_to_cne"][i_cnec], f_bus_name] - p_sysModel.grid["nPTDF"][p_sysModel.grid["cnecs_to_cne"][i_cnec], t_bus_name]
        end
        areas = [areas; "Virtual_"*string(i_dcline["name"])]
        p_sysModel.grid["zPTDF"] = JuMP.Containers.DenseAxisArray([p_sysModel.grid["zPTDF"] new_col], cnecs, areas)
        @info "Created new area for HVDC link "*i_dcline["name"]*" connecting bus "*f_bus_name*" to "*t_bus_name
    end
end

function compute_basecase_flows!(sys)
    results = PowerModels.solve_dc_opf(sys.grid, SOLVER.Optimizer)
    cnecs = sys.grid["zPTDF"].axes[1]
    F_ref = JuMP.Containers.DenseAxisArray(zeros(length(cnecs)), cnecs)
    cne_to_key = Dict([v["name"] => k for (k,v) in sys.grid["branch"]])
    cnecs_to_cne = sys.grid["cnecs_to_cne"]
    for i_cnec in cnecs
        F_ref[i_cnec] = results["solution"]["branch"][cne_to_key[cnecs_to_cne[i_cnec]]]["pf"]*100
    end
    areas = sys.grid["zPTDF"].axes[2]#[]string.([sys.grid["area_name"][string(i)]["name"] for i in 1:length(sys.grid["area_name"])])
    NPs = JuMP.Containers.DenseAxisArray(zeros(length(areas)), areas)
    for (i_br_id, i_br) in sys.grid["branch"]
       NPs[string(sys.grid["area_name"][string(sys.grid["bus"][string(i_br["f_bus"])]["area"])]["name"])] -= results["solution"]["branch"][i_br_id]["pf"]*100
       NPs[string(sys.grid["area_name"][string(sys.grid["bus"][string(i_br["t_bus"])]["area"])]["name"])] += results["solution"]["branch"][i_br_id]["pf"]*100
    end
    dcflows = 0.0
    for (i_br_id, i_br) in sys.grid["dcline"]
        NPs["Virtual_"*i_br["name"]] = results["solution"]["dcline"][i_br_id]["pf"]*100
        dcflows += results["solution"]["dcline"][i_br_id]["pf"]*100
     end
    @assert abs(sum(NPs.data)-dcflows)<1 "Flows mismatch by: "*string(sum(NPs.data)-dcflows)
    F_zero = JuMP.Containers.DenseAxisArray(zeros(length(cnecs)), cnecs)
    for i_cnec in cnecs
        pre_load = F_ref[i_cnec] - sum(NPs[i_area]*sys.grid["zPTDF"][i_cnec, i_area] for i_area in areas) 
        F_zero[i_cnec] = pre_load
    end
    sys.grid["F_zero"] = F_zero
end

function compute_final_domain!(sys)
    zPTDF = sys.grid["zPTDF"]
    F_zero = sys.grid["F_zero"]
    cnecs_to_cne = sys.grid["cnecs_to_cne"]
    br_limits = Dict([sys.lines.names[i] => sys.lines.forward_capacity[i,1] for i in 1:length(sys.lines)])
    cnecs = zPTDF.axes[1]
    cnecs_f = [cnecs; cnecs.*"_Opposite"]
    zPTDF_f = JuMP.Containers.DenseAxisArray([zPTDF; -zPTDF], cnecs_f, zPTDF.axes[2])
    RAM_f = JuMP.Containers.DenseAxisArray(zeros(length(cnecs_f)), cnecs_f)
    for i_cnec in cnecs
        limit = br_limits[cnecs_to_cne[i_cnec]]
        minram = sys.grid["minram"]*limit
        RAM_f[i_cnec] = max(minram, limit - F_zero[i_cnec])
        RAM_f[i_cnec*"_Opposite"] = max(minram, limit + F_zero[i_cnec])
        @assert RAM_f[i_cnec] ≥ minram "Min RAM not reached on: "*i_cnec
        @assert RAM_f[i_cnec*"_Opposite"] ≥ minram "Min RAM not reached on: "*i_cnec
    end
    sys.grid["RAM_f"] = RAM_f
    sys.grid["zPTDF_f"] = zPTDF_f
end

function compute_NTCs_f!(sys)
    NTCs = DataFrame()
    for i_int in 1:length(sys.interfaces)
        from_area = sys.regions.names[sys.interfaces.regions_from[i_int]]
        to_area = sys.regions.names[sys.interfaces.regions_to[i_int]]
        push!(NTCs, Dict(:Name=>from_area*">"*to_area, :F_area => from_area, :T_area=>to_area), cols = :union)
        push!(NTCs, Dict(:Name=>to_area*">"*from_area, :F_area => to_area, :T_area=>from_area), cols = :union)
    end
    n_NTC = size(NTCs)[1]
    
    #take the AC flow domain
    zPTDF_f = sys.grid["zPTDF_f"]
    RAM = sys.grid["RAM_f"]
    cnecs = RAM.axes[1]
    borders = NTCs[!,:Name]
    ztzPTDF = JuMP.Containers.DenseAxisArray(zeros(length(cnecs), length(borders)), cnecs, borders)
    for i in 1:n_NTC
        border = NTCs[i,:Name]
        from = NTCs[i,:F_area]
        to = NTCs[i,:T_area]
        ztzPTDF[:,border] = max.(0,zPTDF_f[:,from].data-zPTDF_f[:,to].data)
    end
    sys.grid["ztzPTDF"] = ztzPTDF
    ATC = zeros(n_NTC) 
    for i in 1:10
       # @info "Iteration "*string(i)
        RAM_ATC = RAM.data - ztzPTDF.data*ATC
        increment = ones(n_NTC)*500
        Constraining_element = string.(zeros(n_NTC))
        for i_cnec in 1:length(cnecs)
            n_non_zero_borders = sum([value == 0.0 ? 0 : 1 for value in ztzPTDF[cnecs[i_cnec],:].data])
            share = RAM_ATC[i_cnec]/n_non_zero_borders
            for i_border in 1:length(borders)
                if ztzPTDF[cnecs[i_cnec], borders[i_border]] != 0.0 
                    max_bil = share/ztzPTDF[cnecs[i_cnec], borders[i_border]]
                    if max_bil<increment[i_border]
                        Constraining_element[i_border] = cnecs[i_cnec]
        #                @info "CNEC "*RAM_name[i_cnec]*" constrains the max billateral increase, on  "*NTCs[i_border, :Name]*" to: "*string(max_bil)
                        increment[i_border] = max_bil
                    end
                end
            end
        end
        increment = max.(0.0, increment)
        delta = sum(abs.(increment))
        ATC = ATC + increment
       # @info "Changes after this iteration:"*string(increment)
        new_NTCs = deepcopy(NTCs)
        new_NTCs[!,:Value] = ATC
        new_NTCs[!,:Increment] = increment
        new_NTCs[!,:Constrained_by] = Constraining_element
       # @show new_NTCs
        if delta <0.001
           # @info "Converged"
            ATC = round.(ATC)
            break
        end
        
    end
    NTCs[!,:Value] = ATC
    sys.grid["NTC"] = ATC
    sys.grid["NTC_df"] = NTCs
end