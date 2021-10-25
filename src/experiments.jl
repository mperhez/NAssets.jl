# module NAssets
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

configs = []
exp_params = deserialize("data/services.bin")

for exp_param in exp_params
    for cg=6:6
        push!(configs, ( seed = first(exp_param)
                    ,ctl_model= GraphModel(cg) #NAssets.GraphModel(6)
                    ,ntw_topo = GraphModel(6) #NAssets.GraphModel(6)
                    ,size=100
                    ,n_steps=200
                    ,deterioration = 0. # physical deterioration parameter. 0: switched off.
                    # random asset drops
                    ,drop_proportion=0.2 #proportion of assets to randomly fail. 0: switched off.
                    ,drop_stabilisation=50 # time (from simulation start) to allow assets to stabilise before trigger random drops.
                    ,prob_random_walks = 1. #BA(6): 0.5#star(5): 1. #complete(3): 0.3 #ring(2): 1. # grid(4): 0.8 #0.5
                    ,benchmark = false
                    ,animation = false
                    ,k=2
                    ,B = 0.5
                    ,ctl_k=2
                    ,ctl_B = 0.5
                    ,custom_topo = nothing
                    ,ctl_custom_topo = nothing
                    ,mnt_policy = 1
                    ,mnt_wc_duration = 20
                    ,mnt_bc_duration = 10
                    ,mnt_wc_cost = 150.
                    ,mnt_bc_cost = 100.
                    ,traffic_dist_params = [1,0.05]
                    ,traffic_proportion = 0.01
                    ,clear_cache_graph_freq = 50#50,#25, # How often the ntw graph is cleared to initial state, 0: no cache. A value of 10, is not enough in a 16 mesh network to find paths when queries are not repeated, prob_eq_query. 
                    ,interval_tpt = 10 #interval used to calculate tpt
                    ,pkt_size = 1#0.065, # (in MB) pkt size  IP between 21 is 65536 bytes Ref: Internet Core Protocols: The Definitive Guide by Eric Hall
                    ,pkt_per_tick = 2000#0, # How many packets are processsed per tick. #TODO which number is reasonable?
                    # I am setting this to 2000 as the expectations is nes
                    # are able to process. Check references e.g. Nokia SR 7750.
                    ,max_queue_ne = 300#700 #This indicates how many pkts/msgs can be stored in tick to be processed the next tick
                    ,ofmsg_reattempt=10#4,# greater number to avoid duplicated install flows
                    ,max_cache_paths = 2
                    ,data_dir = "data/exp1/"
                    ,plots_dir = "plots/exp1/"
                    # ,ntw_services = [(1,7),(4,1),(5,14),(12,8)]
                    ,ntw_services = last(exp_param)
                ))
    end
end


BenchmarkTools.DEFAULT_PARAMETERS.samples = 100

Threads.@threads for config in configs
    single_run_with_file_logging(config)
end
# end # module