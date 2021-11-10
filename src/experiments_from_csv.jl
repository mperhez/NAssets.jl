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


base_cfgs = load_base_cfgs("data/configs/configs.csv")
#obtain services that provide this coverage of the network
coverage = 0.95
configs = []
for bcfg in base_cfgs
    ntw_services = get_end_points(bcfg.seed,get_graph(bcfg.seed,bcfg.size,GraphModel(bcfg.ntw_topo_n);k=bcfg.k,adj_m_csv=bcfg.ntw_csv_adj_matrix),coverage)
    push!(configs,config(bcfg,ntw_services))
    
end


BenchmarkTools.DEFAULT_PARAMETERS.samples = 100

single_run_with_logging(configs[1])
#single_run_with_file_logging(configs[1])
#pmap(single_run_with_file_logging,configs)

# end # module