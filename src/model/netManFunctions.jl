"""
Find agent in the model given the id
"""
function find_agent(id,model)
    first(filter(a->a.id == id,Set(allagents(model))))
end

function get_control_agent(asset_id::Int,model)
    return model.mapping_ctl_ntw[asset_id]
end

function get_controlled_assets(agent_id::Int,model)::Set{Int64}
    assets = filter(k->model.mapping_ctl_ntw[k] == agent_id,keys(model.mapping_ctl_ntw))
    #log_info("assets controlled by $(agent_id) are: $(length(assets))")
    return assets
end

function has_active_controlled_assets(agent::Agent,model)
    assets = get_controlled_assets(agent.id,model)

    sum_up = sum([ is_up(getindex(model,sne)) for sne in assets ])
    return sum_up > 0 ? true : false
end

function set_control_agent!(asset_id::Int, agent_id::Int, model)
    getindex(model,asset_id).controller_id = agent_id
    #TODO Consider removing this line below
    #To avoid putting info in model
    model.mapping_ctl_ntw[asset_id] = agent_id
end

"""
Given a SimNE id it returns its ntw node address.
"""
function get_address(eid::Int,g::AbstractGraph)::Int
    #res = filter(p->p[2] == eid,pairs(model.mapping_ntw_sne))
    #return !isempty(res) ? first(keys(res)) : -1
    return g[eid,:eid]
end

"""
Given a ntw node address it returns the corresponding SimNE id
"""
function get_eid(address::Int,model)::Int
    return model.mapping_ntw_sne[address]
end

function update_sne_address!(eid::Int,new_address::Int,model)
    #curr_address = get_address(eid,model)
    model.mapping_ntw_sne[new_address] = eid
end

"""
Update (ntw node) addresses of SimNE agents after removal of a given SimNE
"""
function update_addresses_removal!(dpn_id::Int,model)
    available_addr = get_address(dpn_id,model.ntw_graph)
    #log_info("Current length of g: $(nv(model.ntw_graph))")
    for addr::Int=available_addr:nv(model.ntw_graph)
        #log_info("Address $addr and its type: $(typeof(addr))")
        update_sne_address!(
            get_eid(addr+1,model),
            addr,
            model
            )
    end
    delete!(model.mapping_ntw_sne,length(model.ntw_graph)+1)
end

function circle_shape(h,k,r)
    θ = LinRange(0,2*π, 500)
    h .+ r*sin.(θ), k .+ r*cos.(θ)
end

function do_agent_step!(a::SimNE,model)
    #Process OF messages (packet data traffic)
    # log_info(model.ticks,a.id, "start step! $(get_state(a).up) ==> $(get_state(a).rul)")
    is_up(a) && is_ready(a) ? in_packet_processing(a,model) : nothing 
    
    # log_info(model.ticks,a.id,"rqsted: $(a.requested_ctl)")
    # @debug("[$(model.ticks)]($(a.id)) end step")
    deteriorate!(a,model)
end

function do_agent_step!(a::Agent,model)
   
    if is_up(a)
        # for sprt in sne_print
        #     log_info(model.ticks,a.id," step!: {$(sprt.id)} $(get_state(sprt).flow_table) ===> all ports: $(get_port_edge_list(sprt)) ===> paths: $(a.paths)")
        # end        

        ## Process OF Messages (SimNE to (sdn) control messages)
        is_ready(a) ? in_packet_processing(a,model) : nothing #log_info("queue of $(a.id) is empty")

        # Process inter-agent messages
        # log_info(model.ticks,a.id,"==> a.paths ==> $(a.paths)")
        do_receive_messages(a,model)

        do_maintenance_step!(a,a.maintenance.policy,model)
    end

    # log_info(model.ticks,a.id,25,"pending msgs: $(length(a.
    # pending)) --> $(a.pending)")
    # log_info(model.ticks,a.id,25,"QUEUE --> $(a.queue.data)")

    # do_confidence_check!(a,model)

    # if !isempty(get_state(a).active_paths)
    #     log_info(model.ticks,a.id,"ap-->$(get_state(a).active_paths)")
    # end

end

"""
    Receives inter-agent messages
"""
function do_receive_messages(a::Agent,model)
    #TODO: check if another periodicity is required, rather than every tick
    #if !isempty(a.msgs_in) log_info("[$(model.ticks)]($(a.id)) in msgs: $(a.msgs_in)") end

    #senders = [ m.sid for m in a.msgs_in ]
    #log_info("[$(model.ticks)]($(a.id)) has $(length(a.msgs_in)) msgs to process from $senders" )

    if model.ctrl_model != GraphModel(1)
        for msg in a.msgs_in
            #log_info(msg)
            process_msg!(a,msg,model)
        end
    end
end

function do_send_messages(a::Agent,model)
    g = a.params[:ctl_graph]
    # In this graph a is always node 1
    nbs = neighbors(g,1)

    for nb in nbs
        rid = get_prop(g,nb,:aid)
        send_msg!(a.id,rid,msg)
    end

end
"""
Records benchmark for a query
"""
function record_benchmark!(bdir,run_label,aid,query_time,query,query_graph,query_paths,benchmark)
    if benchmark 
        if !isdir(bdir)
        mkdir(bdir) 
        end
        #benchmark block start
        b = @benchmark begin 
            do_query($query_time,$query,$query_graph,$query_paths)
        end
        serialize( bdir * run_label *"_$(first(query))_$(last(query))_$(query_time)_$(aid)_bchmk.bin",b)
    end        
end

## main functions

new_config(seed,ctl_model,ntw_topo,size,n_steps,drop_proportion,prob_random_walks,benchmark, animation,k,Β,ctl_k,ctl_Β,mnt_policy,ntw_services,mnt_wc_duration,mnt_bc_duration,mnt_wc_cost,mnt_bc_cost,traffic_dist_params) =
    return ( seed = seed
            ,ctl_model=ctl_model
            ,ntw_topo = ntw_topo
            ,size=size
            ,n_steps=n_steps
            ,drop_proportion=drop_proportion
            ,prob_random_walks = prob_random_walks
            ,benchmark = benchmark
            ,animation = animation
            ,k=k
            ,Β = Β
            ,ctl_k=ctl_k
            ,ctl_Β = ctl_Β
            ,custom_topo = nothing
            ,ctl_custom_topo = nothing
            ,mnt_policy = mnt_policy
            ,ntw_services = ntw_services
            ,mnt_wc_duration = mnt_wc_duration
            ,mnt_bc_duration = mnt_bc_duration
            ,mnt_wc_cost = mnt_wc_cost
            ,mnt_bc_cost = mnt_bc_cost
            ,traffic_dist_params = traffic_dist_params
            )

function get_dropping_nodes(drop_proportion)
    #TODO calcualte according to proportion
    return Dict(
       50 => [3]
        #55: Grid and Grid fails
        , 75 => [8]
        #, 115 => [11]
        # , 70 => [10]
        #50=>[3,6] #TODO simoultaneous drops only work in centralised control
    #,120=>[2]
    ) # drop time => drop node
end

"""
It returns the next event time for a given random number and rate of events
"""
function next_event_time(rn,λ)
    return -log(1.0-rn)/λ
end

"""
return the times when random assets will fail
according to total sim time (N), quantity (q) of
assets and proportion. It receives also random 
"""
function get_dropping_times(seed,stabilisation_period,drop_proportion,q,N)
    Random.seed!(seed)
    #events 
    k = Int(round(q * drop_proportion))
    #rate events happening within time horizon 
    λ = k / (N - 2*stabilisation_period) # stabilisation period is substracted twice, so the disruption comes after this period and also allows for the same time to fix before simulation ends.
    #events happen randomly folling Poisson process with 
    # λ, after stabilisation_period
    
    event_times = Int.(round.(sort(stabilisation_period .+ next_event_time.(rand(k),[λ]))))

    #For testing
    event_times = [30,50]#,70]

    log_info("Dropping times are: $event_times")
    return event_times
end

function load_run_configs() 
    configs = []
    for ctl_model in [GraphModel(1)]#, ControlModel(4) ] #instances(ControlModel)
        for ntw_topo in [GraphModel(4)] #6
            for size in [16]#, 50, 100]
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
                                        push!(configs,new_config(seed,ctl_model,ntw_topo,size,200,drop_proportion,1.0,false,true,k,Β,ctl_k,ctl_Β,1,[(1,7),(4,1),(5,14),(12,8)],20,10,150.,100.,[1,0.05]))
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
    args = Dict()
    params = Dict()
    args[:N]=config.n_steps
    args[:Τ]=config.size
    args[:ΔΦ]=1
    ntw_graph = load_network_graph(get_graph(config.seed,config.size,config.ntw_topo;k=config.k,Β=config.Β,custom_topo=config.custom_topo))
    args[:ntw_graph]=ntw_graph
    # args[:dropping_nodes]= get_dropping_nodes(config.drop_proportion)
    args[:ctrl_model] = config.ctl_model
    args[:ntw_model] = config.ntw_topo

    args[:seed] = config.seed
    args[:benchmark] = config.benchmark
    args[:animation] = config.animation
    args[:prob_random_walks] = config.prob_random_walks
    args[:mnt_policy] = config.mnt_policy
    args[:ntw_services] = config.ntw_services
    args[:mnt_wc_duration] = config.mnt_wc_duration
    args[:mnt_bc_duration] = config.mnt_bc_duration
    args[:mnt_wc_cost] = config.mnt_wc_cost
    args[:mnt_bc_cost] = config.mnt_bc_cost
    args[:traffic_dist_params] = config.traffic_dist_params

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
    result_agents,result_model = run_model(config.n_steps,args,params; agent_data = adata, model_data = mdata)
    
    ctl_ags = last(result_agents[result_agents[!,:id] .> nv(ntw_graph) ,:],q_ctl_agents)[!,"get_state_trj"]
    nes = last(result_agents[result_agents[!,:id] .<= nv(ntw_graph) ,:],nv(ntw_graph))[!,"get_state_trj"]
    modbin = last(result_model)["get_state_trj"]

    nes_1 = vcat([ [ split(string(j-1)*";"*replace(to_string(nes[i][j]),"NetworkAssetState(" => ""),";") for j=1:length(nes[i])] for i=1:length(nes) ]...)

    ctl_ags_1 = vcat([ [ split(string(j-1)*";"*replace(to_string(ctl_ags[i][j]),"ControlAgentState(" => ""),";") for j=1:length(ctl_ags[i])] for i=1:length(ctl_ags) ]...)

    # print(last(result_model)["get_state_trj"])
    
    #sdir = data_dir*"runs2/$(config.ctl_model)/"
    sdir = data_dir*"runs3/"

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

    # nwords = Dict(1=>"one",2=>"two",3=>"three",4=>"four",5=>"five",6=>"six",7=>"seven",8=>"eight",9=>"nine",0=>"zero", 10=>"ten")

    # for i in 1:length(ctl_ags)
    #     for j in  1:length(ctl_ags[i])
    #         #log_info("$i - $j -> $(ctl_ags[i][j].a_id)")
    #         ij_paths = ctl_ags[i][j].paths
            
    #         # txt = objecttable(ctl_ags[i][j].paths)
    #         #::Dict{Symbol,Array{Tuple{Int64,Float64,Array{Int64}}}}
    #         ij_d::Dict{Symbol,Array{Int64}} = Dict()
    #         for k in keys(ij_paths)
    #             # ij_d[ Symbol("$(k[1])_$(k[2])") ] = [1]
                
    #             ij_d[ Symbol("$(nwords[k[1]])_$(nwords[k[2]])") ] = [1]
    #         end
    #         log_info("$i - $j -> $(keys(ij_d))")
    #         txt = objecttable(ij_d)
    #         log_info("$i - $j -> $txt")
    #     end
    # end
    
    # js_ctl_agents = objecttable(ctl_ags)

    ctl_ags_1 = [ replace.(ctl_ags_1[i]," Dict{Tuple{Int64,Int64},Array{Tuple{Int64,Float64,Array{Int64,N} where N},N} where N}" => "") for i=1:1]#length(ctl_ags_1) ]

    # ctl_ags_1 = [filter(x -> x .!= " ", ctl_ags_1[i]) for i=1:length(ctl_ags_1) ]

    model_data = last(result_model)["get_state_trj"]
    model_data = [ (m.tick,m.links_load) for m in model_data ]

    #ags_1 = [ split(string(i-1)*";"*replace(to_string(ags[j][i]),"NetworkAssetState(" => ""),";") for j=1:length(ags)] for i=1:length(ags[j]) ]
    open(sdir * run_label * "_steps_nelements.csv", "w") do io
        # writedlm(io, ["tick" "id" "up" "ports_edges" "pkt_in" "pkt_out" "pkt_drop" "flows"], ';')
        writedlm(io,reshape(vcat(["tick"],string.([i for i in fieldnames(NetworkAssetState)])),1,length(fieldnames(NetworkAssetState))+1),';')
        writedlm(io,nes_1,';') 
    end;
    

    # open(data_dir*"runs/$(config.ctl_model)/"*"$(config.size)_$(config.seed)_steps_ctl_agents.json", "w") do io
    #     write(io, js_ctl_agents)
    #  end

    open(sdir * run_label * "_steps_ctl_agents.csv", "w") do io
        # writedlm(io, ["tick" "id" "up" "paths" "in_ag_msg" "out_ag_msg" "in_of_msg" "out_of_msg" "q_queries" ], ';')
        writedlm(io,reshape(vcat(["tick"],string.([i for i in fieldnames(ControlAgentState)])),1,length(fieldnames(ControlAgentState))+1),';')
        writedlm(io,ctl_ags_1,';') 
    end;


    open(sdir * run_label * "_steps_model.csv", "w") do io
        writedlm(io,model_data,';') 
    end;

end

"""
Clears cache of control agent
# TODO Opportunity to investigate ways to store relevant cache rather than clearing all
"""
function clear_cache!(a::Agent,model::ABM)
    if model.ticks - a.params[:last_cache_graph] == model.clear_cache_graph_freq
        # log_info(model.ticks,a.id,"cc prev My graph-> vertices: $(nv(a.params[:ntw_graph])) -- edges: $(ne(a.params[:ntw_graph]))")
        a.params[:ntw_graph] = a.params[:base_ntw_graph]
        # log_info(model.ticks,a.id,"cc after My graph-> vertices: $(nv(a.params[:ntw_graph])) -- edges: $(ne(a.params[:ntw_graph]))")
        a.params[:last_cache_graph] = model.ticks
        a.paths = Dict()
    end

end

function clear_cache!(sne::SimNE,model::ABM)
    #placeholder
end

function to_string(s)
    sep = "; "
    return join([getfield(s,a) for a in fieldnames(typeof(s))],sep)
end

"""
Return SNEs that are up
"""
function get_live_snes(model)
    return [ sne.id for sne in allagents(model) if typeof(sne) == SimNE && get_state(sne).up  ]
end
"""
Return SNEs controlled by Agent a that are up
"""
function get_live_snes(a::Agent,model)
    controlled_snes = [ getindex(model,sid) for sid in get_controlled_assets(a.id,model)]
    return [ sne.id for sne in controlled_snes if get_state(sne).up  ]
end

# function init_logger(log_name)
#     loggers[log_name] = getlogger(log_name)
#     setlevel!(loggers[log_name], "info")
#     push!(loggers[log_name],getlogger(name="root"))
#     # push!(loggers[log_name], DefaultHandler(tempname(), DefaultFormatter("[{date} | {level} | {name}]: {msg}")))
#     return loggers[log_name]
# end