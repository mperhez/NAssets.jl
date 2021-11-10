"""
It loads a graph from csv file containing the adjacency matrix of the graph. The file location and name is passed as argument (location/name.csv).
"""
function load_graph_from_csv(csv_adj_m::String)

    #adjacency matrix
    am = readdlm(csv_adj_m, ',', Int, '\n')
    
    #create metagraph
    g = MetaGraph(SimpleGraph(am))
    return g
end

"""
It annotates the graph with the coordinates obtained from the passed file name and location (location/name.csv). Annotating the graph is just adding attributes to the MetaGraph object passed.
"""
function add_geo_coordinates_to_graph!(g::MetaGraph,csv_coordinates::String)
    #coordinates
    df_net = CSV.File(csv_coordinates) |> DataFrame
    df_net = sort(df_net,[:id])
    #populate metagraph
    vi = 0
    for r in eachrow(df_net)
        vi += 1
        set_props!(g,vi,Dict(:lon=>r.lon,:lat=>r.lat))
    end
    return g
end


"""
Create a packet using arguments
"""
function create_pkt(src::Int64,dst::Int64,model)
    model.pkt_id += 1
    return DPacket(model.pkt_id,src,dst,model.:pkt_size,model.:ticks,100)
end

"""
Traffic generation per tick
"""
function generate_traffic!(model)
    #random pkts
    traffic_μ = first(model.traffic_dist_params)
    traffic_sd = last(model.traffic_dist_params)
    q_pkts = abs(round(model.traffic_proportion*model.pkt_per_tick*get_random(model.seed,model.ticks,Normal(traffic_μ,traffic_sd))))
    # q_pkts: A percentage of the model.pkt_per_tick so NEs are able to process traffic coming from different nodes (NEs)
    #src,dst = samplepair(1:nv(model.ntw_graph)) # can be replaced for random pair
    pairs = model.ntw_services
    ##**For testing only**
    #fixed pkts
    #q_pkts = 5 
    # pairs =[(5,14)]
    # println("$(model.seed)-->[$(model.ticks)] - generating traffic btwn $pairs")
    for p in pairs
        src,dst = p
        sne_src = getindex(model,src)
        sne_dst = getindex(model,dst)
        if is_up(sne_src) && is_up(sne_dst)
            for i =1:q_pkts
                pkt = create_pkt(src,dst,model)
                # if model.ticks >= 80 
                #     log_info(model.ticks,src,"Sending src: $src - dst: $dst -> q_pkts: $q_pkts ==> $pkt packets ")
                # end
                
                push_msg!(sne_src,OFMessage(next_ofmid!(model), model.ticks,src,0,pkt)) # always from port 0
            end
        end
    end

   # log_info("[$(model.ticks)] $(q_pkts) pkts generated")
end

"""
 Get a random number of packets to be processed by a sne on a given tick
 defined by the sequence passed (tick + sne_id)
"""
function get_random_packets_to_process(seed,sequence,max_ppt)
    #max pkts processed per tick
    #1/10 of ppt
    ppt_u = Int(round(max_ppt/10))   
    return get_random(seed,sequence,((max_ppt-(4*ppt_u)):ppt_u:max_ppt))
end


"""
Rejoin node to network according to 
- base_network
- current_network
- rejoining node id
"""
function rejoin_node!(model,rjn_id::Int64)
    
   base_g = model.base_ntw_graph 
   g = model.ntw_graph
   
   nbs = neighbors(base_g,rjn_id)
   lsnes = get_live_snes(model)
   #those neighbour nodes that are up
   sne_ids = intersect(nbs,lsnes)
   
   for sne_id in sne_ids
       add_edge!(g,sne_id,rjn_id)
       add_edge!(g,rjn_id,sne_id)
       sne = getindex(model,sne_id)     
       link_up!(sne,rjn_id,model)
   end

   rjn_ag = getindex(model,rjn_id)
   set_up!(rjn_ag)
   
   #re init ports
   nbs = all_neighbors(model.base_ntw_graph,get_address(rjn_ag.id,model.base_ntw_graph))
   
   
   push_ep_entry!(rjn_ag,(0,"h$(rjn_ag.id)")) # link to a host of the same id
   
   # creates entries for all nb from current ntw?
   for i in 1:size(nbs,1)
       if is_up(getindex(model,nbs[i]))
          push_ep_entry!(rjn_ag,(i,"s$(nbs[i])"))
       end
   end

   #it simulates control detects sne up:
   # when down, controller id is multiplied by -1, so we do the opposite now
   aid = abs(get_control_agent(rjn_id,model))
   a = getindex(model,aid)
   controlled_sne_up!(a,rjn_id,sne_ids,model)
end