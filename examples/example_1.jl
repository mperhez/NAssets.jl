using NAssets
using Plots



# Prepare base simulation configuration 
bcfg = (
        ntw_topo = 2, 
        size = 5,
        ctl_model = 1, 
        n_steps = 80, 
        traffic_dist_params = [1.0, 0.05], 
        ntw_services = [(3, 5), (1, 4)] 
        )

#obtain the configuration object. This method will create the control and underlying graphs as well as other objects required to run the simulation.
cfg = NAssets.config(bcfg)


# run simulation
ctl_ags, vnes, modbin = NAssets.single_run(cfg,log_to_file=false)

# Three objects are returned with the state trajectory of the control agents, network elements (assets) and the entire model

#
p = plot(title="Network Assets RUL")

for ne in 1:size(vnes,1)
    plot!(p,[ ne_st.rul for ne_st in vnes[ne] ], linestyle= ne == 2 ? :dash : :dot )
end
hline!(p,[10], linestyle=:dash, c=:red, label="")
hline!(p,[0.1], linestyle=:dash, c=:red, label="")
p

