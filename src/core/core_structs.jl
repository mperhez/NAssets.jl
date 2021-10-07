export State
"""
Self-organising agent
"""

abstract type SOAgent <: AbstractAgent end
abstract type SimAsset <: AbstractAgent end
abstract type State end
abstract type Packet end

abstract type MaintenanceType end
abstract type CorrectiveM <: MaintenanceType end
abstract type PreventiveM <: MaintenanceType end
abstract type PredictiveM <: MaintenanceType end


"""
    "Real" state of the asset
"""
mutable struct SimpleAssetState <: State
    color::Symbol
    condition_trj::Array{Float64,2}
    queue::Channel{Packet}
end

"""
    Agent's state, including observed state of 
    monitoring/controlling asset
"""
mutable struct SimpleAgState <: State
    color::Symbol
    condition_trj::Array{Float64,2}
    health_trj::Vector{Float64}
end



#fireflystate
mutable struct FFAgState <: State
    color::Symbol
    #T::Int64 # period to fire
    phase::Float64 #internal clock
    #inbox::Vector{Tuple{Int64,Float64}}
    inbox::Vector{Int64}
    blind::Int64
    maxN::Int64
    maxId::Int64
    condition_trj::Array{Float64,2}
    health_trj::Vector{Float64}
    #pulse_strategy::Symbol # FIFO, NEAR, MIXED
    #ϕ
end

"""
Supported Graphs
"""
@enum GraphModel begin
    CUSTOM=0
    CENTRALISED=1 # Only for control model
    RING=2
    COMPLETE=3
    GRID=4
    STAR=5
    BA_RANDOM=6 # Barrabasi_Albert
    WS_RANDOM=7 # watts_strogatz
    #SM_RANDOM_TOPO=8 # Stochastic Block Model
end

"""
Indicates the type of a flow within a path
"""
@enum Flow_Type begin
    f_SE = -2 # start and end
    f_S = -1 # start
    f_I = 0 # intermediate
    f_E = 1 # end
end

mutable struct ModelState <: State
    tick::Int
    links_load::Dict{Tuple{Int,Int},Int} # key: (src,dst), value: pkts
    active_flows::Vector{Tuple{Int,Int,Flow_Type}} # source,destination,type
end

@enum CTL_Event begin
    NetworkChange = 1 #Network change and reroute traffic
    TriggerDown = 2 #Trigger SNE down
    TriggerUp = 3 #Trigger SNE up
    Prediction = 4 #Update RUL predictions
    InstallFlows = 5 #Install flows already calculated, different from 1, which calculates flow based on network shortest path 
end


@enum Ofp_Event begin
    EventOFPPortStatusDown=1
    EventOFPPortStatusUp=2
end
@enum Ofp_Protocol begin
    OFPR_ACTION = 1
    OFPPR_DELETE = 2
    OFPR_ADD_FLOW = 3
    OFPR_NO_MATCH = 4
    OFPPR_JOIN = 5
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
    PREDICTED_NES_DOWN = 5
end

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
    id::Int
    ticks::Int
    sid::Int # sender id
    rid::Int # receiver id
    reason::AG_Protocol # Type of msg as per enum
    body::Dict{Symbol,Any}
end

mutable struct OFEvent
    msg::OFMessage    
end

mutable struct ControlEvent
    #When event is triggered
    time::Int64 
    #type of event
    type::CTL_Event
    #affected snes
    snes::Vector{Int64}
end

mutable struct Flow 
    dpid::Int64 # datapath id
    match_rule::MRule
    params::Vector{Any}
    action::OFS_Action # out_port, TODO: Check if other actions are needed
end


#State for which we need to save trajectory
mutable struct NetworkAssetState <: State
    ne_id::Int64
    up::Bool
    on_maintenance::Bool
    port_edge_list::Vector{Tuple{Int64,String}}
    in_pkt::Int64
    out_pkt::Int64
    drop_pkt::Int64
    flow_table::Vector{Flow}
    throughput_out::Dict{Int64,Float64} # link/port, value
    # throughput_in::Float64
    condition_ts::Array{Float64,1} # sensor data related to the condition of the asset
    rul::Float64 # "real" rul
    rul_e::Float64 # estimated rul
    maintenance_due::Int64 #
end


mutable struct ControlAgentState <: State
    a_id::Int64
    up::Bool
    active_paths::Dict{Tuple{Int64,Int64},Array{Int64}}
    in_ag_msg::Float64
    out_ag_msg::Float64
    in_of_msg::Float64
    out_of_msg::Float64
    q_queries::Float64
    path_scores::Array{Tuple{Int64,Int64,Float64}}
end

"""
 It represents data structure for maintenance related info
"""
mutable struct MaintenanceInfo
    #Current maintenance policy
    policy::Type{<:MaintenanceType} 
    # Expected useful life. Standard manufacturer time-to-failure
    eul::Int64 
    # When last job started
    job_start::Int64 
    # duration of current/next job
    duration::Int64
    # Cost of this type of maintenance
    cost::Float64
    #To trigger preventive maintenance ahead of breakdown
    threshold::Int64
    #How often rul predictions are run
    predictive_freq::Int64 
    # how many steps ahead the prediction is going to be for
    prediction_window::Int64
    deterioration_parameter::Float64
    #Duration of the corrective maintenance
    reference_duration::Int64 
    #Cost of the corrective maintenance
    reference_cost::Float64
end

"""
    Control Agent
"""
mutable struct Agent <: SOAgent
    id::Int64
    pos::Int64
    color::Symbol
    size::Float16
    pending::Vector{Tuple{Int64,OFMessage,Bool}} # <-time initially processed, ofmsg, reprocess in next tick?) reprocess only if a match is done
    # key(src,dst): value(tick_found,confidence,score,path)
    paths::Dict{Tuple{Int64,Int64},Array{Tuple{Int64,Float64,Float64,Array{Int64}}}} # pre-calculated paths for operation
    state_trj::Vector{ControlAgentState}
    msgs_links::Array{Vector{AGMessage},2}
    msgs_in::Vector{AGMessage}
    queue::Channel{OFMessage}
    previous_queries::Dict{Tuple{Int64,Int64},Tuple{Int64,Array{Int64}}} # (src,dst):(tick last queried,[nb ag queried])
    matched_queries::Dict{Tuple{Int64,Int64,Array{Int64}},Int64} 
    ctl_paths::Vector{Array{Int64}}
    #Maintenance info for all assets controlled by this agent
    maintenance::MaintenanceInfo
    rul_predictions::Matrix{Float64}
    events::Dict{Int64,Vector{ControlEvent}}
    ntw_graph::MetaGraph
    base_ntw_graph::MetaGraph
    ctl_graph::MetaGraph
    params::Dict{Symbol,Any}
end

function Agent(id::Int64,nid::Int64,maintenance::MaintenanceInfo,rul_predictions,params::Dict{Symbol,Any})::Agent
    s0 = ControlAgentState(id,true,Dict(),0,0,0,0,0,[])
    Agent(id,nid,:lightblue,0.1,Vector{Tuple{Int64,OFMessage,Bool}}(),Dict{Tuple{Int64,Int64},Array{Tuple{Int64,Float64,Array{Int64}}}}(),[s0],Array{Vector{AGMessage}}(undef,1,1),[],Channel{OFMessage}(500),Dict(),Dict(),[],maintenance,rul_predictions,Dict{Int64,Vector{ControlEvent}}(),MetaGraph(),MetaGraph(),MetaGraph(),params)
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
    requested_ctl::Dict{Tuple{Int64,Int64},Int64} # flows requested to controller: key{src,dst}:value{tick}
    state_trj::Vector{NetworkAssetState}
    one_way_time_pkt::Dict{Int64,Array{Int64}}
    controller_id::Int64
    #Individual Maitenance info for this asset
    maintenance::MaintenanceInfo 
    params::Dict{Symbol,Any}
end

function SimNE(id,nid,params,max_q,maintenance)
    SimNE(id,nid,0.3,Channel{OFMessage}(max_q),Vector{OFMessage}(),Dict{Tuple{Int64,Int64},Int64}(),[NetworkAssetState(id)],Dict(),-1,maintenance,params) #initialise SimNE with a placeholder in the controller
end


function ModelState(tick::Int)
    ModelState(tick,Dict(),[])
end


function SimpleAgState(condition_trj::Array{Float64,2}, health_trj::Vector{Float64})
    SimpleAgState(:red,condition_trj,health_trj)
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

"""
    Message with pair in data
"""
function OFMessage(id::Int64,ticks::Int,dpid::Int,ofp::Ofp_Protocol,data::Tuple{Int64,Int64})
    return OFMessage(id,ticks,dpid,-1,ofp,data)
end



function NetworkAssetState(ne_id::Int)
    NetworkAssetState(ne_id,true,false,Vector{Tuple{Int64,String}}(),0,0,0,Vector{Flow}(),Dict(),Array{Float64,1}(),0.0,0.0,0)
end




