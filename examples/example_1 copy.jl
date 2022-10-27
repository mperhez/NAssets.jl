using NAssets
using Plots
using GraphRecipes


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
        traffic_dist_params = [1.0, 0.07], 
        #max_queue_ne = 4000,
        #capacity_factor = 1.5,
        # link_capacity = 1000,
        #clear_cache_graph_freq = 5,
        #pkt_per_tick = 5000,
        #  max_msg_live = 5,
        init_sne_params = (ids=[5,9],capacity_factor=[2,2]),
        init_link_params = (ids=[(2,5),(4,5),(5,8),(5,6)],capacities=Int.(ones(4)*1000)),
        ntw_services = [
            (3, 6),
            #(1, 4),
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
# hline!(p,[10], linestyle=:dash, c=:red, label="")
# hline!(p,[0.1], linestyle=:dash, c=:red, label="")

# print(modbin)



#rings
#gp = NAssets.get_graph(-1,40,NAssets.GraphModel(7);k=2,B=0)

#grid?

gp = NAssets.get_graph(-1,ntw_size,NAssets.GraphModel(5))
graphplot(gp)

# tpt_p = plot(
#         ylabel!(NAssets.plot_tpt_step(rd[1].snes_ts,rd[4].snes_ts,rd[1].model_ts,t),"Throughput\n(MB/time)",guidefontsize=6)
#         ,plot_tpt_step(rd[2].snes_ts,rd[4].snes_ts,rd[2].model_ts,t)
#         ,plot_tpt_step(rd[3].snes_ts,rd[4].snes_ts,rd[3].model_ts,t)
#         ,layout=(1,3))

p = plot(title="End-to-end Throughput")
for ne in 1:size(vnes,1)
    plot!(p,NAssets.get_throughput_trj(vnes[ne],n_steps), linestyle= :solid , label = "Asset_$ne", legend = :outerright
    )
end
p

