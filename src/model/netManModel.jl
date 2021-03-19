"""
Basic initialization
"""
function initialize(args,user_props;grid_dims=(3,3),seed=0)
    pulses = []
    for i in 1:args[:q]
        push!(pulses,[])
    end

    # Global model props
    default_props = Dict(
        :ticks => 0,# # time unit
        :pkt_id => 0,
        :amsg_id =>0,
        :ofmsg_id=>0,
        :ofmsg_reattempt=>4,
        :pulses=>pulses,
        :Τ => args[:Τ], # Max time steps to fire
        :ΔΦ => args[:ΔΦ],
        :ntw_graph => args[:ntw_graph],
        :ctl_graph => args[:ctl_graph],
        :mapping_ctl_ntw => Dict{Int64,Int64}(), # mapping between (Ctl) Agent and SimNE
        :mapping_ntw_sne => Dict{Int64,Int64}(), #mapping btwn the underlying network and the corresponding simNE agent 
        :pkt_per_tick => 500, # How many packets are processsed per tick
        :ctrl_model => DISTRIBUTED, #CENTRALISED,
        :pkt_size => 1500,
        :freq => 30, # frequency of monitoring
        :N=>args[:N],
        # key(src,dst)=>value(time_left_at_link =>msg)
        :ntw_links_msgs=>Dict{Tuple{Int,Int},Vector{Vector{OFMessage}}}(),
        :ntw_links_delays =>Dict{Tuple{Int,Int},Int}(),
        :state_trj => Vector{ModelState}()
    )

    Random.seed!(seed)
    props = merge(default_props,user_props)
    #space = GridSpace(grid_dims, moore=true)
    space = GraphSpace(props[:ntw_graph])
    agent_types = Union{SimNE,Agent}
    model = ABM(agent_types, space; scheduler = random_activation, properties = props)
    init_model!(model)
    #create 
    create_agents!(model)
    model
end

"""
Simplest create agents
"""

function create_agents!(model)
    a_params = Dict(:pkt_per_tick=>model.pkt_per_tick)    
    # create SimNE
    for i in 1:nv(model.properties[:ntw_graph])
        #next_fire = rand(0:0.2:model.:Τ)
        id = nextid(model)
        # @show i
        a = add_agent_pos!(
                SimNE(id,i,a_params),model
            )
        
        set_prop!(model.ntw_graph, id, :eid, id )
        # create initial mapping btwn network and SimNE
        model.mapping_ntw_sne[i] = i   
    end
    set_indexing_prop!(model.ntw_graph, :eid)
    println(" Nodes CTL: $(nv(model.properties[:ctl_graph]))")
    #create control agents 1:1
    for i in 1:nv(model.properties[:ctl_graph])
        #next_fire = rand(0:0.2:model.:Τ)
        id = nextid(model)
        a = add_agent_pos!(
                Agent(id,i,a_params),model
            )
        set_props!(model.ctl_graph, i, Dict(:eid => i, :aid => id) )
        ##assign controller to SimNE
        if model.ctrl_model == CENTRALISED
            for j in 1:nv(model.properties[:ntw_graph])
                set_control_agent!(j,id,model)
            end
        else
            #one-to-one mapping 
            set_control_agent!(i,id,model)
        end
    end
    set_indexing_prop!(model.ctl_graph, :aid)
    

    init_agents!(model)
    # for i in 1:nv(model.properties[:ntw_graph])
    #     @show get_node_agents(i, model)
    # end

end



"""
    It advance model one step. Agents are progressed here to ensure that one action is perform in
    all agents before the next action is performed in all agents, instead of having one action
    executed in some agents and then some start with second action.
"""
function model_step!(model)
    init_step_state!(model)
    println("=====Tick $(model.ticks)======")
    for a in allagents(model)
        init_state!(a)
    end
    
    for e in edges(model.ntw_graph)
        ntw_link_step!((e.src,e.dst),model)
    end
    
    
    ctl_links_step!(model)
    
    # if model.ticks in 80:1:90
    #     println("[$(model.ticks)] - AFTER Processing $(get_state(getindex(model,10)))")
    # end    
    # if model.ticks == 1 
        generate_traffic!(model) 
    # end
    for a in allagents(model)
        do_agent_step!(a,model)
    end
    for a in allagents(model)
        pending_pkt_handler(a,model)
    end

    
    soft_drop_node(model)
end

"""
    Progress control agents one step.
"""
function agent_step!(a::Agent,model)
    #placeholder
end

"""
    Progress SimNE one step.
"""
function agent_step!(a::SimNE,model)
    #placeholder
end

"""
Simple run model function
"""
function run_model(n,args,properties; agent_data, model_data)
    model = initialize(args,properties;seed=123)

    
    # agent_shape(a::Agent) = :square
    agent_size(a) = 7
    # agent_size(a::Agent) = 7

    plot_scheduler = model.scheduler#by_type((SimNE,Agent), false)#

    plotkwargs = (
            # ac = agent_color, am = agent_shape, as = agent_size,
            # scheduler = plot_scheduler, aspect_ratio = 1
            # #Graph space properties
            # , method = :circular, node_size = 0.2
            # , 
            size = (1000, 600),
            showaxis = false
    )

    #p = plotabm(model; plotkwargs...)
    df = init_agent_dataframe(model,agent_data)
    df_m = init_model_dataframe(model,model_data)
    anim = @animate for i in 0:n
            p = plotabm_networks(model; plotkwargs...)
            title!(p, "step $(i)",position=(10,1))
            #annotate!((1,1,Plots.text("step $(i)", 11, :black, :center)))
            step!(model, agent_step!,model_step!)
            collect_agent_data!(df, model, agent_data, i)
            collect_model_data!(df_m, model, model_data, i)
        end
    println("PRINTING HERE")
    println("Space: $(model.space)")
    gif(anim, plots_dir*"animation.gif", fps = 5), df, df_m
end

function agent_color(a)
    #@show typeof(a)
    return :blue#a.color
end
        
    # agent_color(a::Agent) = :black#a.color
# function agent_shape(a)
#    #[println(c.shape) for c in a] 
   
#    return [c.shape for c in a] 
# end

function init_agents!(model)
    # for a in sort(allagents(model))
    #     init_agent(a,model)
    # end

    #force ordered start

    ids = [a.id for a in allagents(model)]
    
    for id in sort(ids)
        init_agent!(getindex(model,id),model)
    end
end

function init_agent!(a::Agent,model)

    println("Starting Agent $(a.id)")
    
    # calculate local subgraph for the underlying network

    nes = collect(get_controlled_assets(a.id,model))
    nbs = []

    for i=1:length(nes)
        # println("Agent $(a.id) controls node: $(get_address(nes[i],model.ntw_graph))")
        #subgraph
        push!(nbs,deepcopy(neighbors(model.ntw_graph,nes[i])))
        push!(nbs,[nes[i]])
    end

    nnbs = vcat(nbs...)
    sub_g = deepcopy(model.ntw_graph)
    vs = collect(vertices(sub_g))
    to_del = [v for v ∈ vs if v ∉ nnbs]
    
#     print("to delete: $(to_del)")
#     println("Agent $(a.id) : nnbs: $(nnbs)")


    # It seems unnecessary as removing vertex remove all edges
    # for v in collect(vertices(sub_g))
    #     for d in collect(vertices(sub_g))
    #         if d in to_del
    #             rem_edge!(sub_g,d,v)
    #             rem_edge!(sub_g,v,d)
    #         end
    #     end
    # end
    for d in to_del
        for v in collect(vertices(sub_g))
            if !has_prop(sub_g,v,:eid) || get_prop(sub_g,v,:eid) == d
                rem_vertex!(sub_g,v)
            end
        end
    end
    
    ctl_sub_g = deepcopy(model.ctl_graph)

    # create local subgraph for the control network

    ctl_v = first(filter(v->get_prop(ctl_sub_g,v,:aid) == a.id,1:nv(ctl_sub_g)))
    
    ctl_ns = collect(neighbors(ctl_sub_g,ctl_v))
    ctl_ns = [ctl_ns...,ctl_v]
    to_del = [v for v ∈ vs if v ∉ ctl_ns]
    
    for d in to_del
        for v in collect(vertices(ctl_sub_g))
            if !has_prop(ctl_sub_g,v,:eid) || get_prop(ctl_sub_g,v,:eid) == d
                rem_vertex!(ctl_sub_g,v)
            end
        end
    end

    a.params[:ntw_graph] = sub_g
    a.params[:ctl_graph] = ctl_sub_g
    a.params[:delay_ctl_link] = 1 # 1: no delay

    a.state.paths = label_path.(all_k_shortest_paths(sub_g))
    #a.params[:delay_ctl_link]
    

    #Init vector of msgs
    #a.msgs_links = Array{Vector{AGMessage}}(undef,a.params[:delay_ctl_link],degree(ctl_sub_g,to_local_vertex(ctl_sub_g,a.id,:aid)))
    #[ a.msgs_links[i,j] = Vector{AGMessage}() for i=1:size(a.msgs_links,1) for j=1:size(a.msgs_links,2)]
    a.msgs_links = init_array_vectors(AGMessage,a.params[:delay_ctl_link],degree(ctl_sub_g,to_local_vertex(ctl_sub_g,a.id,:aid)))

    #println(a.msgs_links)

end



function label_path(state)
    path = first(state.paths)
    return (first(path),last(path),path)
end




function init_agent!(a::SimNE,model)
    #print("Initialisation of SimNE agent $(a.id)")
    nbs = all_neighbors(model.ntw_graph,get_address(a.id,model.ntw_graph))
    
    push_ep_entry!(a,(0,"h$(a.id)")) # link to a host of the same id
    
    for i in 1:size(nbs,1)
        push_ep_entry!(a,(i,"s$(nbs[i])"))
    end

    #initialise condition: we generate entire time series to failure
    # TODO: Review
    #simulated sensor functions
    funs = [
        (exp_f,(1.0,0.05),exp_ts,(),exp_c), 
        (weibull_f,(1.0,1.0),wb_ts,(6.0),wb_c),
        (log_f,(50,0.1),log_ts,(),log_c)
        ]
    
    ttf = 100
    Δᵩ = 0.05
    downtime = 2 #time steps
    a.condition_ts = generate_sensor_series(ttf,model.N,Δᵩ,0.05,downtime,funs)
    vrul = generate_rul_series(ttf,Δᵩ,model.N,downtime)
    a.rul = vrul#reshape(vrul,length(vrul),1)
       
    init_switch(a,model)
end



"""
msg: SimNE.id, in_port, DPacket
"""
function in_packet_handler(a::Agent,msg::OFMessage,model)

    println("[$(model.ticks)]($(a.id)) msg-> $(msg)")
    dst = msg.data.dst
    src = msg.data.src
    path = []
    found = false
    
    

    if msg.dpid != dst
        paths = filter(p-> p[1] == src && p[2] == dst ,a.state.paths)
        path = !isempty(paths) ? first(paths) : do_query!(a,model,msg.id,(src,dst))
        found = isempty(path) ? false : true
    else
        found = true
    end

    if found 
        install_flows!(msg.dpid,msg.in_port,path,model) 
    else
        push!(a.pending,msg)
    end
    

    push!(a.of_started,(msg.id,model.ticks))
    # TODO
    # Need to implement asynchronous msgs
    # Need to control when msgs come and come because of being pushed to pending
    # If path is not found, it has to keep track of pending OFMessage if Any
    # and once any path is received it should install the flows for the path
    
end

# function install_flows(a::SimNE,paths,model)
#     (2, 1, [2, 10, 1])


# end

function install_flow!(msg::OFMessage, sne::SimNE,model)
    #ports = get_port_edge_list(sne,model)
    println("[$(model.ticks)] Installing flow: $(sne.id) - $(msg.data)")
    push!(get_state(sne).flow_table,msg.data)
end

function install_flow!(a::Agent,path,of_mid,model)
   # find which ones of path I am controlling
   es = get_controlled_assets(a.id,model)
   eois = intersect(es,path)
   
   for e in eois
        i = first(indexin(e,path))
        sne = getindex(model,e)
        i_prev = i > 1 ? i - 1 : i
        
        ports = get_port_edge_list(sne)

        println("[$(model.ticks)]{$(a.id)}($(sne.id)) - ports: $(ports)")
        r_src = first(path)
        r_dst = last(path)
        in_port = 0
        if i == 1
            of_msg₀ = first(filter(ofm -> ofm.id == of_mid,a.pending))
            in_port = of_msg₀.in_port
            #TODO of_msg remove from pending
        else
            in_port = first(filter(p->p[2][2:end] == path[i_prev],ports))
        end
        out_port = 0
        
        if i < length(path)
            out_port = first(filter(p->parse(Int,p[2][2:end]) == path[i+1],ports))[1]
        end

        flow = Flow(  sne.id
                ,MRule(string(in_port)
                ,string(r_src)
                ,string(r_dst))
                ,[out_port]
                ,OFS_Output)
        msg = OFMessage(next_ofmid!(model), model.ticks,e,1,OFPR_ADD_FLOW,flow)
        send_msg!(e,msg,model)
        
   end
   


   # for each one, get proceed as the other algo 


end

function install_flows!(in_dpid,in_port_start,path,model)
    println("install flow: $(in_dpid) - $(in_port_start) - $(path)")
    if !isempty(path)
        pairs = diag([j == i + 1 ? (path[3][i],path[3][j]) : nothing for i=1:size(path[3],1)-1, j=2:size(path[3],1)])
        
        prev_eid = path[1]
        for p in pairs
            sne = getindex(model,p[1])
            prev_sne = getindex(model,prev_eid)
            port_dst = filter(x->x[2]=="s$(p[2])",get_port_edge_list(sne))[1]
            out_port = port_dst[1]
            in_port = p[1] == path[1] ? in_port_start : filter(x->x[2]=="s$(prev_eid)",get_port_edge_list(sne))[1][1]
            r_src = path[1]
            r_dst = path[2]
            
            fw = Flow(sne.id,MRule(string(in_port),string(r_src),string(r_dst)),[out_port],OFS_Output)
            #(ticks,pkt,sne_src,sne_dst)->forward(ticks,pkt,sne_src,sne_dst)
            println("[$(model.ticks)] {A} Installing flow: $(p[1]) - $(fw.match_rule)")
            push_flow!(sne,fw)
            prev_eid = sne.id
        end
    else
        sne = getindex(model,in_dpid)
        #TODO how to make the rule to be regardless of port in
        fw =Flow(in_dpid,MRule("*","*",string(in_dpid)),[0],OFS_Output)
        #(ticks,pkt,src_sne)->forward(ticks,pkt,src_sne)
        println("[$(model.ticks)]  {B} Installing flow to $(in_dpid): $(fw.match_rule)")
        push_flow!(sne,fw)
    end
end

function create_pkt(src::Int64,dst::Int64,model)
    model.pkt_id += 1
    return DPacket(model.pkt_id,src,dst,1500,model.:ticks,100)
end

"""
    Next agent message's id
"""
function next_amid!(model)
    model.amsg_id += 1
    return model.amsg_id
end

"""
    Next Open Flow message id
"""
function next_ofmid!(model)
    model.ofmsg_id += 1
    return model.ofmsg_id
end


function generate_traffic!(model)
    q_pkts = abs(round(10rand(Normal(1,0.1))))
    #q_pkts = 100
    #src,dst = samplepair(1:nv(model.ntw_graph)) # can be replaced for random pair
    pairs = [(1,7)]#,(4,1),(9,5)] #[(9,5)]
    for p in pairs
        src,dst = p
        for i =1:q_pkts
            pkt = create_pkt(src,dst,model)
            sne = getindex(model,src)
            push_msg!(sne,OFMessage(next_ofmid!(model), model.ticks,src,1,pkt)) # always from port 0
        end
    end

   # println("[$(model.ticks)] $(q_pkts) pkts generated")
end

"""
    Initialise state of model for a given step
"""
function init_step_state!(m::ABM)
    m.ticks += 1
    new_state = ModelState(m.ticks)#deepcopy(get_state(m))
    #for e in edges(m.ntw_graph)
    #    new_state.links_load[(e.src,e.dst)] = 0
           # read from links according to delay
   # put msgs in destination nodes for those where delay is over

        #m.ntw_links[k] 
    #end
    push!(m.state_trj,new_state)
end

function get_state(m::ABM)
    return last(m.state_trj)
end


function init_model!(m::ABM)
    #all delays equal initially
    for e in edges(m.ntw_graph)
        #println("[$(m.ticks)] edge: $((e.src,e.dst))")
        m.ntw_links_delays[(e.src,e.dst)] = 1
    end

    #init link msgs
    # for e in edges(m.ntw_graph)
    #     link_queue = Vector{Vector{OFMessage}}()
    #     for q=1:m.ntw_links_delays[(e.src,e.dst)]
    #         push!(link_queue,Vector{OFMessage}())
    #     end
    #     m.ntw_links_msgs[(e.src,e.dst)] = link_queue
    # end

end

function init_link_msg!(l::Tuple{Int,Int},m::ABM)
    link_queue = Vector{Vector{OFMessage}}()
    for q=1:m.ntw_links_delays[l]
        push!(link_queue,Vector{OFMessage}())
    end
    m.ntw_links_msgs[l] = link_queue
end


function ntw_link_step!(l::Tuple{Int,Int},model)
    
    if haskey(model.ntw_links_msgs,l)
        
        msgs = model.ntw_links_msgs[l]
        # if model.ticks in 80:1:90 
        #     println("[$(model.ticks)] - $(l) -> msgs: $(length(first(msgs)))")
        # end
        to_deliver = first(msgs)
        in_pkt_count = 0
        if !isempty(to_deliver)
            if length(msgs) > 1
                msgs = msgs[begin+1:end]
                push!(msgs,Vector{OFMessage}())
            else
                msgs = [ Vector{OFMessage}() ]
            end
            
            model.ntw_links_msgs[l] = msgs

            for msg in to_deliver
                #Does it need to check address?, I don't think so
                dst = msg.dpid == l[1] ? getindex(model,l[2]) : getindex(model,l[1])
                put!(dst.queue,msg)
                in_pkt_count = get_state(dst).in_pkt + 1
                set_in_pkt!(dst,in_pkt_count)
            end
            #push!(model.state_trj,ModelState(model.ticks))
        end
    end
end

# function init_msgs_link!(msgs::Array{Array{AGMessage,1},1})
#     [ msgs[i] = Vector{AGMessage}() for i=1:length(a.msgs_links) ]
#     return msgs
# end

"""
    Initialize an array of dimensions d1 x d2 that contains vectors of type T
"""
function init_array_vectors(T,d1,d2)
    arr = d2 > 1 ? Array{Vector{T}}(undef,d1,d2) : Array{Vector{T}}(undef,d1)
    [ arr[i,j] = Vector{T}() for i=1:size(arr,1) for j=1:size(arr,2)]
    return arr
end

function ctl_links_step!(model)
    
    ctl_ags = filter(a->typeof(a) == Agent,Set(allagents(model)))
    #println(ctl_ags)
    ctl_link_step!.(ctl_ags)

end

function ctl_link_step!(a::Agent)
    #println("=== START Processing links of Ag: $(a.id) => $(a.msgs_links) -- $(a.msgs_in) ===")
    #Merge msgs from all senders to be processed
    a.msgs_in = vcat(a.msgs_links[1,:]...)
    a.msgs_links[1,:] = init_array_vectors(AGMessage,size(a.msgs_links,2),1)
    a.msgs_links = circshift(a.msgs_links,1)
    #println("=== END Processing links of Ag: $(a.id) => $(a.msgs_links) -- $(a.msgs_in) ===")
end
    
function get_state_trj(m::ABM)::Vector{ModelState}
    return m.state_trj
end
