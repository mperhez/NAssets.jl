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
 using PyCall
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


# GurobiPy Optimisation config
script_dir = pwd() * "/src/pyopt/" #@__DIR__ 
pushfirst!(PyVector(pyimport("sys")."path"), script_dir)
opt_init = pyimport("optimisation_initialisation")
opt_run = pyimport("maintenance_planning")
np = pyimport("numpy")

# load sim config file
base_cfgs = load_base_cfgs("data/configs/configs.csv")
#first row of the file
bcfg = base_cfgs[1]

#obtain random services that provide this coverage of the network
# coverage = 0.95
# ntw_topo = GraphModel(bcfg.ntw_topo_n)
# ntw_services = get_end_points(bcfg.seed,get_graph(bcfg.seed,bcfg.size,ntw_topo;k=bcfg.k,adj_m_csv=bcfg.ntw_csv_adj_matrix),coverage)

#small scale scenario
# remember to set ntw topo and other params in config.csv file. ntw_topo_n: 4, size = 16, mnt_policy: 2
ntw_services = [(1,7),(4,1),(5,14),(12,8)]
init_sne_params = (ids=[2,6,9,13,10,15,16],ruls=[65,78,84,86,93,49,90])

#large scale scenario
# services = [(23,80),(18,48),(56,92),(64,31),(48,70)]
# init_sne_params = (ids = [36,6,3,5,12,57,2,19,1,25,8], ruls = [34,42,48,50,53,73,82,88,90,94,97])

cfg = config(bcfg,ntw_services,init_sne_params)

single_run_with_logging(cfg)
