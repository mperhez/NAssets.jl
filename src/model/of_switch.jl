mutable struct Flow 
    dpid::Int64 # datapath id
    match_rule::MRule
    action # out_port, TODO: Check if other actions are needed
end

#if has come from in_port and src, going to dst
mutable struct MRule 
    in_port::Int16
    src::Int64
    dst::Int64
end

mutable struct NetworkAssetState <: State
    color::Symbol
    condition_trj::Array{Float64,2}
    queue::Channel{Tuple{Int16,DPacket}} # 
    flow_table::Vector{Flow}
end


mutable struct DPacket <: Packet
    id::Int64
    src::Int64
    dst::Int64
    size::Int64 # in bytes
    time_sent::Int64
    hop_limit::Int64
end


function forward(packet::DPacket,out_port::Int)
    @show packet out_port
end


function init_switch(a,model)
    #action to forward via port 1
    push!(Flow(1,MRule(0,1,7),(pkt)->forward(pkt,1)),a.state.flow_table)
end

function in_packet_processing(a::SimNE,model)
    for i in 1:model.pkt_per_tick
        if !isempty(a.state.queue)
            qpkt = take!(a.state.queue)
            flow = filter(mr -> mr.src == qpkt[2].src && mr.in_port == qpkt[1] && mr.dst == qpkt[2].dst, a.state.flow_table)[1][2]
            flow.action(qpkt[2])
        end
    end
end