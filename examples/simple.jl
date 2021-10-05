using NAssets

config = ( seed = 123
            ,ctl_model= NAssets.GraphModel(1)
            ,ntw_topo = NAssets.GraphModel(4)
            ,size=16
            ,n_steps=40
            ,drop_proportion=0.1
            ,prob_random_walks = 0.1
            ,benchmark = false
            ,animation = true
            ,k=0
            ,Β = 0.
            ,ctl_k=0
            ,ctl_Β = 0.
            ,custom_topo = nothing
            ,ctl_custom_topo = nothing
            ,mnt_policy = 1
            ,ntw_services = [(1,7),(4,1),(5,14),(12,8)]
            ,mnt_wc_duration = 20
            ,mnt_bc_duration = 10
            ,mnt_wc_cost = 150.
            ,mnt_bc_cost = 100.
            ,traffic_dist_params = [1,0.05]
            ,data_dir = "data/testing/"
            ,plots_dir = "plots/testing/"
        )
single_run_with_logging(config)