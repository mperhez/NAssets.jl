#export NetworkAssetState, ModelState, ControlAgentState
function forward!(msg::OFMessage,src::SimNE,model)
    # log_info("[$(model.ticks)]($(src.id)) Packet $(msg.id) delivered")
    out_pkt_count = get_state(src).out_pkt + 1
    set_out_pkt!(src,out_pkt_count)

    if !haskey(src.one_way_time_pkt,msg.data.src)
        src.one_way_time_pkt[msg.data.src] = Array{Int64,1}()
    end
    push!(src.one_way_time_pkt[msg.data.src],model.ticks - msg.data.time_sent)
end

function forward!(msg::OFMessage,src::SimNE,dst::SimNE,reason::Ofp_Protocol,model)
    # if model.ticks > 45 && model.ticks < 60 
    #     log_info(model.ticks,src.id,5,"[$(model.ticks)] ($(src.id)) forwarding $msg")
    # end
    in_ports = filter(p->p[2]=="s$(src.id)",get_port_edge_list(dst))
    in_port = in_ports[1][1]
    push_msg!(src,dst,OFMessage(next_ofmid!(model),model.ticks,src.id,in_port,reason,msg.data),model)
    #@show msg out_port
    # Next two lines are inside push_msg!
    # out_pkt_count = get_state(src).out_pkt + 1
    # set_out_pkt!(src,out_pkt_count)
end

function route_traffic!(a::SimNE,msg::OFMessage,model)
    
    out_pkt_count = 0
    flow = filter(fw -> 
                            ( fw.match_rule.src == string(msg.data.src) || fw.match_rule.src == "*" )
                            && (fw.match_rule.in_port == string(msg.in_port) || fw.match_rule.in_port == "*" )
                            && (fw.match_rule.dst == string(msg.data.dst) || fw.match_rule.dst == "*")
                            , get_flow_table(a))
                            
    if !isempty(flow)
        # if model.ticks > 40 && model.ticks < 60
        #     log_info(model.ticks,a.id,5," Routing Msg $(msg) --- $(msg.in_port)----    flout_out: $(flow[1].params[1][1]) --- all ports: $(get_port_edge_list(a))")
        # end
        
        if flow[1].action == OFS_Output
            if flow[1].params[1][1] != 0
                ports = get_port_edge_list(a)
                dst_id = parse(Int64,filter(x->x[1]==flow[1].params[1],ports)[1][2][2:end])
                dst = getindex(model,dst_id)

                #OFPR_NO_MATCH: here used to tell other SNE that packet couldn't reach destination.
                if flow[1].params[1] == msg.in_port 
                    log_info(model.ticks,a.id,"Forward NO MATCH to ($dst) ")
                    forward!(msg,a,dst,OFPR_NO_MATCH,model)
                    ftype = msg.data.src == a.id ? msg.data.dst == dst_id ? Flow_Type(-2) : Flow_Type(-1) : msg.data.dst == dst_id ? Flow_Type(1) : Flow_Type(0)
                    record_active_flow!(model,a.id,dst_id,ftype)

                    #drop following packets
                    delete_flow!(a,flow[1].params[1],model)
                    nfw = deepcopy(flow[1])
                    nfw.action = OFS_Drop
                    install_flow!(nfw,a,model)

                else

                    forward!(msg,a,dst,OFPR_ACTION,model)
                    ftype = msg.data.src == a.id ? msg.data.dst == dst_id ? Flow_Type(-2) : Flow_Type(-1) : msg.data.dst == dst_id ? Flow_Type(1) : Flow_Type(0)
                    record_active_flow!(model,a.id,dst_id,ftype)

                end



            else
            forward!(msg,a,model)
            #    record_active_flow!(model,a.id,a.id,Flow_Type(1))
            end
        elseif flow[1].action == OFS_Drop
            drop_packet!(a)
        end
    else
        query = (a.id,msg.data.dst)
        
        if !haskey(a.requested_ctl,query) 
            of_qid = next_ofmid!(model)
            ctl_msg = OFMessage(of_qid,model.ticks,a.id,msg.in_port,msg.data)
            send_msg!(a.controller_id,ctl_msg,model)
            track_pending_query!(a,model.ticks,query...)
        end
                
        #return package to queue as it does not know what to do with it
        push!(a.pending,msg)

    end
end



"""
    push OF message to from src SimNE to dst SimNE
"""
function push_msg!(src::SimNE,dst::SimNE,msg::OFMessage,model)
    #put!(sne.queue,msg)
    
    l = (get_address(src.id,model.ntw_graph),get_address(dst.id,model.ntw_graph))
    l = l[1] < l[2] ? l : (l[2],l[1])
    if !haskey(model.ntw_links_msgs,l)
        init_link_msg!(l,model)
    end
    link_queue = last(model.ntw_links_msgs[l])
    push!(link_queue,msg)
    links_load = get_state(model).links_load
    current_load = haskey(links_load,l) ? links_load[l] : 0

    links_load[l] = current_load + 1    
    

    out_pkt_count = get_state(src).out_pkt + 1
    set_out_pkt!(src,out_pkt_count)
    # if model.ticks > 45 && model.ticks < 60 
    #      log_info(model.ticks,src.id,5,"AFTER push msgs: $(model.ntw_links_msgs)")
    #      log_info(model.ticks,src.id,9,"AFTER push msgs: $(model.ntw_links_msgs)")
    # end
end

"""
    push OF message to from simulated host to dst SimNE
"""
function push_msg!(dst::SimNE,msg::OFMessage)
    put!(dst.queue,msg)
    in_pkt_count = get_state(dst).in_pkt + 1
    set_in_pkt!(dst,in_pkt_count)
end

function install_flow!(msg::OFMessage, sne::SimNE,model)
    nf = first(msg.data)
    qid = last(msg.data)
    install_flow!(nf,sne,model)   
    if qid < 0
        clear_pending_query!(sne,nf,qid)
    end
end

function install_flow!(flow::Flow, sne::SimNE,model)
    log_info(model.ticks,sne.id," Installing flow: $(sne.id) - $(flow)")
    ft = get_state(sne).flow_table
    
    #Assumes only one flow to a given destination, hence replace existing flows leading towards the same destination
    nft = [ f for f in ft if f.match_rule.dst != flow.match_rule.dst ]
    
    push!(nft,flow) #msg.data[1] = flow, msg.data[2] = query_id:qid
    set_flow_table!(sne,nft)
    log_info(model.ticks,sne.id," Installed flow: $(sne.id) - $(get_state(sne).flow_table)")
end


"""
    Packet processing per tick per agent
"""
function in_packet_processing(a::AbstractAgent,model)
    in_pkt_count = 0
    out_pkt_count = 0
    processed_tick = 0
    actions_to_process = []
    
    ppt = a.params[:pkt_per_tick]#get_random_packets_to_process(model.seed,model.ticks+a.id,a.params[:pkt_per_tick])

    while is_ready(a)
        msg = take_msg!(a)

        if processed_tick <= ppt
            #process first non-action msgs which have greater priority e.g. node drop
            if msg.reason == OFPR_ACTION
                push!(actions_to_process,msg)
            else
                process_msg!(a,msg,model)
            end
            processed_tick += 1
        else
            push_pending!(a,msg)
        end
    end
    #process action msgs
    for msg in actions_to_process
        process_msg!(a,msg,model)
    end
end

"""
Processes msgs to SimNE
"""
function process_msg!(sne::SimNE,msg::OFMessage,model)
    @match msg.reason begin
        Ofp_Protocol(1) =>  
                        begin
                            route_traffic!(sne,msg,model)
                        end
        Ofp_Protocol(3) => 
                        begin
                            # log_info("[$(model.ticks)]($(sne.id)) -> processing $(msg.reason)")
                            install_flow!(msg,sne,model)       
                        end
        Ofp_Protocol(4) => 
                        begin
                            log_info(model.ticks,sne.id,"Received NO MATCH ==> $msg")
                            delete_flow!(sne,msg.in_port,model)       
                        end
                            
        _ => begin
            log_info("[$(model.ticks)]($(sne.id)) -> match default")
            end
    end
end

"""
    It enqueues packets that were not processed in 
    previous time steps. It discard packets according to defined size of the queue.
"""

function pending_pkt_handler(a::SimNE,model)
    # if model.ticks in 80:1:90 && a.id == 10
    # end
    q_i = 0
    if !isempty(a.pending)
        # log_info("[$(model.ticks)]($(a.id)) pending: $(length(a.pending))")

        for msg in a.pending 
            if msg.reason == OFPR_ACTION
                if(q_i <= model.:max_queue_ne)
                    put!(a.queue,msg)
                    q_i+= 1
                else
                    drop_packet!(a)
                end
            else
                put!(a.queue,msg)
            end
        end
       empty_pending!(a)
    end
end


function throughput(bytes₋₁,bytes₀, τ₋₁,τ₀)
    Δτ = τ₀ - τ₋₁
    Δbytes = bytes₀ - bytes₋₁
    #log_info("Δbytes: $(bytes₀)  - $(bytes₋₁) / Δτ: $(Δτ)")
    return Δτ > 0 && Δbytes >= 0 ? Δbytes / Δτ : 0
end

"""
It simulates operations happening in a network asset
when the link corresponding to the given dpn_id goes down. sne is up and node went down is dpn_id.
"""
function link_down!(sne::SimNE,dpn_id::Int,model)
    # log_info(model.ticks,sne.id,"BEFORE link down start $dpn_id - all ports: $(get_port_edge_list(sne))")
    #remove from list of ports
    new_port_edge_list::Vector{Tuple{Int64,String}} = []
    dpn_port = -1
    ports = get_port_edge_list(sne)
    for p in ports
        if p[2]!="s"*string(dpn_id)
            push!(new_port_edge_list,p)
        else
            dpn_port = p[1]
        end
    end
    delete_flow!(sne,dpn_port,model)
    set_port_edge_list!(sne,new_port_edge_list)
    controller = getindex(model,sne.controller_id)
    # log_info(model.ticks,sne.id,"Triggering event to ag: $(sne.controller_id) for dpn_id: $dpn_id ")
    trigger_of_event!(model.ticks,controller,dpn_id,Ofp_Event(1),model)
    # log_info(model.ticks,sne.id,"AFTER link down start $dpn_id - all ports: $(get_port_edge_list(sne))")
end

"""
It simulates operations happening in a network asset
when the link corresponding to the given rjn_id rejoins. sne is up and node re-joining is rjn_id.
"""
function link_up!(sne::SimNE,rjn_id::Int,model)
    #add to the list of ports
    nbs = all_neighbors(model.ntw_graph,get_address(sne.id,model.ntw_graph))
    #save original port number
    for i in 1:size(nbs,1)
        if nbs[i] == rjn_id
            push_ep_entry!(sne,(i,"s$(nbs[i])"))
        end
    end
    controller = getindex(model,sne.controller_id)
    #simulates controller detects port up
    trigger_of_event!(model.ticks,controller,(sne.id,rjn_id),Ofp_Event(2),model)   
end

"""
A controller agent is notified of an event happening in the controlled element

"""
function trigger_of_event!(ticks::Int,a::Agent,ev_data,ev_type::Ofp_Event,model)
    msg = @match ev_type begin
        Ofp_Event(1) =>
                            OFMessage(next_ofmid!(model),ticks,a.id,OFPPR_DELETE,ev_data)
        Ofp_Event(2) => OFMessage(next_ofmid!(model),ticks,a.id,OFPPR_JOIN,ev_data)
    end
    # log_info(model.ticks,a.id,"Triggering event: $(msg)")
    push_msg!(a,msg)
end

# #Controller method to handle changes in port switches
# function port_status_handler(a::Agent,event::Ofp_Event)

# end


function get_state(sme::SimNE)::State
    return last(sme.state_trj)
end

function init_state!(sme::SimNE)
    new_state = deepcopy(get_state(sme)) #!isnothing(get_state(sme)) ? deepcopy(get_state(sme)) : NetworkAssetState(sme.id)
    new_state.in_pkt = 0
    new_state.out_pkt = 0
    new_state.drop_pkt = 0
    new_state.throughput_out = Dict()
    push!(sme.state_trj,new_state)
    sme.one_way_time_pkt = Dict()
end
function init_state!(a::Agent)
    new_state = deepcopy(get_state(a)) #!isnothing(get_state(sme)) ? deepcopy(get_state(sme)) : NetworkAssetState(sme.id)
    new_state.in_ag_msg = 0
    new_state.out_ag_msg = 0
    new_state.path_scores =  []
    push!(a.state_trj,new_state)
end


function is_up(sne::SimNE)
    return get_state(sne).up
end

function is_up(a::Agent)
    return get_state(a).up
end

function set_port_edge_list!(sne::SimNE,port_edge_list::Vector{Tuple{Int64,String}})
    state = get_state(sne)
    state.port_edge_list = port_edge_list
    set_state!(sne,state)
end

function set_state!(sne::SimNE,new_state::NetworkAssetState)
    pop!(sne.state_trj)
    push!(sne.state_trj,new_state)
end

function set_down!(sne::SimNE)
    state = get_state(sne)
    state.up = false
    state.flow_table = []
    state.in_pkt = 0
    state.out_pkt  = 0
    state.port_edge_list = []
    set_state!(sne,state)
end

function set_up!(sne::SimNE)
    state = get_state(sne)
    state.up = true
    set_state!(sne,state)
end

function is_ready(a::Agent)
    return isready(a.queue)
end

function is_ready(sne::SimNE)
    return isready(sne.queue)
end

"""
Push a new port edge pair
"""
function push_ep_entry!(sne::SimNE,ep_entry::Tuple{Int64,String})
    state = get_state(sne)
    push!(state.port_edge_list,ep_entry)
    set_state!(sne,state)
end

function push_flow!(sne::SimNE,flow::Flow)
    state = get_state(sne)
    push!(state.flow_table,flow)
    set_state!(sne,state)
end



function set_in_pkt!(sne::SimNE,in_pkt::Int)
    state = get_state(sne)
    state.in_pkt = in_pkt
    set_state!(sne,state)
end
function set_out_pkt!(sne::SimNE,out_pkt::Int)
    state = get_state(sne)
    state.out_pkt = out_pkt
    set_state!(sne,state)
end

function get_pending(a::AbstractAgent)
    return a.pending
end

function empty_pending!(a::AbstractAgent)
    empty!(get_pending(a))
end

function get_port_edge_list(sne::SimNE)
    return get_state(sne).port_edge_list
end

function set_flow_table!(sne::SimNE,new_flow_table::Vector{Flow})
    state = get_state(sne)
    state.flow_table = new_flow_table
    set_state!(sne,state)
end
function get_flow_table(sne::SimNE)
    return get_state(sne).flow_table
end

function track_pending_query!(sne::SimNE,request_time::Int64,src::Int64,dst::Int64)
    #only one query is sent, then control ag will decide if reattempt
    sne.requested_ctl[(src,dst)] = request_time
end

function clear_pending_query!(sne::SimNE,flow::Flow,qid::Int64)
    #clear requested queries
    query = (flow.dpid,parse(Int64,flow.match_rule.dst))
    new_rq_ctl = Dict()
    log_info(sne.id," BEFORE Cleared: $(sne.requested_ctl)")
    for k in keys(sne.requested_ctl)
        if k != query
            new_rq_ctl[k] = sne.requested_ctl[k]
        end
    end
    sne.requested_ctl = new_rq_ctl
    log_info(sne.id," AFTER Cleared: $(sne.requested_ctl)")
end



function take_msg!(sne::SimNE)
    return take!(sne.queue)
end

function take_msg!(a::Agent)
    take!(a.queue)
end

function get_state_trj(sne::SimNE)::Vector{State}
    return sne.state_trj
end

"""
    Calculates throughput for the given trajectory
    - packet/bytes trajectory 
    - interval: time steps

"""
function get_throughput(pb_trj::Array{Float64,1},interval::Int)
    # print("received......-> $pkt_trj ")
    acc_pb = zeros(Float64,min(length(pb_trj),interval))

    if length(pb_trj) >= interval
         acc_pb = vcat(acc_pb[1:end-1],rolling(mean,pb_trj,interval))
    end

    # b_1 = zeros(Float64,min(interval,length(pkt_trj)))
    # b_2 = pkt_trj[1:end-interval]
    # b = vcat(b_1,b_2)
    # log_info("calculating tpt......-> $(a) -- $(b_1) -- $(b_2) -- $b ")
    # result = get_throughput.(a,b,[interval]) 
    # log_info("result of tpt is $result")
    return acc_pb

end

"""
It filters throughput only when the given sne is up
"""
function get_throughput_up(sne::SimNE,model)
    v_pkt_in = [ s.out_pkt * model.:pkt_size for s in sne.state_trj ]
    v_up = [ s.up for s in sne.state_trj ]
    v_tpt = get_throughput(v_pkt_in,model.:interval_tpt)
    return [ v_up[i] ? v_tpt[i] : 0.0   for i=1:length(v_tpt)]
end

function get_throughput_trj(sne::SimNE)
     [ isempty(st.throughput_out) ? 0 : mean([st.throughput_out[k] for k in keys(st.throughput_out)])  for st in sne.state_trj]
end

function get_packet_loss_trj(sne::SimNE)
    [ st.drop_pkt  for st in sne.state_trj ]
end


function get_condition_ts(a::Agent)
    #return a.id
    return ones(1,1)
end

function get_condition_ts(sne::SimNE)
    return get_state(sne).condition_ts
end

function get_rul(a::Agent)
    return 0.0
end
function get_rul(sne::SimNE)
    return get_state(sne).rul
end

"""
    It records active flow for reporting active path
"""
function record_active_flow!(m,src,dst,ftype)
    m_state = get_state(m)
            nf = (src,dst,ftype)
            if isempty(filter(af->af==nf,m_state.active_flows))
                af = m_state.active_flows
                push!(af,nf)
            # log_info(m.ticks,"aflows: $(get_state(m).active_flows)")
            end
end


function delete_flow!(sne::SimNE,out_port::Int64,model::ABM)

    new_flow_table::Vector{Flow} = []
    
    for f in get_flow_table(sne)
        # log_info(model.ticks,sne.id,"Existing flow: $f --> $out_port ---> $(f.params) ---> all ports: $(get_port_edge_list(sne))")
        if  ~(out_port in f.params)
            push!(new_flow_table,f)
        end    
    end
    set_flow_table!(sne,new_flow_table)
    
    # log_info(model.ticks,sne.id,"New flow table AFTER DELETE: $new_flow_table ---> all ports: $(get_port_edge_list(sne))")
end

function drop_packet!(sne::SimNE)
    s = get_state(sne)
    s.drop_pkt += 1
    set_state!(sne,s)
end


function calculate_metrics_step!(sne::SimNE,model::ABM)
    state = get_state(sne)

    for k in keys(sne.one_way_time_pkt)
        # state.throughput_out[k] = mean(model.pkt_size .* sne.one_way_time_pkt[k])
        state.throughput_out[k] = ( model.pkt_size * length(sne.one_way_time_pkt[k])) / mean(sne.one_way_time_pkt[k])
        # pkt_size * No. pkts / mean time it took each pkt

    end
    set_state!(sne,state)
    # log_info(model.ticks,sne.id," tpt_trj: $([ st.throughput_out for st in sne.state_trj])")
end