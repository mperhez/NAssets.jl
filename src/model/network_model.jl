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