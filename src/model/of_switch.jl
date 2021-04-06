@enum Ofp_Event begin
    EventOFPPortStatus
end
@enum Ofp_Protocol begin
    OFPR_ACTION = 1
    OFPPR_DELETE = 2
    OFPR_ADD_FLOW = 3
end
@enum OFS_Action begin
    OFS_Output = 1
end

@enum AG_Protocol begin
    QUERY_PATH = 1
    MATCH_PATH = 2
    NEW_NB = 3
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
    size::Int64 # in bytes
    time_sent::Int64
    hop_limit::Int64
end


abstract type CTLMessage end

mutable struct OFMessage <: CTLMessage
    id::Int64
    ticks::Int
    dpid::Int # sender of msg,  aka SimNE.id aka switch.id
    in_port::Int # (Optional) sender's input port
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
    flow_table::Vector{Flow}
    # throughput_in::Float64
    # throughput_out::Float64
end

function NetworkAssetState(ne_id::Int)
    NetworkAssetState(ne_id,true,Vector{Tuple{Int64,String}}(),0,0,Vector{Flow}())
end

mutable struct SDNCtlAgState <: State
    up::Bool
    color::Symbol
    condition_trj::Array{Float64,2}
    health_trj::Vector{Float64}
    #paths::Vector{Tuple{Int64,Int64,Array{Array{Int64}}}} # src,dst,path
    #paths: Dict key: (src,dst) => value: [(tick-updated,score,path)]
    paths::Dict{Tuple{Int64,Int64},Array{Tuple{Int64,Float64,Array{Int64}}}}
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
    state::SDNCtlAgState
    state_trj::Vector{SDNCtlAgState}
    msgs_links::Array{Vector{AGMessage},2}
    msgs_in::Vector{AGMessage}
    params::Dict{Symbol,Any}
end


function Agent(id,nid,params)
    s0 = SDNCtlAgState(zeros((2,2)),Vector{Float64}())
    Agent(id,nid,:lightblue,0.1,Vector{OFMessage}(),Vector{Tuple{Int64,Int64}}(),s0,[s0],Array{Vector{AGMessage}}(undef,1,1),[],params)
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
function SimNE(id,nid,params)
    SimNE(id,nid,0.3,Channel{OFMessage}(5000),Vector{OFMessage}(),Vector{Tuple{Int64,Int64,Int64}}(),[NetworkAssetState(id)],zeros(Float64,2,1),[],-1,params) #initialise SimNE with a placeholder in the controller
end

function init_switch(a,model)
    #action to forward via port 1
    #push!(a.state.flow_table,Flow(1,MRule(0,1,7),(pkt)->forward(pkt,1)))
    # for port_edge in a.state.port_edge_list
    #     push!(a.state.flow_table,Flow(a.id,MRule(port_edge[1],"*",),(pkt)->forward(pkt,1)))
    # end
end

#in_port, src, dst -> action
#pkt

# function evaluate(rule::MRule)(pkt::DPacket)
#     @match pkt begin
#         ()
#     end
# end



# function ask_controller(sne::SimNE,a::Agent,msg::OFMessage)
#     put!(a.state.queue,OFMessage(next_ofmid!(model),msg.ticks,sne.id,msg.in_port,msg.data))
#     #TODO in_processing msgs of controller to install flow for unknown dst
# end

function forward(msg::OFMessage,src::SimNE,model)
    #println("Packet $(msg.id) delivered")
    out_pkt_count = get_state(src).out_pkt + 1
    set_out_pkt!(src,out_pkt_count)
end

function forward(msg::OFMessage,src::SimNE,dst::SimNE,model)
    in_ports = filter(p->p[2]=="s$(src.id)",get_port_edge_list(dst))
    in_port = in_ports[1][1]
    push_msg!(src,dst,OFMessage(next_ofmid!(model),model.ticks,src.id,in_port,msg.data),model)
    #@show msg out_port
end

function route_traffic!(a::SimNE,msg::OFMessage,model)
    # println("[$(model.ticks)]($(a.id)) Routing Msg $(msg)")
    out_pkt_count = 0

    # if a.id == 1 && model.ticks > 80 && model.ticks < 90
    #     println("[$(model.ticks)]($(a.id)) Found this msg $(msg)")
    #     println("[$(model.ticks)]($(a.id)) Found this ports $(get_state(a).port_edge_list)")
    #     println("[$(model.ticks)]($(a.id)) Found this table $(get_state(a).flow_table)")
    # end

    flow = filter(fw -> 
                            ( fw.match_rule.src == string(msg.data.src) || fw.match_rule.src == "*" )
                            && (fw.match_rule.in_port == string(msg.in_port) || fw.match_rule.in_port == "*" )
                            && (fw.match_rule.dst == string(msg.data.dst) || fw.match_rule.dst == "*")
                            , get_flow_table(a))
    #println("[[$(model.ticks)]($(a.id)) flow==> $(flow)")
    if !isempty(flow)

        if flow[1].params[1][1] != 0
            ports = get_port_edge_list(a)
            dst_id = parse(Int64,filter(x->x[1]==flow[1].params[1],ports)[1][2][2:end])
            # if a.id == 10 && model.ticks in 80:1:90 
            #     println("[$(model.ticks)]($(a.id)) New destinatio is $(dst_id) ")
            # end
            dst = getindex(model,dst_id)
            #flow[1].action(model.ticks,msg,a,dst)
            forward(msg,a,dst,model)
        else
           # flow[1].action(model.ticks,msg,a)
           forward(msg,a,model)
        end
        # flow[1].action == OFS_Output ? out_pkt_count += 1 : out_pkt_count
        #@show flow
    else
        # if a.id == 10 && model.ticks in 80:1:90 
        #     println("[$(model.ticks)]($(a.id)) else New destinatio is $(get_state(a)) ")
        # end
        similar_requests = filter(r->(r[2],r[3]) == (msg.data.src,msg.data.dst) && (model.ticks - r[1]) < model.ofmsg_reattempt+1,a.requested_ctl)
        #println("[$(model.ticks)]($(a.id)) Similar requests $(similar_requests)")
        if isempty(similar_requests)
            controller = getindex(model,a.controller_id)
            #ask_controller(a,controller,msg)
            ctl_msg = OFMessage(next_ofmid!(model),model.ticks,a.id,msg.in_port,msg.data)
            send_msg!(a.controller_id,ctl_msg,model)
            push!(a.requested_ctl,(model.ticks,msg.data.src,msg.data.dst))
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
    #println("[$(model.ticks)] msgs: $(model.ntw_links_msgs)")
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
    println("[$(model.ticks)] Installing flow: $(sne.id) - $(msg.data)")
    push!(get_state(sne).flow_table,msg.data)
end

function in_packet_processing(a::AbstractAgent,model)
    in_pkt_count = 0
    out_pkt_count = 0
    for i in 1:a.params[:pkt_per_tick]
        #println("[$(model.ticks)]($(a.id)) -> processing $i")
        msg = is_ready(a) ? take_msg!(a) : break
        # if model.ticks < 3
        #     println("[$(model.ticks)]($(a.id)) Processing packet $(msg)")
        # end
        # in_pkt_count += 1
        # out_pkt_count += 
        process_msg!(a,msg,model)
    end

end

function process_msg!(sne::SimNE,msg::OFMessage,model)
    #println("[$(model.ticks)]($(sne.id)) -> processing $(msg.reason)")
    
    @match msg.reason begin
        Ofp_Protocol(1) =>  
                        begin
                            route_traffic!(sne,msg,model)
                        end
        Ofp_Protocol(3) => 
                        begin
                            install_flow!(msg,sne,model)       
                        end
                            
        _ => begin
            println("[$(model.ticks)]($(sne.id)) -> match default")
            end
    end
end


function pending_pkt_handler(a::SimNE,model)
    # if model.ticks in 80:1:90 && a.id == 10
    # end
    if !isempty(a.pending)
        println("[$(model.ticks)]($(a.id)) pending: $(length(a.pending))")
        for msg in a.pending
            put!(a.queue,msg)
         end
       empty_pending!(a)
    end
end




function throughput(bytes₋₁,bytes₀, τ₋₁,τ₀)
    Δτ = τ₀ - τ₋₁
    Δbytes = bytes₀ - bytes₋₁
    #println("Δbytes: $(bytes₀)  - $(bytes₋₁) / Δτ: $(Δτ)")
    return Δτ > 0 && Δbytes >= 0 ? Δbytes / Δτ : 0
end

function link_down!(eid::Int,dpn_id::Int,model)
    println("[$(model.ticks)]($(eid)) link down start")
    #remove from list of ports
    sne = getindex(model,eid)
    new_port_edge_list::Vector{Tuple{Int64,String}} = []
    dpn_port = -1
    for p in get_port_edge_list(sne)
        println("[$(model.ticks)]($(eid)) port found: $p")
        if p[2]!="s"*string(dpn_id)
            push!(new_port_edge_list,p)
        else
            dpn_port = p[1]
        end
    end
    println("[$(model.ticks)]($(eid)) link down mid")
    set_port_edge_list!(sne,new_port_edge_list)
    new_flow_table::Vector{Flow} = []
    for f in get_flow_table(sne)
        println("[$(model.ticks)]($(eid)) dpn_port: $dpn_port in $(f.params) - flow found: $(f)")
        if  ~(dpn_port in f.params)
            push!(new_flow_table,f)
        end    
    end
    set_flow_table!(sne,new_flow_table)
    println("[$(model.ticks)]($(eid)) new flow found: $(get_state(sne).flow_table)")
    #sne.state.flow_table = sne.state.flow_table - filter(f->dpn_port in f.params,sne.state.flow_table)[1]

    controller = getindex(model,sne.controller_id)
    trigger_of_event!(model.ticks,controller,dpn_id,EventOFPPortStatus,model)
    
end

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


function get_state(sme::SimNE)
    return last(sme.state_trj)
end

function init_state!(sme::SimNE)
    new_state = deepcopy(get_state(sme)) #!isnothing(get_state(sme)) ? deepcopy(get_state(sme)) : NetworkAssetState(sme.id)
    new_state.in_pkt = 0
    new_state.out_pkt = 0
    push!(sme.state_trj,new_state)
end
function init_state!(a::Agent)
end


function is_up(sne::SimNE)
    return get_state(sne).up
end

function is_up(a::Agent)
    return a.state.up
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
    return isready(a.state.queue)
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
function set_in_pkt!(a::Agent,in_pkt::Int)
    push!(a.state.in_pkt_trj,in_pkt)
end
function set_out_pkt!(a::Agent,out_pkt::Int)
    push!(a.state.out_pkt_trj,out_pkt)
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

function take_msg!(sne::SimNE)
    return take!(sne.queue)
end

function take_msg!(a::Agent)
    take!(a.state.queue)
end

function get_state_trj(sne::SimNE)::Vector{NetworkAssetState}
    return sne.state_trj
end
function get_state_trj(a::Agent)::Vector{NetworkAssetState}
    return []
end

function to_string(s::NetworkAssetState)
    sep = "; "
    return  string(s.ne_id) * 
            sep * string(s.up) *
            sep * string(s.port_edge_list) * 
            sep * string(s.in_pkt) *
            sep * string(s.out_pkt) *
            sep * string(s.flow_table)
end

function get_throughput(sne::SimNE)::Int
    return get_state(sne).in_pkt
end

function get_throughput(a::Agent)::Int
    return 0
end

function get_condition_ts(a::Agent)
    return zeros(1,1)
end

function get_condition_ts(sne::SimNE)
    return sne.condition_ts
end

function get_rul_ts(a::Agent)
    return [0]
end
function get_rul_ts(sne::SimNE)
    return sne.rul
end