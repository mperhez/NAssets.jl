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

config = ( seed = 43608
            ,ctl_model= GraphModel(6) #NAssets.GraphModel(6)
            ,ntw_topo = GraphModel(6) #NAssets.GraphModel(6)
            ,size=100
            ,n_steps=100
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
            ,data_dir = "data/testing/"
            ,plots_dir = "plots/testing/"
            # ,ntw_services = [(1,7),(4,1),(5,14),(12,8)]
            ,ntw_services = [(21, 48), (21, 86), (21, 93), (21, 78), (21, 97), (21, 63), (21, 43), (21, 87), (21, 84), (21, 91), (21, 90), (21, 64), (21, 71), (21, 72), (21, 80), (21, 99), (21, 98), (21, 89), (48, 81), (48, 61), (48, 93), (48, 78), (48, 97), (48, 62), (48, 63), (48, 76), (48, 43), (48, 73), (48, 45), (48, 87), (48, 90), (48, 71), (48, 72), (48, 95), (48, 69), (48, 80), (48, 99), (48, 98), (48, 79), (48, 66), (81, 86), (81, 93), (81, 78), (81, 97), (81, 63), (81, 43), (81, 73), (81, 45), (81, 87), (81, 84), (81, 91), (81, 90), (81, 64), (81, 71), (81, 72), (81, 80), (81, 99), (81, 98), (81, 89), (81, 66), (81, 94), (86, 61), (86, 93), (86, 78), (86, 97), (86, 62), (86, 63), (86, 76), (86, 43), (86, 73), (86, 45), (86, 87), (86, 90), (86, 71), (86, 72), (86, 95), (86, 69), (86, 80), (86, 99), (86, 98), (86, 79), (86, 66), (61, 93), (61, 78), (61, 97), (61, 63), (61, 73), (61, 87), (61, 91), (61, 90), (61, 64), (61, 71), (61, 80), (61, 99), (61, 98), (61, 89), (61, 66), (93, 78), (93, 97), (93, 62), (93, 76), (93, 43), (93, 73), (93, 87), (93, 84), (93, 91), (93, 90), (93, 51), (93, 64), (93, 71), (93, 72), (93, 95), (93, 69), (93, 80), (93, 99), (93, 98), (93, 89), (93, 22), (93, 66), (93, 94), (78, 97), (78, 62), (78, 63), (78, 76), (78, 43), (78, 45), (78, 87), (78, 77), (78, 91), (78, 90), (78, 64), (78, 71), (78, 72), (78, 80), (78, 99), (78, 98), (78, 89), (78, 79), (78, 22), (78, 94), (97, 62), (97, 63), (97, 76), (97, 43), (97, 73), (97, 45), (97, 87), (97, 77), (97, 84), (97, 91), (97, 90), (97, 51), (97, 64), (97, 71), (97, 72), (97, 95), (97, 69), (97, 80), (97, 99), (97, 98), (97, 89), (97, 79), (97, 22), (97, 66), (97, 94), (62, 43), (62, 73), (62, 87), (62, 84), (62, 91), (62, 64), (62, 71), (62, 72), (62, 99), (62, 98), (62, 89), (62, 66), (63, 76), (63, 73), (63, 84), (63, 91), (63, 51), (63, 64), (63, 71), (63, 72), (63, 95), (63, 69), (63, 80), (63, 98), (63, 89), (63, 66), (76, 43), (76, 73), (76, 45), (76, 87), (76, 84), (76, 91), (76, 90), (76, 64), (76, 71), (76, 72), (76, 80), (76, 99), (76, 98), (76, 89), (76, 66), (76, 94), (43, 73), (43, 87), (43, 77), (43, 91), (43, 90), (43, 64), (43, 71), (43, 95), (43, 69), (43, 99), (43, 98), (43, 89), (43, 79), (43, 22), (43, 66), (43, 94), (73, 87), (73, 77), (73, 84), (73, 91), (73, 90), (73, 51), (73, 64), (73, 71), (73, 72), (73, 69), (73, 80), (73, 99), (73, 98), (73, 89), (73, 22), (73, 94), (45, 84), (45, 91), (45, 64), (45, 71), (45, 72), (45, 95), (45, 69), (45, 80), (45, 98), (45, 89), (45, 22), (45, 66), (45, 94), (87, 77), (87, 84), (87, 91), (87, 90), (87, 51), (87, 71), (87, 72), (87, 95), (87, 69), (87, 79), (87, 22), (87, 66), (87, 94), (77, 84), (77, 64), (77, 71), (77, 95), (77, 80), (77, 99), (77, 98), (77, 89), (84, 71), (84, 69), (84, 80), (84, 99), (84, 98), (84, 79), (84, 22), (84, 66), (84, 94), (91, 90), (91, 64), (91, 71), (91, 72), (91, 95), (91, 69), (91, 80), (91, 99), (91, 98), (91, 89), (91, 22), (91, 66), (91, 94), (90, 51), (90, 71), (90, 72), (90, 95), (90, 99), (90, 98), (90, 79), (90, 66), (51, 64), (51, 71), (51, 80), (51, 99), (51, 98), (51, 89), (51, 66), (64, 71), (64, 72), (64, 95), (64, 69), (64, 80), (64, 99), (64, 79), (64, 22), (64, 66), (64, 94), (71, 72), (71, 95), (71, 98), (71, 89), (71, 79), (71, 22), (71, 66), (71, 94), (72, 95), (72, 69), (72, 99), (72, 98), (72, 89), (72, 66), (95, 80), (95, 99), (95, 98), (95, 89), (95, 79), (95, 94), (69, 80), (69, 99), (69, 98), (69, 89), (69, 66), (69, 94), (80, 79), (80, 22), (80, 66), (80, 94), (99, 79), (99, 22), (99, 66), (99, 94), (98, 79), (98, 22), (98, 66), (98, 94), (89, 79), (89, 22), (89, 66), (89, 94), (79, 94)]
        )
single_run_with_logging(config)


# end # module