"""
It creates custom's backbone rich graph from given files

"""
function load_custom_backbone(csv_file_v,csv_file_e)
    #load nodes/vertices
    df_net = CSV.File(csv_file_v,dateformat="YYYY-mm-dd"
    #,skipto=2
    ) |> DataFrame
    # log_info("NAMES==> $(names(df_net))")
    sort!(df_net,["SAUID"])

    #load edges/links        
    df_net_links = CSV.File(csv_file_e,dateformat="YYYY-mm-dd"
    #,skipto=2
    ) |> DataFrame
    
    
    #Transformations on link data
    sort!(df_net_links,["From_SAU", "To_Sau"])
    df_net_links = filter(r->r.OSPF != "Removed",df_net_links)
    replace!(df_net_links.To_Sau, "SWNE/EX" => "SWNE_EX")
    replace!(df_net_links.To_Sau, "CLFAR-A" => "CLFAR")
    replace!(df_net_links.From_SAU, "EATR/NONE" => "EATRU")
    
    #Keeps only node that that corresponds to the links
    df_net = filter(r->r.SAUID in unique(df_net_links.To_Sau) || r.SAUID in unique(df_net_links.From_SAU),df_net)

    #Transformations of node data
     df_net = transform(df_net,[:Longitude,:Latitude] => ByRow((x,y) -> BNGPoint(lon=x,lat=y)) => :bng_point)
     df_net = transform(df_net,[:bng_point] => ByRow(x -> x.e) => :bng_lon)
     df_net = transform(df_net,[:bng_point] => ByRow(x -> x.n) => :bng_lat)

    
    #adjacency matrix
    adj_mx_net = zeros(length(unique(df_net.SAUID)),length(unique(df_net.SAUID)))
    nids = unique(df_net.SAUID)
    global i = 0
    for r in eachrow(df_net_links)
        global i+=1
        x = first(indexin([r.From_SAU],nids))
        y = first(indexin([r.To_Sau],nids))
        if !isnothing(x) && !isnothing(y)
            #   println("$i : $x ($(r.From_SAU)) - $y ($(r.To_Sau))")
            adj_mx_net[x,y] = 1.0
            adj_mx_net[y,x] = 1.0
        end
        
    end
    
    #create metapgraph
    g = MetaGraph(SimpleGraph(adj_mx_net))
    #set_indexing_prop!(g,:eid)
    vi = 0
    for r in eachrow(df_net)
        vi += 1
        set_props!(g,vi,Dict(:sauid=>r.SAUID,:bng_lon=>r.bng_lon,:bng_lat=>r.bng_lat))
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
    # log_info("[$(model.ticks)] - generating traffic")
    #fixed pkts
    q_pkts = 400 
    #random pkts
    #q_pkts = abs(round(0.1*model.pkt_per_tick*get_random(model.seed,model.ticks,Normal(1,0.05))))
    # q_pkts: A percentage of the model.pkt_per_tick so NEs are able to process traffic coming from different nodes (NEs)
    #src,dst = samplepair(1:nv(model.ntw_graph)) # can be replaced for random pair
    #pairs =[(1,7),(4,1),(5,14)] #[(9,5)] #[(4,5)]#
    pairs =[(1,7),(4,1),(5,14),(9,5),(12,8)]#

    for p in pairs
        src,dst = p
        sne_src = getindex(model,src)
        sne_dst = getindex(model,dst)
        if is_up(sne_src) && is_up(sne_dst)
            for i =1:q_pkts
                pkt = create_pkt(src,dst,model)
                # log_info(model.ticks, "Sending src: $src - dst: $dst -> q_pkts: $q_pkts ==> $pkt packets ")
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