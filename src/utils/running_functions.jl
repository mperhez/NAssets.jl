"""

`single_run(config) -> ctl_ags,ne_ags,model`

It runs a single simulation with the passed configuration, returning simulation data in `ctl_ags`,`ne_ags`,`model`. Optionally logging to a  file if parameter `log_to_file` set to `true`.

"""
function single_run(config;log_to_file=false)
    run_label = config.run_label

    io = log_to_file ? open( config.data_dir * run_label * "_log.log", "w+") : stdout
    
    logger = MessageOnlyLogger(io,Logging.Info)
    ctl_ags,ne_ags,model = with_logger(logger) do
        start_time = now()
        log_info("$start_time: start $run_label")
        ctl_ags,ne_ags,model = run_sim(config)
        end_time = now()
        log_info("$end_time: end $run_label. Elapsed: $((end_time - start_time))")
        ctl_ags,ne_ags,model
    end
    if log_to_file
        flush(io)
        close(io) 
    end
    ctl_ags,ne_ags,model
end

"""

`get_run_label(config)`

It obtains the label for a simulation run based on the configuration parameters: `config`. Label is based on the graph model of the underlying controlled network and the control network, plus the size, seed and maintenance policy.

"""
function get_run_label(config)
    base_label = "$(config.ntw_topo)"
    if config.ntw_topo == string.(instances(GraphModel))[6+1] ||
    config.ntw_topo == string.(instances(GraphModel))[7+1]
        base_label = base_label * "_$(config.k)_$(replace(string(config.B),"."=>""))"
    end

    base_label = base_label * "_$(config.ctl_model)"

    if config.ctl_model == string.(instances(GraphModel))[6+1] ||
        config.ctl_model == string.(instances(GraphModel))[7+1]
        base_label = base_label * "_$(config.ctl_k)_$(replace(string(config.ctl_B),"."=>""))"
    end
   
    p_random_walks = replace(string(config.prob_random_walks),"."=>"")
    
    run_label = config.seed >= 0 ? base_label * "_$(config.size)_$(config.seed)_$(p_random_walks)" : "_$(config.size)___$(p_random_walks)"

    run_label *= "_MNT_" * @match config.mnt_policy begin
        0 => "CORR"
        1 => "PREV"
        2 => "OPT"
    end
    return run_label
end

"""

`run_sim(config)`

Based on `config` parameters received it creates objects required to trigger simulation run. 

"""
function run_sim(config)
    
    
    
    args= Dict()

    for k in keys(config)
        args[k] = config[k]
    end
 
    q_agents = config.size + config.q_ctl_agents
    args[:q]=q_agents
    
    adata = [get_state_trj]
    mdata = [:mapping_ctl_ntw,get_state_trj]

    result_agents,result_model = run_model(config.n_steps,args; agent_data = adata, model_data = mdata)
    
    ctl_ags = last(result_agents[result_agents[!,:id] .> config.size ,:],config.q_ctl_agents)[!,"get_state_trj"]
    nes = last(result_agents[result_agents[!,:id] .<= config.size ,:],config.size)[!,"get_state_trj"]
    modbin = last(result_model)["get_state_trj"]

    nes_1 = vcat([ [ split(string(j-1)*";"*replace(to_string(nes[i][j]),"NetworkAssetState(" => ""),";") for j=1:length(nes[i])] for i=1:length(nes) ]...)

    ctl_ags_1 = vcat([ [ split(string(j-1)*";"*replace(to_string(ctl_ags[i][j]),"ControlAgentState(" => ""),";") for j=1:length(ctl_ags[i])] for i=1:length(ctl_ags) ]...)

    # print(last(result_model)["get_state_trj"])
    
    #sdir = data_dir*"runs2/$(config.ctl_model)/"
    sdir = config.data_dir
    
    check_create_dir!(sdir)

    vnes = Vector{Vector{NetworkAssetState}}()
    for ne in nes
        push!(vnes,ne)
    end

    serialize( sdir * config.run_label * "_steps_ctl_agents.bin",ctl_ags)
    serialize( sdir * config.run_label * "_steps_nelements.bin",vnes)
    serialize( sdir * config.run_label * "_steps_model.bin",modbin)



    ctl_ags_1 = [ replace.(ctl_ags_1[i]," Dict{Tuple{Int64,Int64},Array{Tuple{Int64,Float64,Array{Int64,N} where N},N} where N}" => "") for i=1:1]

    model_data = last(result_model)["get_state_trj"]
    model_data = [ (m.tick,m.links_load) for m in model_data ]

    nelements_header = reshape(vcat(["tick"],string.([i for i in fieldnames(NetworkAssetState)])),1,length(fieldnames(NetworkAssetState))+1)

    open(sdir * config.run_label * "_steps_nelements.csv", "w") do io
        writedlm(io,nelements_header,';')
        writedlm(io,nes_1,';') 
    end;
    
    ctl_header = reshape(vcat(["tick"],string.([i for i in fieldnames(ControlAgentState)])),1,length(fieldnames(ControlAgentState))+1)

    open(sdir * config.run_label * "_steps_ctl_agents.csv", "w") do io
        writedlm(io,ctl_header,';')
        writedlm(io,ctl_ags_1,';') 
    end;


    open(sdir * config.run_label * "_steps_model.csv", "w") do io
        writedlm(io,model_data,';') 
    end;

    ctl_ags, vnes, modbin

end

"""

`load_base_cfgs`

It loads the simulation config parameters from csv file which location and name is passed. I passes a list with delimiters (delims) used in the file from outer, to inner. Default=[';',',']

"""
function load_base_cfgs(filename;delims=[';',','])
    df_c = CSV.File(filename,types=Dict(:deterioration => Float64),delim=delims[1]) |> DataFrame
    base_cfgs = []
    for row in eachrow(df_c)
        vals = []
        for nm in names(df_c)
            val = @match String(nm) begin
                #parse "special" csv fields
                "traffic_dist_params" => parse.([Float64],split(row[:traffic_dist_params][2:end-1],delims[2]))
                _ => ismissing(row[nm]) ? "" : row[nm]
            end
            push!(vals,val)
        end
        push!(base_cfgs, (;zip(Tuple(Symbol.(names(df_c))),vals)...))
    end
    return base_cfgs
end


"""
`get_default_config()`

It returns the default config for simulation.

"""
function get_default_config()
    return (

        ## Basic simulation parameters

        seed = -1, # Random seed to use. Negative to work with no seed.
        n_steps = 20, # Steps to run the simulation for 
                
        ctl_model = 1, # Topology to use from `GraphModel` enum. 1 indicates centralised topo.
        ntw_topo = 2, # Topology to use from `GraphModel` enum. 2: Ring Topology. 0 Indicates custom topo from CSV file. 

        size = 8, # If random topo for underlying network (ntw_topo != 0). Underlying network size for randomly generated networks.
        k = 1, # If random topo for underlying network (ntw_topo != 0). K parameter to use in randomly generated underlying networks
        B = 0.5, # If random topo for underlying network (ntw_topo != 0). B parameter to use in randomly generated underlying networks
        ctl_k = 1, # If random topo for control network (ctl_model != 0). K parameter to use in randomly generated control networks
        ctl_B = 0.5, # If random topo for control network (ctl_model != 0). B parameter to use in randomly generated control networks
        
        ntw_csv_adj_matrix = "", # If custom topo for underlying network (ntw_topo == 0). Location of the CSV file containing the adjancency matrix for the underlying network topology.  
        ctl_csv_adj_matrix = "", # If custom topo for control network (ctl_model == 0).  Location of the CSV file containing the adjancency matrix for the control network topology.
        custom_topo = "nothing", # Deprecated. Used to set custom topo for underlying network. 
        ctl_custom_topo = "nothing", # Deprecated. Used to set custom topo for control network.
        benchmark = false, # It activate benchmarks (BenchmarkTools.jl) for the run. Takes longer.
        animation = false, # Deprecated. Produce simple animantion.
        
        data_dir = "", # Output data dir
        plots_dir = "", # Deprecated. Directory for plot generation.
        
        
        ## Asset Maintenance Params 

        deterioration = 0.0, # deterioration parameters for network assets. This parameter is used by the `deteriorate!` function in the `physical_model` module.
        mnt_policy = 0, # Maintenance policy used in the simulation. 0: Corrective, 1: Preventive, 2: Custom/Optimal
        mnt_wc_duration = 0, # Worst case duration of the maintenance operations (ticks)
        mnt_bc_duration = 0, # Best case duration of the maintenance operations (ticks)
        mnt_wc_cost = 0, # Worst case costs of maintenance operations (££)
        mnt_bc_cost = 0, # Best case costs of maintenance operations (££)

        ## Underlying Network & Traffic Params
        ntw_services = [], # List of pairs of nodes of the underlying network where the traffic is flowing. e.g. [(3,7),(8,2)] indicates that 2 services are running in the underlying network. First service implies there is traffic flowing between 3 and 7. Second service, traffic flowing between 8 and 2.
        traffic_dist_params = [1.0, 0.05], # Distribution params (mean, std) for traffic generation
        traffic_packets = 400, # Magnitude No. of packets for traffic generation
        link_capacity = 400, # Link Capacity/Bandwith per tick (Packets)
        interval_tpt = 10, # Ticks used for throughput calculation
        pkt_size = 1, # Packet size for throughput calculations
        pkt_per_tick = 2000, # Default packet processing capacity for all nodes
        capacity_factor = 1.2, #default capacity factor of pkts processed per tick (.2 extra is to have always room for management msgs/pkts.) This Factor is used to have nodes with different processing capacities.
        max_queue_ne = 300, # Queue size for each node of the underlying network (Packets)

        ## Control params

        prob_random_walks = 1, # For distributed control. Probability of neighbour nodes to propagate query msgs when discovering/learning underlying network.
        clear_cache_graph_freq = 50, # frequency for clearing cache of learned graphs by control agents to avoid large outdated graphs.
        max_msg_live = 5, # Max ticks a control messasge is live in the simulation.
        ofmsg_reattempt = 10, # Frequency for re-attempting un-responded OpenFlow-like messages
        max_cache_paths = 2, # Max quantity of paths to store in the control agent cache.

        ## Event Simulation

        drop_proportion = 0, # Proportion of nodes that will drop from the network 
        drop_stabilisation = 10, # ticks to wait at the end of simulation after the last node has been dropped.

        ## Further customisation

        init_sne_params = (ids=[],ruls=[]), # List of node ids and their specific initial parameters. e.g. (ids=[15,19],ruls=[1,0.7],deterioration=[0.2,0.001],capacity_factor=[1.2,5]) This indicates that for node 15, the starting RUL (Remaining Useful Life) will be 1, the deterioration parameter is 0.2 and the packet capacity is 1.2x (pkt_per_tick) . Likewise, for node 19, starting RUL is 0.7, deterioration 0.001 and capacity factor 5x (pkt_per_tick).

        init_link_params = (ids=[],capacities=[]), # List of links (node pairs) and their specific initial parameters. e.g. (ids=[(15,17),(8,9)],capacities=[200,400]). Setting a capacity of 200 packets per tick for link 15-17 and 400 packets per tick for link 8-9.

        ## Python integration

        py_integration = (), # Python integration  object for calling python functions
        notes = ""
        )
end

"""
`config(bconfig)`

It prepares a config object based on the plain configuration (bconfig) passed as parameter.

"""
function config(bconfig)

    default_config = get_default_config()
    
    config_d = Dict()

    for cfg_param in keys(default_config)
        
        k,v = cfg_param in keys(bconfig) ? (cfg_param, bconfig[cfg_param]) : (cfg_param, default_config[cfg_param])
        @show k,v, cfg_param
        
        config_d[k] = v

        k,v = @match cfg_param begin

            Symbol("ctl_model") => (Symbol("ctrl_model"),GraphModel(v))

            Symbol("ntw_topo") => (Symbol("ntw_model"),GraphModel(v))

            Symbol("n_steps") => (Symbol("N"),v)

            _ => (k, v)

        end
        config_d[k] = v
    end

    #get size from topo, either from csv file or randomly generated.

    g = get_graph(config_d[:seed],config_d[:size],config_d[:ntw_model];k=config_d[:k],B=config_d[:B],adj_m_csv=config_d[:ntw_csv_adj_matrix])
    config_d[:ntw_graph] = load_network_graph(g)
    config_d[:size] = nv(config_d[:ntw_graph])

    config_d[:ctl_graph] = config_d[:ctrl_model] == GraphModel(1) ? MetaGraph() :
        config_d[:ctl_graph] = get_graph(config_d[:seed],config_d[:size],config_d[:ctrl_model];k=config_d[:ctl_k],B=config_d[:ctl_B],adj_m_csv=config_d[:ctl_csv_adj_matrix])

    # seed, stabilisation_time,proportion_dropping,q,N
    config_d[:dropping_times] = get_dropping_times(config_d[:seed],config_d[:drop_stabilisation],config_d[:drop_proportion],config_d[:size],config_d[:n_steps])

    q_ctl_nodes = nv(config_d[:ctl_graph])
    config_d[:q_ctl_agents] = q_ctl_nodes == 0 ? 1 : q_ctl_nodes

    config = NamedTuple{Tuple(keys(config_d))}(values(config_d))
    config = merge(config, (run_label = get_run_label(config), ))
    
    return config

end