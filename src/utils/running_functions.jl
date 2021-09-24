function single_run_with_logging(config)
    run_label = get_run_label(config)
    io = stdout
    logger = MessageOnlyLogger(io,Logging.Info)
    with_logger(logger) do
        start_time = now()
        log_info("$start_time: start $run_label")
        single_run(config)
        end_time = now()
        log_info("$end_time: end $run_label. Elapsed: $((end_time - start_time))")
    end
end

function single_run_with_file_logging(config)
    
    run_label = get_run_label(config)

    io = open( config.data_dir * run_label * "_log.log", "w+")
    # logger = SimpleLogger(io,Logging.Debug)

    # logger = FormatLogger() do io, args
    #     log_info(io, args._module, " | ", "[", args.level, "] ", args.message)
    # end;
    # logger = MinLevelLogger(FileLogger(run_label* "_testing.log"), Logging.Info) |> simplified_logger
    
    # logger = OneLineTransformerLogger(MinLevelLogger(FileLogger( data_dir * run_label* ".log"), Logging.Info)#|> OneLineTransformerLogger
    # logger = SimpleLogger(stdout, Logging.Debug) |> OneLineTransformerLogger
    logger = MessageOnlyLogger(io,Logging.Info)
    with_logger(logger) do
        start_time = now()
        log_info("$start_time: start $run_label")
        single_run(config)
        end_time = now()
        log_info("$end_time: end $run_label. Elapsed: $((end_time - start_time))")
    end
    flush(io)
    close(io)
end

function load_run_configs() 
    configs = []
    for ctl_model in [GraphModel(1)]#, ControlModel(4) ] #instances(ControlModel)
        for ntw_topo in [GraphModel(0)] #4#6
            for size in [92]#, 50, 100]
                for drop_proportion in [10]
                    for seed in [123]
                        ks = ntw_topo == GraphModel(6) ||
                            ntw_topo == GraphModel(7) ? [4] : [0]
                        ctl_ks = ctl_model == GraphModel(6) ||
                                ctl_model == GraphModel(7) ? [4] : [0]
                        Βs = ntw_topo == GraphModel(6) ||
                                ntw_topo == GraphModel(7) ? [0.8] : [0.0]
                        ctl_Βs = ctl_model == GraphModel(6) ||
                                    ctl_model == GraphModel(7) ? [0.8] : [0.0]
                        
                        for k in ks
                            for Β in Βs
                                for ctl_k in ctl_ks
                                    for ctl_Β in ctl_Βs
                                        push!(configs,new_config(seed,ctl_model,ntw_topo,size,100,drop_proportion,1.0,false,false,k,Β,ctl_k,ctl_Β,2,[(1,7),(4,1),(5,14),(12,8)],20,10,150.,100.,[1,0.05]))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return configs
end

function load_run_configs(g_size,m_policy,services,steps) 
    ntw_graph = g_size == 92 ? 0 : 4
    configs = []
    for ctl_model in [GraphModel(1)]#, ControlModel(4) ] #instances(ControlModel)
        for ntw_topo in [GraphModel(ntw_graph)] 
            for size in [g_size]
                for drop_proportion in [10]
                    for seed in [123]
                        ks = ntw_topo == GraphModel(6) ||
                            ntw_topo == GraphModel(7) ? [4] : [0]
                        ctl_ks = ctl_model == GraphModel(6) ||
                                ctl_model == GraphModel(7) ? [4] : [0]
                        Βs = ntw_topo == GraphModel(6) ||
                                ntw_topo == GraphModel(7) ? [0.8] : [0.0]
                        ctl_Βs = ctl_model == GraphModel(6) ||
                                    ctl_model == GraphModel(7) ? [0.8] : [0.0]
                        
                        for k in ks
                            for Β in Βs
                                for ctl_k in ctl_ks
                                    for ctl_Β in ctl_Βs
                                        push!(configs,new_config(seed,ctl_model,ntw_topo,size,steps,drop_proportion,1.0,false,false,k,Β,ctl_k,ctl_Β,m_policy,services,20,10,150.,100.,[1,0.05]))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return configs
end




function get_run_label(config)
    base_label = "$(config.ntw_topo)"
    if config.ntw_topo == GraphModel(6) ||
    config.ntw_topo == GraphModel(7)
        base_label = base_label * "_$(config.k)_$(replace(string(config.Β),"."=>""))"
    end

    base_label = base_label * "_$(config.ctl_model)"

    if config.ctl_model == GraphModel(6) ||
        config.ctl_model == GraphModel(7)
        base_label = base_label * "_$(config.ctl_k)_$(replace(string(config.ctl_Β),"."=>""))"
    end
   
    run_label = base_label * "_$(config.size)_$(config.seed)_$(replace(string(config.prob_random_walks),"."=>""))"

    run_label *= "_MNT_" * @match config.mnt_policy begin
        0 => "CORR"
        1 => "PREV"
        2 => "OPT"
    end
    return run_label
end

function single_run(config)
    Random.seed!(config.seed)
    args= Dict()
    ntw_graph = load_network_graph(get_graph(config.seed,config.size,config.ntw_topo;k=config.k,Β=config.Β,custom_topo=config.custom_topo))
    args[:ntw_graph]=ntw_graph
    # args[:dropping_nodes]= get_dropping_nodes(config.drop_proportion)
    args[:ctrl_model] = config.ctl_model
    args[:ntw_model] = config.ntw_topo

    args[:seed] = config.seed
    args[:benchmark] = config.benchmark
    args[:animation] = config.animation
    args[:prob_random_walks] = config.prob_random_walks # prob. of neighbour nodes to propagate query msgs.
    args[:mnt_policy] = config.mnt_policy
    args[:ntw_services] = config.ntw_services
    args[:mnt_wc_duration] = config.mnt_wc_duration #worst case duration
    args[:mnt_bc_duration] = config.mnt_bc_duration
    args[:mnt_wc_cost] = config.mnt_wc_cost
    args[:mnt_bc_cost] = config.mnt_bc_cost #best case cost
    args[:traffic_dist_params] = config.traffic_dist_params #traffic distribution parameters
    args[:data_dir] = config.data_dir
    args[:plots_dir] = config.plots_dir
    args[:rul_deterioration] = 0.2 #default rul deterioration

    q_ctl_agents = 0
    run_label = get_run_label(config)
    args[:run_label] = run_label
    if config.ctl_model == GraphModel(1)
        args[:ctl_graph] = MetaGraph()
        q_ctl_agents = 1
    else
        ctl_graph = get_graph(config.seed,config.size,config.ctl_model;k=config.ctl_k,Β=config.ctl_Β,custom_topo=config.ctl_custom_topo)
        args[:ctl_graph]=ctl_graph
        q_ctl_agents = nv(ctl_graph)
    end

    q_agents = nv(ntw_graph)+q_ctl_agents
    args[:q]=q_agents
    # seed, stabilisation_time,proportion_dropping,q,N
    args[:dropping_times] = get_dropping_times(config.seed,30,0.2,nv(ntw_graph),config.n_steps)
    adata = [get_state_trj]
    mdata = [:mapping_ctl_ntw,get_state_trj]
    result_agents,result_model = run_model(config.n_steps,args; agent_data = adata, model_data = mdata)
    
    ctl_ags = last(result_agents[result_agents[!,:id] .> nv(ntw_graph) ,:],q_ctl_agents)[!,"get_state_trj"]
    nes = last(result_agents[result_agents[!,:id] .<= nv(ntw_graph) ,:],nv(ntw_graph))[!,"get_state_trj"]
    modbin = last(result_model)["get_state_trj"]

    nes_1 = vcat([ [ split(string(j-1)*";"*replace(to_string(nes[i][j]),"NetworkAssetState(" => ""),";") for j=1:length(nes[i])] for i=1:length(nes) ]...)

    ctl_ags_1 = vcat([ [ split(string(j-1)*";"*replace(to_string(ctl_ags[i][j]),"ControlAgentState(" => ""),";") for j=1:length(ctl_ags[i])] for i=1:length(ctl_ags) ]...)

    # print(last(result_model)["get_state_trj"])
    
    #sdir = data_dir*"runs2/$(config.ctl_model)/"
    sdir = config.data_dir

    if !isdir(sdir)
        mkdir(sdir) 
    end

    vnes = Vector{Vector{NetworkAssetState}}()
    for ne in nes
        push!(vnes,ne)
    end

    serialize( sdir * run_label * "_steps_ctl_agents.bin",ctl_ags)
    serialize( sdir * run_label * "_steps_nelements.bin",vnes)
    serialize( sdir * run_label * "_steps_model.bin",modbin)



    ctl_ags_1 = [ replace.(ctl_ags_1[i]," Dict{Tuple{Int64,Int64},Array{Tuple{Int64,Float64,Array{Int64,N} where N},N} where N}" => "") for i=1:1]

    model_data = last(result_model)["get_state_trj"]
    model_data = [ (m.tick,m.links_load) for m in model_data ]

    
    open(sdir * run_label * "_steps_nelements.csv", "w") do io
        writedlm(io,reshape(vcat(["tick"],string.([i for i in fieldnames(NetworkAssetState)])),1,length(fieldnames(NetworkAssetState))+1),';')
        writedlm(io,nes_1,';') 
    end;
    

    open(sdir * run_label * "_steps_ctl_agents.csv", "w") do io
        writedlm(io,reshape(vcat(["tick"],string.([i for i in fieldnames(ControlAgentState)])),1,length(fieldnames(ControlAgentState))+1),';')
        writedlm(io,ctl_ags_1,';') 
    end;


    open(sdir * run_label * "_steps_model.csv", "w") do io
        writedlm(io,model_data,';') 
    end;

end
