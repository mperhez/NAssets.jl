#if has come from in_port and src, going to dst
mutable struct MRule 
    in_port::String
    src::String
    dst::String
end

mutable struct Flow 
    dpid::Int64 # datapath id
    match_rule::MRule
    params::Vector{Any}
    action # out_port, TODO: Check if other actions are needed
end

mutable struct DPacket <: Packet
    id::Int64
    src::Int64
    dst::Int64
    size::Int64 # in bytes
    time_sent::Int64
    hop_limit::Int64
end


mutable struct NEStatistics 
    tick::Int64
    ne_id::Int64
    throughput_in::Float64
    throughput_out::Float64
end

mutable struct NetworkAssetState <: State
    color::Symbol
    port_edge_list::Vector{Tuple{Int64,String}}
    condition_trj::Array{Float64,2}
    in_pkt_trj::Vector{Int64}
    out_pkt_trj::Vector{Int64}
    queue::Channel{Tuple{Int64,Int64,Int64,DPacket}} # 
    flow_table::Vector{Flow}
    pending::Vector{Tuple{Int64,Int64,Int64,DPacket}}
    requested_ctl::Vector{Tuple{Int64,Int64}} # flows requested to controller
end

function NetworkAssetState(condition_trj::Array{Float64,2})
    NetworkAssetState(:blue,Vector{Tuple{Int64,String}}(),condition_trj,Vector{Int64}(),Vector{Int64}(),Channel{Tuple{Int64,Int64,Int64,DPacket}}(1000),Vector{Flow}(),Vector{Tuple{Int64,Int64,Int64,DPacket}}(),Vector{Tuple{Int64,Int64}}())
end

mutable struct SDNCtlAgState <: State
    color::Symbol
    condition_trj::Array{Float64,2}
    health_trj::Vector{Float64}
    paths::Vector{Tuple{Int64,Int64,Array{Int64}}}
    in_pkt_trj::Vector{Int64}
    out_pkt_trj::Vector{Int64}
    queue::Channel{Tuple{Int64,Int64,Int64,DPacket}}
end

function SDNCtlAgState(condition_trj::Array{Float64,2}, health_trj::Vector{Float64})
    SDNCtlAgState(:red,condition_trj,health_trj,Vector{Tuple{Int64,Int64,Array{Int64}}}(),Vector{Int64}(),Vector{Int64}(),Channel{Tuple{Int64,Int64,Int64,DPacket}}(500))
end


"""
    Control Agent
"""
mutable struct Agent <: SOAgent
    id::Int64
    pos::Int64
    color::Symbol
    size::Float16
    state::SDNCtlAgState
    params::Dict{Symbol,Any}
end


function Agent(id,nid,state,params)
    Agent(id,nid,:lightblue,0.1,state,params)
end


"""
    Simulated Physical Network Element
"""
mutable struct SimNE <: SimAsset
    id::Int64
    pos::Int64
    color::Symbol
    size::Float16
    state::NetworkAssetState
    controller_id::Int64
    params::Dict{Symbol,Any}
    statistics::Vector{NEStatistics}
end
function SimNE(id,nid,state,params)
     SimNE(id,nid,:lightgray,0.3,state,-1,params,Vector{NEStatistics}()) #initialise SimNE with a placeholder in the controller
end

function ask_controller(sne::SimNE,a::Agent,msg::Tuple{Int64,Int64,Int64,DPacket})
    put!(a.state.queue,(msg[1],sne.id,msg[3],msg[4]))
    #TODO in_processing msgs of controller to install flow for uknown dst
end

function forward(ticks::Int64,msg::Tuple{Int64,Int64,Int64,DPacket},src::SimNE)
    #println("Packet $(msg[4].id) delivered")
end

function forward(ticks::Int64,msg::Tuple{Int64,Int64,Int64,DPacket},src::SimNE,dst::SimNE)
    in_ports = filter(p->p[2]=="s$(src.id)",dst.state.port_edge_list)
    #println("fw, from $(src.id) to $(dst.id) msg: $msg, in port will be $(in_ports)")
    # println("ports table: $(dst.state.port_edge_list)")
    # println("in ports: $in_ports")
    in_port = in_ports[1][1]
    put!(dst.state.queue,(ticks,src.id,in_port,msg[4]))
    # target = filter(p->p[1]==out_port,sne.state.port_edge_list)
    # if !isempty(target)
    #     println("The target is: $(target)")
    #     t_sne = getindex(model,parse(Int64,target[1][2][2]))
    #     in_port = filter(p->p[2]=="s$(sne.id)",t_sne.state.port_edge_list)
    #     put!(t_sne.state.queue,(sne.id,parse(Int64,in_port[1][2][2]),msg[3]))
    # end
    #@show msg out_port
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


function in_packet_processing(a::AbstractAgent,model)
    in_pkt_count = 0
    out_pkt_count = 0

    for i in 1:a.params[:pkt_per_tick]
        msg = isready(a.state.queue) ? take!(a.state.queue) : break
        # if model.ticks < 3
        #     println("[$(model.ticks)]($(a.id)) Processing packet $(msg)")
        # end
        in_pkt_count += 1
        out_pkt_count += process_msg(a,msg,model)
    end

    push!(a.state.in_pkt_trj,in_pkt_count)
    push!(a.state.out_pkt_trj,out_pkt_count)
end


function process_msg(a::Agent,msg::Tuple{Int64,Int64,Int64,DPacket},model)
    in_packet_handler(a,msg,model)
    return 0
end

function process_msg(a::SimNE,msg::Tuple{Int64,Int64,Int64,DPacket},model)
    out_pkt_count = 0

    # if a.id == 10 && model.ticks < 10
    #     println("[$(model.ticks)]($(a.id)) Found this msg $(msg)")
    #     println("[$(model.ticks)]($(a.id)) Found this ports $(a.state.port_edge_list)")
    #     println("[$(model.ticks)]($(a.id)) Found this table $(a.state.flow_table)")
    # end

    flow = filter(fw -> 
                            ( fw.match_rule.src == string(msg[4].src) || fw.match_rule.src == "*" )
                            && (fw.match_rule.in_port == string(msg[3]) || fw.match_rule.in_port == "*" )
                            && (fw.match_rule.dst == string(msg[4].dst) || fw.match_rule.dst == "*")
                            , a.state.flow_table)
    #println("[[$(model.ticks)]($(a.id)) flow==> $(flow)")
    if !isempty(flow)

        if flow[1].params[1][1] != 0
            dst_id = parse(Int64,filter(x->x[1]==flow[1].params[1],a.state.port_edge_list)[1][2][2:end])
            # println("New destinatio is $(dst_id) ")
            dst = getindex(model,dst_id)
            flow[1].action(model.ticks,msg,a,dst)
        else
            flow[1].action(model.ticks,msg,a)
        end
        flow[1].action == forward ? out_pkt_count += 1 : out_pkt_count
        #@show flow
    else

        similar_requests = filter(r->r == (msg[4].src,msg[4].dst),a.state.requested_ctl)

        if isempty(similar_requests)
            controller = getindex(model,a.controller_id)
            ask_controller(a,controller,msg)
            push!(a.state.requested_ctl,(msg[4].src,msg[4].dst))
        end
        #return package to queue as it does not know what to do with it
        push!(a.state.pending,msg)
    end
    return out_pkt_count
end

function pending_pkt_handler(a::AbstractAgent,model)
    @match a begin
        a::SimNE => begin
                        for msg in a.state.pending
                            put!(a.state.queue,msg)
                        end
                        empty!(a.state.pending)
                    end
        _ => nothing
    end
    
end

# function in_packet_processing(a::SimNE,model)
#     in_pkt_count = 0
#     out_pkt_count = 0
#     for i in 1:model.pkt_per_tick
#             qpkt = isready(a.state.queue) ? take!(a.state.queue) : break
#             in_pkt_count += 1
#             flow = filter(fw -> 
#                             fw.match_rule.src == qpkt[2].src 
#                             && fw.match_rule.in_port == qpkt[1] 
#                             && fw.match_rule.dst == qpkt[2].dst
#                             , a.state.flow_table)

#             if !isempty(flow)
#                 flow[1].action((a.id,qpkt...))
#                 out_pkt_count += 1
#                 @show flow
#             end
#     end
#     #Just one update per tick regardless of pkts processed
#     push!(a.state.in_pkt_trj,in_pkt_count)
#     push!(a.state.out_pkt_trj,out_pkt_count)
# end

function in_pkt_trj(a::AbstractAgent)
    return typeof(a) == SimNE ?  a.state.in_pkt_trj : [] 
end

function out_pkt_trj(a::AbstractAgent)
    return typeof(a) == SimNE ?  a.state.out_pkt_trj : []
end

# function controller_id(a::AbstractAgent)
#     return typeof(a) == SimNE ?  a.controller_id : 0
# end


function throughput(bytes₋₁,bytes₀, τ₋₁,τ₀)
    Δτ = τ₀ - τ₋₁
    Δbytes = bytes₀ - bytes₋₁
    println("Δbytes: $(bytes₀)  - $(bytes₋₁) / Δτ: $(Δτ)")
    return Δτ > 0 && Δbytes >= 0 ? Δbytes / Δτ : 0
end