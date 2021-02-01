#if has come from in_port and src, going to dst
mutable struct MRule 
    in_port::Int16
    src::Int64
    dst::Int64
end

mutable struct Flow 
    dpid::Int64 # datapath id
    match_rule::MRule
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

mutable struct NetworkAssetState <: State
    color::Symbol
    condition_trj::Array{Float64,2}
    in_pkt_trj::Vector{Int64}
    out_pkt_trj::Vector{Int64}
    queue::Channel{Tuple{Int16,DPacket}} # 
    flow_table::Vector{Flow}
end

function NetworkAssetState(condition_trj::Array{Float64,2})
    NetworkAssetState(:blue,condition_trj,Vector{Int64}(),Vector{Int64}(),Channel{Tuple{Int16,DPacket}}(1),Vector{Flow}())
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
    #controller_id::Int64
end
function SimNE(id,nid,state)
     SimNE(id,nid,:lightgray,0.3,state) #initialise SimNE with a placeholder in the controller
end


function forward(packet::DPacket,out_port::Int)
    @show packet out_port
end


function init_switch(a,model)
    #action to forward via port 1
    push!(a.state.flow_table,Flow(1,MRule(0,1,7),(pkt)->forward(pkt,1)))
end

function in_packet_processing(a::SimNE,model)
    in_pkt_count = 0
    out_pkt_count = 0
    for i in 1:model.pkt_per_tick
            qpkt = isready(a.state.queue) ? take!(a.state.queue) : break
            in_pkt_count += 1
            flow = filter(fw -> 
                            fw.match_rule.src == qpkt[2].src 
                            && fw.match_rule.in_port == qpkt[1] 
                            && fw.match_rule.dst == qpkt[2].dst
                            , a.state.flow_table)

            if !isempty(flow)
                flow[1].action(qpkt[2])
                out_pkt_count += 1
                @show flow
            end
    end
    #Just one update per tick regardless of pkts processed
    push!(a.state.in_pkt_trj,in_pkt_count)
    push!(a.state.out_pkt_trj,out_pkt_count)
end

function in_pkt_trj(a::AbstractAgent)
    return typeof(a) == SimNE ?  a.state.in_pkt_trj : [] 
end

function out_pkt_trj(a::AbstractAgent)
    return typeof(a) == SimNE ?  a.state.out_pkt_trj : []
end

# function controller_id(a::AbstractAgent)
#     return typeof(a) == SimNE ?  a.controller_id : 0
# end