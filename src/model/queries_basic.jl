"""
Initial query by controller receiving OF message
"""
function do_query!(msg::OFMessage,a::Agent,model)
    # If asset's network does not have any edge, there is no way to transport packets 
    ignore = ne(a.params[:ntw_graph]) > 0 ? false : true
    path = []
    log_info(model.ticks, a.id, "querying local... $(msg)===> ignore: $ignore ====> paths: $(a.paths)")
    if !ignore
        # src (from this sne) to dst
        query = (msg.dpid,msg.data.dst)       
        query_time = model.ticks
        #existing precalc paths
        query_paths = a.paths
        #local graph to query
        query_graph = a.params[:ntw_graph]
        
        ####Start for benchmark#####
        sdir = data_dir 
        if model.benchmark 
            record_benchmark!(sdir,model.run_label,a.id,query_time,query,query_graph,query_paths) 
        end
        ####End for benchmark#####
        
        path = do_query(query_time,query,query_graph,query_paths)
        
        log_info(model.ticks,a.id,"query: $(query) ----path found: $path ----> in precalc paths: $(query_paths)")
        
        # For no centralised control topo
        if model.ctrl_model != GraphModel(1) # ¬ centralised
            
            #check path validity
            if !isempty(path)
                path = is_invalid_path(path,get_controlled_assets(a.id,model),model) ? [] : path
                clear_cache!(a,model)
            end

            #valid path not found?, need to send queries to nbs
            if isempty(path)
                ntw_edgel = [ e for e in edges(query_graph) if src(e) <  dst(e) ]
                ntw_equiv = [(v,query_graph[v,:eid]) for v in vertices(query_graph)]
                trace = [a.id]
                of_mid = msg.id 
                body = Dict(:query=>query,:trace=>trace,:ntw_edgel => ntw_edgel, :ntw_equiv=>ntw_equiv, :of_mid=>of_mid)
                msg_template = AGMessage(-1,model.ticks,a.id,-1,QUERY_PATH,body)
                send_to_nbs!(msg_template,a,model)
                #track query sent, if not previously tracked
                if !haskey(a.previous_queries,query)
                    a.previous_queries[query] = (model.ticks,[-1])
                end
            else #path found, need to remove potential pending queries
                
                new_previous_queries = Dict()
                for k in keys(a.previous_queries)
                    if k != query #exclude current query as path has been found
                        new_previous_queries[k] = a.previous_queries[k]
                    end
                end
                a.previous_queries = new_previous_queries
                #a.matched_queries[query] = model.ticks #TODO to remove
            end
        end
        #save state                
        new_state = get_state(a)
        ## +1 query
        new_state.q_queries += 1.0
        ## +score path       
        if !isempty(path) && msg.dpid != msg.data.dst 
            push!(new_state.path_scores,(msg.dpid,msg.data.dst,path[2]))
        end
        set_state!(a,new_state)
    end
    return isempty(path) ? [] : last(path)
end

"""
    Query by neighbour control agent after receiving AGMessage
"""
function do_query!(msg::AGMessage,a::Agent,model)
    log_info(model.ticks,a.id,"query msg is: $msg")
    #define criteria for ignoring a msg from other agent
    ignore = false 
    if haskey(a.previous_queries,msg.body[:query]) 
        if model.ticks - first(a.previous_queries[msg.body[:query]]) < model.query_cycle
            bdst = Binomial(1,model.prob_eq_queries_cycle)
            ignore = ~Bool(first(rand(bdst,1)))
        end
    end 

    if !ignore 

        # visited control ag
        trace = msg.body[:trace]
        push!(trace,a.id)
        query = msg.body[:query]

        if get_state(a).up
            # Aggregated information from other agents
            ## join graph received
            msg_ntw_g = create_subgraph(msg.body[:ntw_edgel],msg.body[:ntw_equiv],:eid)
            jg = join_subgraphs(a.params[:ntw_graph],msg_ntw_g)

            # Update Knowledge Base 
            # update local graph, however the problem it can grow too much
            # hence there is a periodic clear_cache to restore to original
            if model.clear_cache_graph_freq != 0
                a.params[:ntw_graph] = jg
            end
            
            
            query_time = model.ticks
            query_paths = a.paths
            query_graph = jg
            path = Dict()

            #path for benchmark recording
            sdir = data_dir * model.run_label
            if model.benchmark 
                record_benchmark!(sdir,model.run_label,a.id,query_time,query,query_graph,query_paths) 
            end

            #query
            # log_info(model.ticks,a.id,[20],"starting query ==> $(a.paths)")
            path = do_query(query_time,query,query_graph,query_paths)
            # log_info(model.ticks,a.id,[20],"ending query")        

            if isempty(path)
                ntw_edgel = [ e for e in edges(jg) if src(e) <  dst(e) ]
                ntw_equiv = [(v,jg[v,:eid]) for v in vertices(jg)]
                of_mid = msg.body[:of_mid]
                nbody = Dict(:query=>query,:trace=>trace,:ntw_edgel => ntw_edgel, :ntw_equiv=>ntw_equiv, :of_mid=>of_mid)
                msg_template = AGMessage(-1,model.ticks,a.id,-1,QUERY_PATH,nbody)
                send_to_nbs!(msg_template,a,model)
            else
                do_match!(path,msg,a,model)
            end
            squery = (msg.body[:query][1],msg.body[:query][2])
            a.previous_queries[query] = (model.ticks,[-1])
            new_state = get_state(a)
            new_state.q_queries += 1.0
            set_state!(a,new_state)
        
        #TODO consider case where multiple paths are found
        else
            of_mid = msg.body[:of_mid]
            nbody = Dict(:query=>query,:trace=>trace,:ntw_edgel => msg.body[:ntw_edgel], :ntw_equiv=>msg.body[:ntw_equiv], :of_mid=>of_mid)
            msg_template = AGMessage(-1,model.ticks,a.id,-1,QUERY_PATH,nbody)
            send_to_nbs!(msg_template,a,model)
        end
    end

end


"""
Query local calculated paths and local graph
"""
function do_query(time::Int64,query::Tuple{Int64,Int64},lg::MetaGraph,paths::Dict{Tuple{Int64,Int64},Array{Tuple{Int64,Float64,Float64,Array{Int64}}}})
    path = []
    cp_paths = []
    lg_paths = []
        
    #query pre-calculated (cache) paths
    cp_paths = haskey(paths,query) ? paths[query] : []

    log_info(time,"paths in precalc paths: $cp_paths")

    #query graph path regardless of cache, in case there is another
    # TODO: Do this only if cache path is too old
    path_state = query_paths(lg,query)
    log_info(time," paths in known graph: $(path_state.paths)")

    #reshape paths found local graph
    for lg_path in path_state.paths
        default_confidence = 0.5
        push!(lg_paths,(time,default_confidence,last(path_state.dists),last(path_state.paths)))
    end



        #assumes query_paths is sorted by tick,score
    lg_ps = !isempty(lg_paths) ? first(lg_paths)[3] : -1.0
    cp_ps = !isempty(cp_paths) ? first(cp_paths)[3] : -1.0

    path = @match (lg_ps,cp_ps) begin
        #no path
        (-1.0,-1.0)  => []
        #path in local graph
        (a::Float64,-1.0), if a > 0 end => first(lg_paths)
        #path in cache
        (-1.0,b::Float64), if b > 0 end => first(cp_paths)
        #path in cache paths and local graph
        (_::Float64,_::Float64) => first(cp_paths)[3] < first(lg_paths)[3] ? first(cp_paths) : first(lg_paths) ##lower is better
    end

    # log_info(time,"!do_query: $query -- graph nv: $(nv(lg))-- Path found: $path")
        
    return path
end

