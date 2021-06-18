@enum Ofp_Event begin
    EventOFPPortStatus
end
@enum Ofp_Protocol begin
    OFPR_ACTION = 1
    OFPPR_DELETE = 2
    OFPR_ADD_FLOW = 3
    OFPR_NO_MATCH = 4
end
@enum OFS_Action begin
    OFS_Output = 1
    OFS_Drop = 2
end

@enum AG_Protocol begin
    QUERY_PATH = 1
    MATCH_PATH = 2
    NEW_NB = 3
    NE_DOWN = 4
end
#@enum Ofp_Config_Flag EventOFPPortStatus=1 



#if has come from in_port and src, going to dst
mutable struct MRule 
    in_port::String
    src::String
    dst::String
end

mutable struct DPacket <: Packet
    id::Int64
    src::Int64
    dst::Int64
    size::Float64 # in bytes
    time_sent::Int64
    hop_limit::Int64
end


abstract type CTLMessage end

mutable struct OFMessage <: CTLMessage
    id::Int64
    ticks::Int
    dpid::Int # sender of msg,  aka SimNE.id aka switch.id
    in_port::Int # (Optional) sender's input port, in SimNE to ControlAg comm, this is the port where the packet was received
    reason::Ofp_Protocol
    data::Any
end

mutable struct AGMessage <: CTLMessage
    mid::Int
    ticks::Int
    sid::Int # sender id
    rid::Int # receiver id
    reason::AG_Protocol # Type of msg as per enum
    body::Dict{Symbol,Any}
end


function OFMessage(id::Int64,ticks::Int,dpid::Int,reason::Ofp_Protocol)
    return OFMessage(id,ticks,dpid,-1,reason,nothing)
end

"""
    Message with default reason: Forward
"""
function OFMessage(id::Int64,ticks::Int,dpid::Int,in_port::Int,data::DPacket)
    return OFMessage(id,ticks,dpid,in_port,OFPR_ACTION,data)
end

"""
    Message with no input port
"""
function OFMessage(id::Int64,ticks::Int,dpid::Int,ofp::Ofp_Protocol,data::Int)
    return OFMessage(id,ticks,dpid,-1,ofp,data)
end

mutable struct OFEvent
    msg::OFMessage    
end


mutable struct Flow 
    dpid::Int64 # datapath id
    match_rule::MRule
    params::Vector{Any}
    action::OFS_Action # out_port, TODO: Check if other actions are needed
end


# mutable struct NEStatistics 
#     tick::Int64
#     ne_id::Int64
#     throughput_in::Float64
#     throughput_out::Float64
# end

#State for which we need to save trajectory
mutable struct NetworkAssetState <: State
    ne_id::Int64
    up::Bool
    port_edge_list::Vector{Tuple{Int64,String}}
    in_pkt::Int64
    out_pkt::Int64
    drop_pkt::Int64
    flow_table::Vector{Flow}
    # throughput_in::Float64
    # throughput_out::Float64
    pending_queries::Vector{Int64}
end

function NetworkAssetState(ne_id::Int)
    NetworkAssetState(ne_id,true,Vector{Tuple{Int64,String}}(),0,0,0,Vector{Flow}(),[])
end

mutable struct ControlAgentState <: State
    a_id::Int64
    up::Bool
    active_paths::Dict{Tuple{Int64,Int64},Array{Tuple{Int64,Float64,Array{Int64}}}}
    in_ag_msg::Float64
    out_ag_msg::Float64
    in_of_msg::Float64
    out_of_msg::Float64
    q_queries::Float64
    path_scores::Array{Tuple{Int64,Int64,Float64}}
end

mutable struct SDNCtlAgState <: State
    up::Bool
    color::Symbol
    condition_trj::Array{Float64,2}
    health_trj::Vector{Float64}
    #paths::Vector{Tuple{Int64,Int64,Array{Array{Int64}}}} # src,dst,path
    #paths: Dict key: (src,dst) => value: [(tick-updated,score,path)]
    active_paths::Dict{Tuple{Int64,Int64},Array{Tuple{Int64,Float64,Array{Int64}}}}
    in_pkt_trj::Vector{Int64}
    out_pkt_trj::Vector{Int64}
    queue::Channel{OFMessage}
end

function SDNCtlAgState(condition_trj::Array{Float64,2}, health_trj::Vector{Float64})
    SDNCtlAgState(true,:lightblue,condition_trj,health_trj,Dict{Tuple{Int64,Int64},Array{Tuple{Int64,Float64,Array{Int64}}}}(),Vector{Int64}(),Vector{Int64}(),Channel{OFMessage}(500))
end


"""
    Control Agent
"""
mutable struct Agent <: SOAgent
    id::Int64
    pos::Int64
    color::Symbol
    size::Float16
    pending::Vector{Tuple{Int64,OFMessage}} # Timeout for this msg to be reprocessed & msg
    of_started::Vector{Tuple{Int64,Int64}} # msg.id,  Time when msg was started
    # state::SDNCtlAgState
    # key(src,dst): value(tick_found,confidence,score,path)
    paths::Dict{Tuple{Int64,Int64,Array{Int64}},Array{Tuple{Int64,Float64,Float64,Array{Int64}}}} # pre-calculated paths for operation
    state_trj::Vector{ControlAgentState}
    msgs_links::Array{Vector{AGMessage},2}
    msgs_in::Vector{AGMessage}
    queue::Channel{OFMessage}
    previous_queries::Dict{Tuple{Int64,Int64,Array{Int64}},Tuple{Int64,Array{Int64}}} # (src,dst):(tick last queried,[list pkt senders that originated query])
    matched_queries::Dict{Tuple{Int64,Int64,Array{Int64}},Int64} 
    params::Dict{Symbol,Any}
end


function Agent(id,nid,params)
    # s0 = SDNCtlAgState(zeros((2,2)),Vector{Float64}())
    s0 = ControlAgentState(id,true,Dict(),0,0,0,0,0,[])
    Agent(id,nid,:lightblue,0.1,Vector{OFMessage}(),Vector{Tuple{Int64,Int64}}(),Dict{Tuple{Int64,Int64,Array{Int64}},Array{Tuple{Int64,Float64,Array{Int64}}}}(),[s0],Array{Vector{AGMessage}}(undef,1,1),[],Channel{OFMessage}(500),Dict(),Dict(),params)
end


"""
    Simulated Physical Network Element
"""
mutable struct SimNE <: SimAsset
    id::Int64
    pos::Int64
    size::Float16
    queue::Channel{OFMessage} # 
    pending::Vector{OFMessage}
    requested_ctl::Vector{Tuple{Int64,Int64,Int64}} # flows requested to controller
    state_trj::Vector{NetworkAssetState}
    condition_ts::Array{Float64,2} # Pre-calculated time series of the condition of asset
    rul::Array{Float64,1}
    controller_id::Int64
    params::Dict{Symbol,Any}
end
function SimNE(id,nid,params,max_q)
    SimNE(id,nid,0.3,Channel{OFMessage}(max_q),Vector{OFMessage}(),Vector{Tuple{Int64,Int64,Int64}}(),[NetworkAssetState(id)],zeros(Float64,2,1),[],-1,params) #initialise SimNE with a placeholder in the controller
end

function init_switch(a,model)
    
end

#in_port, src, dst -> action
#pkt

# function evaluate(rule::MRule)(pkt::DPacket)
#     @match pkt begin
#         ()
#     end
# end



# function ask_controller(sne::SimNE,a::Agent,msg::OFMessage)
#     #TODO in_processing msgs of controller to install flow for unknown dst
# end

function forward!(msg::OFMessage,src::SimNE,model)
    # log_info("[$(model.ticks)]($(src.id)) Packet $(msg.id) delivered")
    out_pkt_count = get_state(src).out_pkt + 1
    set_out_pkt!(src,out_pkt_count)
end

function forward!(msg::OFMessage,src::SimNE,dst::SimNE,reason::Ofp_Protocol,model)
    # log_info("[$(model.ticks)] ($(src.id)) forwarding $msg")
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
        # log_info(model.ticks,a.id,9," Routing Msg $(msg) --- $(msg.in_port)---- flout_out: $(flow[1].params[1][1]) --- all ports: $(get_port_edge_list(a))")
        
        if flow[1].action == OFS_Output
            if flow[1].params[1][1] != 0
                ports = get_port_edge_list(a)
                dst_id = parse(Int64,filter(x->x[1]==flow[1].params[1],ports)[1][2][2:end])
                dst = getindex(model,dst_id)

                #OFPR_NO_MATCH: here used to tell other SNE that packet couldn't reach destination.
                if flow[1].params[1] == msg.in_port 
                    forward!(msg,a,dst,OFPR_NO_MATCH,model)
                    ftype = msg.data.src == a.id ? msg.data.dst == dst_id ? Flow_Type(-2) : Flow_Type(-1) : msg.data.dst == dst_id ? Flow_Type(1) : Flow_Type(0)
                    record_active_flow!(model,a.id,dst_id,ftype)


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
        similar_requests = filter(r->(r[2],r[3]) == (msg.data.src,msg.data.dst) && (model.ticks - r[1]) < model.ofmsg_reattempt+1,a.requested_ctl)

        if isempty(similar_requests)
            # controller = getindex(model,a.controller_id)
            #ask_controller(a,controller,msg)
            of_qid = next_ofmid!(model)
            ctl_msg = OFMessage(of_qid,model.ticks,a.id,msg.in_port,msg.data)
            send_msg!(a.controller_id,ctl_msg,model)
            push!(a.requested_ctl,(model.ticks,msg.data.src,msg.data.dst))
            # log_info("pending query: $of_qid -> $(msg.data.src) - $(msg.data.dst)")
            push_pending_query!(a,of_qid)
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
    #log_info("[$(model.ticks)] msgs: $(model.ntw_links_msgs)")
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
    #ports = get_port_edge_list(sne,model)
    nf = first(msg.data)
    install_flow!(nf,sne,model)
    pop_pending_query!(sne,last(msg.data))
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

function in_packet_processing(a::AbstractAgent,model)
    in_pkt_count = 0
    out_pkt_count = 0
    processed_tick = 0
    actions_to_process = []
    
    while is_ready(a)
        msg = take_msg!(a)

        if processed_tick <= a.params[:pkt_per_tick]
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
    log_info(model.ticks,a.id,"pending msgs: $(length(a.pending))")
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
when the link corresponding to the given dpn_id goes down
"""
function link_down!(sne::SimNE,dpn_id::Int,model)
    # log_info("[$(model.ticks)]($(sne.id)) link down start")
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
    log_info(model.ticks,sne.id,"Triggering event to ag: $(sne.controller_id) for dpn_id: $dpn_id ")
    trigger_of_event!(model.ticks,controller,dpn_id,EventOFPPortStatus,model)
end

"""
A controller agent is notified of an event happening in the controlled element
"""
function trigger_of_event!(ticks::Int,a::Agent,eid::Int,ev_type::Ofp_Event,model)
    msg = @match ev_type begin
        EventOFPPortStatus =>
                            OFMessage(next_ofmid!(model),ticks,a.id,OFPPR_DELETE,eid)
    end
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
    push!(sme.state_trj,new_state)
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
    set_state!(sne::SimNE,state)
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

function push_pending_query!(sne::SimNE,new_pending_query::Int64)
    state = get_state(sne)
    push!(state.pending_queries,new_pending_query)
    #log_info("sending query $new_pending_query")
    set_state!(sne,state)
end

function pop_pending_query!(sne::SimNE,pending_query::Int64)
    state = get_state(sne)
    new_pq = []
    for pq in state.pending_queries
        if pq != pending_query
            push!(new_pq,pq)
        end
    end
    state.pending_queries = new_pq
    set_state!(sne,state)
end

function get_pending_queries(sne::SimNE)
    return get_state(sne).pending_queries
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


# function get_throughput(e_tpt::Float64,s_tpt::Float64,interval::Int)::Float64
#     return (e_tpt - s_tpt) > 0 && interval > 0 ? (e_tpt - s_tpt) / interval : 0.0
# end

# function get_throughput(a::Agent)::Int
#     return 0
# end

function get_condition_ts(a::Agent)
    #return a.id
    return ones(1,1)
end

function get_condition_ts(sne::SimNE)
    return sne.condition_ts
    #return sne.id
end

function get_rul_ts(a::Agent)
    return [0]
end
function get_rul_ts(sne::SimNE)
    return sne.rul
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
        log_info(model.ticks,sne.id,"Existing flow: $f --> $out_port ---> $(f.params) ---> all ports: $(get_port_edge_list(sne))")
        if  ~(out_port in f.params)
            push!(new_flow_table,f)
        end    
    end
    set_flow_table!(sne,new_flow_table)
    
    log_info(model.ticks,sne.id,"New flow table AFTER DELETE: $new_flow_table ---> all ports: $(get_port_edge_list(sne))")
end

function drop_packet!(sne::SimNE)
    s = get_state(sne)
    s.drop_pkt += 1
    set_state!(sne,s)
end