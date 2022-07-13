function validate(sys::SystemModel; verbose=true)
    @info "Model Validation started"
    if length(sys.grid)>1 
        verbose && @info "Grid Model Found"
        @assert haskey(sys.grid,"gen")
        #Generator numbers match
        @assert length(sys.generators.names) == length(sys.grid["gen"])
        verbose && @info "Same number of generators in grid model as in inputs"
        #generator names match
        verbose && @info "Name corss check started"
        for (i_gen_id, i_gen) in sys.grid["gen"]
            @assert haskey(i_gen,"name")
            @assert i_gen["name"] in sys.generators.names "Generator not found in XLSX file with name: "*i_gen["name"]
        end

        @assert haskey(sys.grid,"branch")
        #Branch numbers match
        @assert length(sys.lines.names) == length(sys.grid["branch"])
        verbose && @info "Same number of branches in grid model as in inputs"
        #generator names match
        verbose && @info "Name corss check started"
        for (i_obj_id, i_obj) in sys.grid["branch"]
            @assert haskey(i_obj,"name")
            @assert i_obj["name"] in sys.lines.names "Line not found in XLSX file with name: "*i_obj["name"]
        end
        verbose && @info "Name cross check finished"
    end 
    @info "Modal Validation finished"
    return true
end