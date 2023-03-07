using XLSX, DataFrames, Dates, TimeZones
function read_data(p_name, p_index_col, p_variables_int, p_variables_float, p_input, p_Length; verbose = false)
    verbose ? println("Loading data for: $p_name") : true
    gens_df = DataFrame(XLSX.gettable(p_input[p_name]))
    DataFrames.sort!(gens_df, p_index_col)
    vars = Dict()
    vars[:names] = gens_df[!,:Names]
    region_names = string.(DataFrames.names(DataFrame(XLSX.gettable(p_input["Regions"]))))
    region_map = Dict([region_names[i] => i for i in 1:length(region_names)])
    if p_name == "Lines"
        interface_names = DataFrame(XLSX.gettable(p_input["Interface"]))[!,:Names]
        interface_map = Dict([interface_names[i] => i for i in 1:length(interface_names)])
    end

    if p_name != "Interface" #Interfaces have no Category
        vars[:categories] = Vector{String}(string.(gens_df[!,:Category]))
    end
    gen_num = length(vars[:names])
    var_tables = Dict()
    for name in  XLSX.sheetnames(p_input)
        if split(name, "-")[1] == p_name && name != p_name
            push!(var_tables, split(name,"-")[2] => DataFrame(XLSX.gettable(p_input[name])))
        end
    end
    
    for i_var in p_variables_int
        verbose ? println("Variable: $i_var") : true
        if p_name == "Interface" && i_var in [:Region_from, :Region_to]
            vars[i_var] = Vector{Int64}([region_map[x] for x in gens_df[!, i_var]])
        else   
            vars[i_var] = Matrix{Int64}(fill(0,gen_num, p_Length))
            for i in 1:gen_num
                if gens_df[i, i_var] == -1 
                    vars[i_var][i,:] = var_tables[string(i_var)][!,vars[:names][i]]
                else
                    vars[i_var][i,:] .= gens_df[i, i_var]
                end
            end
        end
    end
    for i_var in p_variables_float
        vars[i_var] = Matrix{Float64}(fill(0,gen_num, p_Length))
        for i in 1:gen_num
            if gens_df[i, i_var] == -1 
                vars[i_var][i,:] = var_tables[string(i_var)][!,vars[:names][i]]
            else
                vars[i_var][i,:] .= gens_df[i, i_var]
            end
        end
    end
    idxs = Vector{UnitRange{Int64}}()
    gens_df[!,:Rownum] = rownumber.(eachrow(gens_df))
    if p_name == "Lines"
        for i_interface in 1:length(interface_names)
            interface_names[i_interface]
            rows = gens_df[gens_df[!,p_index_col] .== interface_names[i_interface],:Rownum]
            if length(rows) == 0
                push!(idxs, 1:0)
            else
                push!(idxs, minimum(rows):maximum(rows))
            end
        end
    else
        expected_next = 1
        for i_region in 1:length(region_names)
            rows = gens_df[gens_df[!,p_index_col] .== region_names[i_region],:Rownum]
            if length(rows) == 0
                push!(idxs, expected_next:expected_next-1)
            else
                push!(idxs, first(rows):last(rows))
                expected_next = last(rows)+1
            end
        end
    end
    vars[:names] = Vector{String}(string.(vars[:names]))
    global vars[:index] = idxs
    return vars
end
function read_XLSX(p_path; verbose = false, demand_scale = 1.0)
    verbose ? println("Reading model from: $p_path") : true
    input_xlsx = XLSX.readxlsx(p_path)
    #settings
    sheetnames = XLSX.sheetnames(input_xlsx)
    settings_df = DataFrame(XLSX.gettable(input_xlsx["Settings"]))
    settings = Dict()
    for i_row in eachrow(settings_df)
        push!(settings, i_row[:Name] => i_row[:Type])
    end
    #These are not safe for code injection
    EnergyUnit = eval(Meta.parse(settings["EnergyUnit"]))
    TimeUnit = eval(Meta.parse(settings["TimeUnit"]))
    PowerUnit = eval(Meta.parse(settings["PowerUnit"]))
    Length = parse(Int64, settings["Length"])
 #    Lines = parse(Int64, settings["TS_Length"])
    TimeStamp_start = ZonedDateTime(settings["TimeStamp_start"], dateformat"yyyy-mm-dd HH:MM ZZZ")
    TimeStamp_stop = ZonedDateTime(settings["TimeStamp_stop"], dateformat"yyyy-mm-dd HH:MM ZZZ")
    tmp = split(settings["TimeStamp_step"]," ")
    if tmp[2] == "minutes"
        tmpfunc = Minute
    elseif tmp[2] in ["hour","Hour"]
        tmpfunc = Hour
    end
    TS_length = parse(Int64,tmp[1])
    TimeStamp_step = tmpfunc(TS_length)
    
    vars = read_data("Generators",:Region, [:capacity],[:λ, :μ] ,input_xlsx, Length)
     
    generators = Generators{Length,TS_length,TimeUnit,PowerUnit}(
        vars[:names], vars[:categories], vars[:capacity], vars[:λ], vars[:μ])
    gen_regions = vars[:index]

    vars = read_data("Storage", :Region, [:charge_capacity, :discharge_capacity, :energy_capacity],[:charge_efficiency,:discharge_efficiency,:carryover_efficiency,:λ, :μ] ,input_xlsx, Length)
    storages = Storages{Length,TS_length,TimeUnit,PowerUnit,EnergyUnit}(
        vars[:names], vars[:categories],
        vars[:charge_capacity], vars[:discharge_capacity],
        vars[:energy_capacity], vars[:charge_efficiency],
        vars[:discharge_efficiency], vars[:carryover_efficiency],
        vars[:λ], vars[:μ])
    stor_regions = vars[:index]

    vars = read_data("GenStor",:Region, [:charge_capacity, :discharge_capacity, :energy_capacity, :inflow, :gridwithdrawal_capacity, :gridinjection_capacity],[:charge_efficiency,:discharge_efficiency,:carryover_efficiency,:λ, :μ] ,input_xlsx, Length)
  
    generatorstorages = GeneratorStorages{Length,TS_length,TimeUnit,PowerUnit,EnergyUnit}(
        vars[:names], vars[:categories],
        vars[:charge_capacity], vars[:discharge_capacity],
        vars[:energy_capacity], vars[:charge_efficiency],
        vars[:discharge_efficiency], vars[:carryover_efficiency],
        vars[:inflow],
        vars[:gridwithdrawal_capacity], vars[:gridinjection_capacity],
        vars[:λ], vars[:μ])
    genstor_regions = vars[:index]

    vars = read_data("Lines", :Interface, [:forward_capacity, :backward_capacity],[:λ, :μ] ,input_xlsx, Length)

    lines = Lines{Length,TS_length,TimeUnit,PowerUnit}(
        vars[:names], vars[:categories],
        vars[:forward_capacity], vars[:backward_capacity],
        vars[:λ], vars[:μ])
    line_interfaces = vars[:index]
    
    regions_df = DataFrame(XLSX.gettable(input_xlsx["Regions"]))
    regions = Regions{Length,PowerUnit}(
        DataFrames.names(regions_df), Matrix{Int64}(floor.(transpose(Matrix{Int64}(regions_df)).*demand_scale)))

    vars = read_data("Interface",:Names, [:Region_from, :Region_to, :limit_forward, :limit_backward],[] ,input_xlsx, Length)
    interfaces = Interfaces{Length,PowerUnit}(
        vars[:Region_from],vars[:Region_to] ,
        vars[:limit_forward], vars[:limit_backward])
    timestamps = TimeStamp_start:TimeStamp_step:TimeStamp_stop
    return SystemModel(
        regions, interfaces,
        generators, gen_regions, storages, stor_regions,
        generatorstorages, genstor_regions,
        lines, line_interfaces,
        timestamps)
    
end
function collapse_rows(p_df)
    collapse = true
    for i_col in 1:size(p_df)[2]
        col =  p_df[!,i_col]
        collapse = collapse & all(y->y==col[1],col)
    end
    if collapse 
        rtn =  p_df[1, :]
    else
        rtn =  p_df
    end
    return DataFrame(rtn)
end
function collapsable(p_array)
    return all(y->y==p_array[1],p_array)
end
function get_data(p_name, p_type, p_idx, p_region_map)
    base_df = DataFrame(
        Names = p_type.names,
        Category = p_type.categories
    )
    #Region allocation
    if p_name == "Lines"
        base_df[!,:Interface] .= ""
        for i_range in 1:length(p_idx)
            base_df[p_idx[i_range],:Interface] .= p_region_map[i_range]#i_range
        end
    else
        base_df[!,:Region] .= ""
        for i_range in 1:length(p_idx)
            base_df[p_idx[i_range],:Region] .= p_region_map[i_range]
        end
    end
    #Variables
    var_names = setdiff(fieldnames(typeof(p_type)),[:names, :categories])
    dfs = Dict()
    for i_var in var_names
        base_df[!,i_var] .= 0.0
        push!(dfs, i_var => DataFrame())
        for i_unit in 1:length(p_type.names)
            if collapsable(getfield(p_type,i_var)[i_unit,:])
                base_df[i_unit,i_var] = getfield(p_type,i_var)[i_unit,1]
            else
                base_df[i_unit,i_var] = -1
                dfs[i_var][!,Symbol(p_type.names[i_unit])] = getfield(p_type,i_var)[i_unit,:]
            end
        end
    end
    to_export = []
    push!(to_export, p_name => base_df)
    for (k,v) in dfs
        if size(v)[1]>0
            push!(to_export, p_name*"-"*string(k) => v)
        end
    end
    return to_export
end
function get_interfaces_data(p_model, p_region_map)
    p_name = "Interface"
    p_type = p_model.interfaces
    interface_map = Dict([i=> p_region_map[p_model.interfaces.regions_from[i]]*">"*p_region_map[p_model.interfaces.regions_to[i]] for i in 1:length(p_model.interfaces.regions_from)])
    base_df = DataFrame( )
    base_df[!,:Names] = [p_region_map[p_model.interfaces.regions_from[i]]*">"*p_region_map[p_model.interfaces.regions_to[i]] for i in 1:length(p_model.interfaces.regions_from)]
    base_df[!,:Region_from] .= [p_region_map[k] for k in p_model.interfaces.regions_from]
    base_df[!,:Region_to] .= [p_region_map[k] for k in p_model.interfaces.regions_to]
    var_names = setdiff(fieldnames(typeof(p_model.interfaces)),[:regions_from, :regions_to])
    dfs = Dict()
    for i_var in var_names
        base_df[!,i_var] .= 0.0
        push!(dfs, i_var => DataFrame())
        for i_inter in 1:length(p_model.interfaces.regions_from)
            if collapsable(getfield(p_type,i_var)[i_inter,:])
                base_df[i_inter,i_var] = getfield(p_type,i_var)[i_inter,1]
            else
                base_df[i_inter,i_var] = -1
                dfs[i_var][!,Symbol(p_type.names[i_inter])] = getfield(p_type,i_var)[i_inter,:]
            end
        end
    end
    to_export = []
    push!(to_export, p_name => base_df)
    for (k,v) in dfs
        if size(v)[1]>0
            push!(to_export, p_name*"-"*string(k) => v)
        end
    end
    return to_export, interface_map
end
function write_XLSX(p_model, p_path)
    @info "Writing model to: "*p_path
    #Settings

    settings_df = DataFrame(Name = [], Type = [])
    push!(settings_df, (Name = "Length", Type = string(typeof(p_model).parameters[1])))
   # push!(settings_df, (Name = "Lines", Type = string(typeof(p_model).parameters[2])))
    push!(settings_df, (Name = "TimeUnit", Type = string(typeof(p_model).parameters[3])))
    push!(settings_df, (Name = "PowerUnit", Type = string(typeof(p_model).parameters[4])))
    push!(settings_df, (Name = "EnergyUnit", Type = string(typeof(p_model).parameters[5])))
    push!(settings_df, (Name = "TimeStamp_start", Type = Dates.format(p_model.timestamps.start, "yyyy-mm-dd HH:MM ZZZ")))
    push!(settings_df, (Name = "TimeStamp_stop", Type = Dates.format(p_model.timestamps.stop, "yyyy-mm-dd HH:MM ZZZ")))
    push!(settings_df, (Name = "TimeStamp_step", Type = string(p_model.timestamps.step)))
    
    #Stack of data to be exported
    export_stack = []
    #Regions
    regions_df = DataFrame(transpose(p_model.regions.load),p_model.regions.names)
    push!(export_stack, "Regions" => regions_df)
    region_map = Dict()
    for i in 1:length(names(regions_df))
        push!(region_map, i=>names(regions_df)[i])
    end
    interface_df, interface_map = get_interfaces_data(p_model, region_map)
    append!(export_stack,interface_df)
    append!(export_stack,get_data("Generators",p_model.generators, p_model.region_gen_idxs, region_map))
    append!(export_stack,get_data("Storage",p_model.storages, p_model.region_stor_idxs, region_map))
    append!(export_stack,get_data("GenStor",p_model.generatorstorages, p_model.region_genstor_idxs, region_map))
    append!(export_stack,get_data("Lines",p_model.lines, p_model.interface_line_idxs, interface_map))
   

    XLSX.openxlsx(p_path, mode="w") do xf
        XLSX.rename!(xf[1], "Settings")
        XLSX.writetable!(xf[1], collect(DataFrames.eachcol(settings_df)), DataFrames.names(settings_df))
        for (name,df) in export_stack
            sheet = XLSX.addsheet!(xf, string(name))
            XLSX.writetable!(sheet, collect(DataFrames.eachcol(df)), DataFrames.names(df))
        end
    end
end