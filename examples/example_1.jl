using NAssets
using Plots
using GraphRecipes


tst = (rul,t,a) -> begin
    println("rul: $rul --- a: $a")
    return last(rul) - ( a * t )
end

ntw_size = 9
ntw_topo = 4
n_steps = 100
# Prepare base simulation configuration 
bcfg = (
        seed = 123,
        ntw_topo = ntw_topo, 
        size = ntw_size,
        ctl_model = 7,
        ctl_k = 3,
        ctl_B = 0.7,
        # prob_random_walks = 0.8,
        n_steps = n_steps, 
        deterioration = [ (rul,t,a) -> rul - a 1 ],
        prediction = [ tst 1 ],
        traffic_dist_params = [1.0, 0.07], 
        traffic_packets = 100,
        #max_queue_ne = 100,
        #capacity_factor = 5,
        link_capacity = 2000,
        max_msg_live = 10,
        #clear_cache_graph_freq = 5,
        pkt_per_tick = 3100,
        #  max_msg_live = 5,
        mnt_bc_duration = 1,
        mnt_bc_cost = 0.5,
        mnt_wc_duration = 5,
        mnt_wc_cost = 5,
        mnt_policy = 0,
        predictive_freq = 10,
        prediction_window = 10,
        init_sne_params = 
        #(ids=[9],capacity_factor=[4]),
        (ids=[9],mnt_policy=[1]),
        #  init_link_params = (
        # #     # ids=[(2,5),(4,5),(5,8),(5,6),(1,2),(3,6),(6,9),(8,9)],capacities=[2000,4000,4000,500,4000,5000,500,500]
        #      ids = [(7,8)],
        #      capacities = [2000]
        #      ),
        ntw_services = [
            (3, 7),
            (9,1),
            (8,4)
            ] 
        )

#obtain the configuration object. This method will create the control and underlying graphs as well as other objects required to run the simulation.
cfg = NAssets.config(bcfg)


# run simulation
ctl_ags, vnes, modbin = NAssets.single_run(cfg,log_to_file=false)

# Three objects are returned with the state trajectory of the control agents, network elements (assets) and the entire model


# Condition deterioration

prul = plot(title="Network Assets RUL")

for ne in 1:size(vnes,1)
    plot!(prul,[ ne_st.rul for ne_st in vnes[ne] ], linestyle= ne == 2 ? :dash : :dot )
end
prul
hline!(prul,[10], linestyle=:dash, c=:red, label="")
prul
# hline!(p,[0.1], linestyle=:dash, c=:red, label="")

# print(modbin)



#rings
#gp = NAssets.get_graph(-1,40,NAssets.GraphModel(7);k=2,B=0)

#grid?

# gp = NAssets.get_graph(-1,ntw_size,NAssets.GraphModel(5))
# graphplot(gp)

# tpt_p = plot(
#         ylabel!(NAssets.plot_tpt_step(rd[1].snes_ts,rd[4].snes_ts,rd[1].model_ts,t),"Throughput\n(MB/time)",guidefontsize=6)
#         ,plot_tpt_step(rd[2].snes_ts,rd[4].snes_ts,rd[2].model_ts,t)
#         ,plot_tpt_step(rd[3].snes_ts,rd[4].snes_ts,rd[3].model_ts,t)
#         ,layout=(1,3))

# p = plot(title="End-to-end Throughput")
# for ne in 1:size(vnes,1)
#     plot!(p,NAssets.get_throughput_trj(vnes[ne],n_steps), linestyle= :solid , label = "Asset_$ne", legend = :outerright
#     )
# end
# p



# pls = plot(title="Packet loss")
# for ne in 1:size(vnes,1)
#     plot!(pls,[ vnes[ne][i].drop_pkt for i=1:n_steps ], linestyle= :solid , label = "Asset_$ne", legend = :outerright
#     )
# end
# pls


