 using Agents: vertices
 using MetaGraphs: add_vertex!, has_edge
 using Agents, AgentsPlots, Plots, LightGraphs, MetaGraphs, GraphPlot, GraphRecipes, NetworkLayout
 using Tables, DataFrames
 using CSV, JSON, Serialization, DelimitedFiles
 using BritishNationalGrid
 using ZipFile, Shapefile
 using Random
 using Match
 using LinearAlgebra
 using StatsBase
 using Distributions
 using StatsPlots
 using SparseArrays
 using Laplacians
 using DataStructures
 using RollingFunctions
 using BenchmarkTools
 using Statistics
 using Logging,LoggingExtras, LoggingFacilities
 using Dates,TimeZones




#Core structures
 include("core/core_structs.jl")
#graph-related
 include("core/graph_functions.jl")
#events
 include("eve/artificial_events.jl")
#various util functions
 include("utils/util_functions.jl")
#logging
 include("utils/logging_functions.jl")
#Plotting functions
 include("utils/plotting_functions.jl")
# time-to-event functions
 include("utils/tte_functions.jl")
#running functions
 include("utils/running_functions.jl")

#maintenance model
 include("phy/maintenance_model.jl")

 include("ntw/of_switch.jl")
 include("ntw/of_control.jl")
 include("ctl/agent_control.jl")

 include("phy/physical_model.jl")

 include("ntw/network_model.jl")
 include("phy/geo_model.jl")

#Main Functions
 include("model/netManFunctions.jl")

#Agents.jl function implementation for this model
 include("model/netManModel.jl")

#Basic queries
#include("model/queries_basic.jl")
#Multiple queries
 include("ctl/queries_multiple.jl")

export load_run_configs, single_run_with_logging


base_cfgs = load_base_cfgs("data/configs/configs_exp5_single.csv")
bcfg = base_cfgs[1]
#obtain services that provide this coverage of the network
coverage = 0.95
ntw_services = get_end_points(bcfg.seed,get_graph(bcfg.seed,bcfg.size,GraphModel(bcfg.ntw_topo_n);k=bcfg.k,adj_m_csv=bcfg.ntw_csv_adj_matrix),coverage)

cfg = config(bcfg,ntw_services)
single_run_with_logging(cfg)
