using Revise
using ResourceAdq
using PowerModels
using DataFrames
using Dates
using Polyhedra, Plots
cd("/Users/tborbath/.julia/dev/ResourceAdq/test")

samples_no = 1
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
    merge!(sys.grid,pm_input)
    compute_nPTDF!(sys)
    sys.grid["minram"] =80/100
    compute_GSK_proportional!(sys)
    compute_zPTDF_and_RAM!(sys)
    add_virtual_areas_to_zPTDF!(sys)
    compute_basecase_flows!(sys)
    compute_final_domain!(sys)
    compute_NTCs_f!(sys)
    validate(sys)
    return sys
end



function compose_polyhedra(sModel)
    n_area = length(sModel.grid["zPTDF"].axes[2])
    p = HyperPlane(ones(n_area), 0)
    for i_cnec in sModel.grid["zPTDF"].axes[1]
         coef = sModel.grid["zPTDF"][i_cnec,:].data
         RAM = sModel.grid["RAM"][i_cnec]
         p = intersect(p, HalfSpace(coef, RAM))
         p = intersect(p, HalfSpace(coef.*-1, RAM))
    end 
   return p
    
    @time poly = polyhedron(p)
    #fixandeliminate(poly,[4],[0])
    return poly
 end

 function compose_polyhedra_NTC(sModel)
    areas = sModel.grid["zPTDF"].axes[2]
    n_area = length(areas)
    p = HyperPlane(ones(n_area), 0)
    maxnp  = zeros(n_area)
    minnp  = zeros(n_area)
    area_order =Dict([areas[i]=>i for i in 1:n_area])
    for i_ntc in eachrow(sModel.grid["NTC_df"])
        minnp[area_order[i_ntc[:F_area]]] += i_ntc[:Value]
        maxnp[area_order[i_ntc[:T_area]]] += i_ntc[:Value]
    end
    for i in 1:n_area
        dims = zeros(n_area)
        dims_o = zeros(n_area)
        dims[i] = 1 
        p = intersect(p, HalfSpace(dims, minnp[i]))
        dims_o[i] = -1
        p = intersect(p, HalfSpace(dims_o, maxnp[i]))
    end
    @time poly = polyhedron(p)
    return poly
 end


function plot_poly(sys, p_proj_dim)
    p = plot(ratio = :equal)
    p_fb = compose_polyhedra(sys)
    p_ntc = compose_polyhedra_NTC(sys)
    plot!(p,project(p_fb, p_proj_dim),ratio = :equal, alpha = 0.5)
    plot!(p,project(p_ntc, p_proj_dim),ratio = :equal, alpha = 0.5)
    return p
end


function compose_polyhedra_ztz(sModel)
    n_area = length(sModel.grid["ztzPTDF"].axes[2])
    p = HyperPlane(ones(n_area), 0)
    for i_cnec in sModel.grid["ztzPTDF"].axes[1]
         coef = sModel.grid["ztzPTDF"][i_cnec,:].data
         RAM = sModel.grid["RAM_ztz"][i_cnec]
         p = intersect(p, HalfSpace(coef, RAM))
    end 
    @time poly = polyhedron(p)
    #fixandeliminate(poly,[4],[0])
    return poly
 end

 function compose_polyhedra_NTC_ztz(sModel)
    areas = sModel.grid["ztzPTDF"].axes[2]
    n_area = length(areas)
    p = HyperPlane(ones(n_area), 0)
    area_order =Dict([areas[i]=>i for i in 1:n_area])
    for i_ntc in eachrow(sModel.grid["NTC_df"])
        dims = zeros(n_area)
        dims[area_order[i_ntc[:Name]]] = 1
        p = intersect(p, HalfSpace(dims, i_ntc[:Value]))
    end
    @time poly = polyhedron(p)
    return poly
 end
 function plot_poly_ztz(sys, p_proj_dim)
    p = plot(ratio = :equal)
    p_fb = compose_polyhedra_ztz(sys)
    p_ntc = compose_polyhedra_NTC_ztz(sys)
    plot!(p,project(p_fb, p_proj_dim),ratio = :equal, alpha = 0.5)
    plot!(p,project(p_ntc, p_proj_dim),ratio = :equal, alpha = 0.5)
    return p
end

function compose_polyhedra_f(sModel)
    n_area = length(sModel.grid["zPTDF_f"].axes[2])
    p = HyperPlane(ones(n_area), 0)
    for i_cnec in sModel.grid["zPTDF_f"].axes[1]
         coef = sModel.grid["zPTDF_f"][i_cnec,:].data
         RAM = sModel.grid["RAM_f"][i_cnec]
         p = intersect(p, HalfSpace(coef, RAM))
    end 
    @time poly = polyhedron(p)
    poly = case == "RTS_GMLC" ? fixandeliminate(poly,[4],[0]) : poly
    return poly
 end


 
function plot_poly_f(sys, p_proj_dim)
    p = plot(ratio = :equal)
    p_fb = compose_polyhedra_f(sys)
    p_ntc = compose_polyhedra_NTC(sys)
    plot!(p,project(p_fb, p_proj_dim),ratio = :equal, alpha = 0.5)
    plot!(p,project(p_ntc, p_proj_dim),ratio = :equal, alpha = 0.5)
    return p
end

sysModel = read_model(case)
plot_poly_f(sysModel, [2;3])
#rams = compute_final_domain!(sysModel)