function validate(sys::SystemModel)
    @info "Model Validation started"
    if length(sys.grid)>1 
        @assert haskey(sys.grid,"gen")
        @assert length(sys.generators.names) == length(sys.grid["gen"])
        for (i_gen_id, i_gen) in sys.grid["gen"]
            @assert haskey(i_gen,"name")
            @assert i_gen["name"] in sys.generators.names "Generator not found in XLSX file with name: "*i_gen["name"]
        end

        @assert haskey(sys.grid,"branch")
        @assert sum([split(category,"_")[end] == "AC" ? 1 : 0 for category in sys.lines.categories]) == length(sys.grid["branch"])
        for (i_obj_id, i_obj) in sys.grid["branch"]
            @assert haskey(i_obj,"name")
            @assert i_obj["name"] in sys.lines.names "Line not found in XLSX file with name: "*i_obj["name"]
        end


        @assert sum([split(category,"_")[end] == "DC" ? 1 : 0 for category in sys.lines.categories]) == length(sys.grid["dcline"])
        for (i_obj_id, i_obj) in sys.grid["dcline"]
            @assert haskey(i_obj,"name")
            @assert i_obj["name"] in sys.lines.names "DCLine not found in XLSX file with name: "*i_obj["name"]
        end

        @assert haskey(sys.grid,"area_name")
        @assert length(sys.regions.names) == length(sys.grid["area_name"])
        for (i_obj_id, i_obj) in sys.grid["area_name"]
            @assert haskey(i_obj,"name")
            @assert i_obj["name"] in sys.regions.names "Region not found in XLSX file with name: "*i_obj["name"]
        end
    end 
    @info "Modal Validation finished"
    return true
end
function read_test_model(p_case; verbose = false)
    @info "Loading $p_case data from file" 
    verbose ? false : PowerModels.silence() 
    if p_case=="RTS_GMLC"
        sys = read_XLSX("test_inputs/RTS_GMLC/RTS_GMLC.xlsx", verbose)
        pm_input =PowerModels.parse_file("test_inputs/rts_gmlc/RTS_GMLC.m")
    elseif p_case == "case5"
        sys = read_XLSX("test_inputs/case5/case5.xlsx")
        pm_input =PowerModels.parse_file("test_inputs/case5/case5.m")
    else 
        @error "Unrecognized test case with name: "*p_case
    end
    merge!(sys.grid,pm_input)
    @info "Computing flow domains" 
    compute_nPTDF!(sys)
    sys.grid["minram"] =70/100
    compute_GSK_proportional!(sys)
    compute_zPTDF_and_RAM!(sys)
    add_virtual_areas_to_zPTDF!(sys)
    compute_basecase_flows!(sys)
    compute_final_domain!(sys)
    compute_NTCs_f!(sys)
    validate(sys)
    return sys
end