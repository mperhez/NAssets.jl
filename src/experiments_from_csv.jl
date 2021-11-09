# module NAssets
using Distributed
# addprocs(7)    

@everywhere using Agents: vertices
@everywhere using MetaGraphs: add_vertex!, has_edge
@everywhere using Agents, AgentsPlots, Plots, LightGraphs, MetaGraphs, GraphPlot, GraphRecipes, NetworkLayout
@everywhere using Tables, DataFrames
@everywhere using CSV, JSON, Serialization, DelimitedFiles
@everywhere using BritishNationalGrid
@everywhere using ZipFile, Shapefile
@everywhere using Random
@everywhere using Match
@everywhere using LinearAlgebra
@everywhere using StatsBase
@everywhere using Distributions
@everywhere using StatsPlots
@everywhere using SparseArrays
@everywhere using Laplacians
@everywhere using DataStructures
@everywhere using RollingFunctions
@everywhere using BenchmarkTools
@everywhere using Statistics
@everywhere using Logging,LoggingExtras, LoggingFacilities
@everywhere using Dates,TimeZones




#Core structures
@everywhere include("core/core_structs.jl")
#graph-related
@everywhere include("core/graph_functions.jl")
#events
@everywhere include("eve/artificial_events.jl")
#various util functions
@everywhere include("utils/util_functions.jl")
#logging
@everywhere include("utils/logging_functions.jl")
#Plotting functions
@everywhere include("utils/plotting_functions.jl")
# time-to-event functions
@everywhere include("utils/tte_functions.jl")
#running functions
@everywhere include("utils/running_functions.jl")

#maintenance model
@everywhere include("phy/maintenance_model.jl")

@everywhere include("ntw/of_switch.jl")
@everywhere include("ntw/of_control.jl")
@everywhere include("ctl/agent_control.jl")

@everywhere include("phy/physical_model.jl")

@everywhere include("ntw/network_model.jl")
@everywhere include("phy/geo_model.jl")

#Main Functions
@everywhere include("model/netManFunctions.jl")

#Agents.jl function implementation for this model
@everywhere include("model/netManModel.jl")

#Basic queries
#include("model/queries_basic.jl")
#Multiple queries
@everywhere include("ctl/queries_multiple.jl")

export load_run_configs, single_run_with_logging


function find_paths_by_seed(seed,g::G)where G<: AbstractGraph
    Random.seed!(seed)

    cc = closeness_centrality(g)
    cci = sort([ (i,cc[i]) for i=1:length(cc) ],by=last,rev=true)

    pending = cci 
    cp =[]
    coverage = 0.95

        while length(pending) >= (1- coverage) * nv(g)
            pending_i = [ first(p) for p in pending]
            
            #node with the most closeness_centrality
            s = first(first(pending))

            #max distance to any other pending node
            ds = gdistances(g,s)
            sds = sort([(i,ds[i]) for i=1:length(ds) if i in pending_i ],by=last,rev=true)
            d = first(first(sds))
            
            #shortest path between these two nodes
            sp = first(yen_k_shortest_paths(g,s,d).paths)
            push!(cp, sp)

            #remove nodes in the shortest path from pending list
            pending_i = collect(setdiff([ first(p) for p in pending ],Set(sp)))
            # println(pending_i)
            pending = [ p for p in pending  if first(p) in pending_i ]
        end
    return cp
end

function find_services(seed,g::G)where G<:AbstractGraph
    return [ (first(p),last(p)) for p in find_paths_by_seed(seed,g) ]
end

function create_csv_template(file_name,config)
    open(file_name * ".csv","w") do io
        writedlm(io,vcat(reshape(collect(keys(config)),1,length(config)),reshape(collect(values(config)),1,length(config))),";")
    end
end

function load_base_cfgs(filename)
    df_c = CSV.File(filename,types=Dict(:deterioration => Float64)) |> DataFrame
    base_cfgs = []
    for row in eachrow(df_c)
        vals = []
        for nm in names(df_c)
            val = @match String(nm) begin
                "traffic_dist_params" => parse.([Float64],split(row[:traffic_dist_params][2:end-1],","))
                _ => row[nm]
            end
            push!(vals,val)
        end
        push!(base_cfgs, (;zip(Tuple(Symbol.(names(df_c))),vals)...))
    end
    return base_cfgs
end

base_cfgs = load_base_cfgs("configs.csv")

configs = []
for bcfg in base_cfgs
    ntw_topo = GraphModel(bcfg.ntw_topo_n)
    ntw_services = find_services(bcfg.seed,get_graph(bcfg.seed,bcfg.size,ntw_topo;k=bcfg.k))
    full_config = NamedTuple{Tuple(vcat([:ctl_model,:ntw_topo,:ntw_services],collect(keys(bcfg))))}(vcat([ GraphModel(bcfg.ctl_model_n),ntw_topo,ntw_services],collect(values(bcfg))))

    push!(configs,full_config)
    
end


BenchmarkTools.DEFAULT_PARAMETERS.samples = 100

# single_run_with_logging(configs[1])
#single_run_with_file_logging(configs[1])
pmap(single_run_with_file_logging,configs)

# end # module