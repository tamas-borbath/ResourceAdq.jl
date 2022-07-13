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
        verbose && @info "Name cross check finished"
    end 
    @info "Modal Validation finished"
    return true
end