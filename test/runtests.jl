using Test
using NAssets
using Agents: vertices
# using MetaGraphs

config = (
            seed = 1 
            ,custom = 0
            ,ctl_model_n = 1
            ,ctl_model = NAssets.GraphModel(3)
            ,ntw_topo_n = 7 
            ,ntw_topo = NAssets.GraphModel(3)
            ,ntw_services = [(1,4),(5,3)]
            ,init_sne_params = (ids=[],ruls=[])
            ,init_link_params = (ids=[],capacities=[])
            ,ntw_csv_adj_matrix = ""
            ,ctl_csv_adj_matrix = ""
            ,size = 7
            ,n_steps = 10
            ,deterioration = 0.01
            ,drop_proportion = 0.
            ,drop_stabilisation = 0.
            ,prob_random_walks = 0.5
            ,benchmark = false
            ,animation = false
            ,k = 1
            ,B = 0.5
            ,ctl_k = 1
            ,ctl_B = 0.5
            ,custom_topo = nothing
            ,ctl_custom_topo = nothing
            ,mnt_policy = 0
            ,mnt_wc_duration = 5
            ,mnt_bc_duration = 3
            ,mnt_wc_cost = 15
            ,mnt_bc_cost = 5
            ,traffic_dist_params = [1.0,0.05]
            ,traffic_packets = 100
            ,link_capacity = 100
            ,clear_cache_graph_freq = 10
            ,interval_tpt = 10
            ,pkt_size = 1
            ,pkt_per_tick = 1000
            ,max_queue_ne = 50
            ,max_msg_live = 5
            ,ofmsg_reattempt = 10
            ,max_cache_paths = 2
            ,data_dir = "data/test/out/"
            ,plots_dir = "plots/test/out/"
            )


@testset "NAssets.jl Tests" begin
    include("graph_tests.jl")
    # ctl_ags,ne_ags,model  = NAssets.single_run(config)
    # length(ctl_ags) == config.size    
end