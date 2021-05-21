


function push_msg!(a::Agent,msg::OFMessage)
    put!(a.queue,msg)
end

function push_pending!(a::AbstractAgent,msg::OFMessage)
    push!(a.pending,msg)
end



function send_msg!(receiver::Int64,msg::OFMessage,model)
    ag = getindex(model,receiver)
    #TODO implement links and get delay of link in ticks
    queue = typeof(ag) == SimNE ? ag.queue : ag.queue
    # log_info("Sent to $receiver msg: $msg")
    put!(queue,msg)
end 



# function install_flows!(in_dpid,in_port_start,path,model)
#     # log_info(model.ticks,"install flow: $(in_dpid) - $(in_port_start) - $(path)")
#     if !isempty(path)
#         pairs = diag([j == i + 1 ? (path[3][i],path[3][j]) : nothing for i=1:size(path[3],1)-1, j=2:size(path[3],1)])
        
#         prev_eid = path[1]
#         for p in pairs
#             sne = getindex(model,p[1])
#             prev_sne = getindex(model,prev_eid)
#             port_dst = filter(x->x[2]=="s$(p[2])",get_port_edge_list(sne))[1]
#             out_port = port_dst[1]
#             in_port = p[1] == path[1] ? in_port_start : filter(x->x[2]=="s$(prev_eid)",get_port_edge_list(sne))[1][1]
#             r_src = path[1]
#             r_dst = path[2]
            
#             fw = Flow(sne.id,MRule(string(in_port),string(r_src),string(r_dst)),[out_port],OFS_Output)
#             #(ticks,pkt,sne_src,sne_dst)->forward(ticks,pkt,sne_src,sne_dst)
#             # log_info("[$(model.ticks)] {A} Installing flow: $(p[1]) - $(fw.match_rule)")
#             push_flow!(sne,fw)
#             prev_eid = sne.id
#         end
#     else
#         sne = getindex(model,in_dpid)
#         #TODO how to make the rule to be regardless of port in
#         fw =Flow(in_dpid,MRule("*","*",string(in_dpid)),[0],OFS_Output)
#         #(ticks,pkt,src_sne)->forward(ticks,pkt,src_sne)
#         # log_info("[$(model.ticks)]  {B} Installing flow to $(in_dpid): $(fw.match_rule)")
#         push_flow!(sne,fw)
#     end
# end

function install_flow!(a::Agent,path::Array{Int64,1},model::ABM,msg::OFMessage=nothing)
    # find which ones of path I am controlling
    es = get_controlled_assets(a.id,model)
    lpath = isempty(path) ? es : path 
    eois = intersect(es,lpath)
    lpath = [ v for v in lpath]
    # log_info(model.ticks,a.id,"{$(first(get_controlled_assets(a.id,model)))} install_flow! => path: $path -- es: $es -- eois: $eois - msg: -> $msg")
    for e in eois
         i = length(lpath) > 1 ? first(indexin(e,lpath)) : 1
         sne = getindex(model,e)
         i_prev = i > 1 ? i - 1 : i
         
         ports = get_port_edge_list(sne)
 
        #  log_info("[$(model.ticks)]{$(a.id)}($(sne.id)) - ports: $(ports) - i: $i - i_prev: $i_prev - e: $e -- lpath : $lpath")
         #Regardless of where the traffic comes
         r_src = "*" #string("h",first(lpath)) 
         r_dst = last(lpath)
         in_port = 0
         if i == 1
             #of_msg₀ = first(filter(ofm -> ofm.id == of_mid,a.pending))
            #  log_info("[$(model.ticks)]($(a.id)) Setting first entry port of path $lpath to $(msg)")
             in_port = msg.in_port
             #TODO of_msg remove from pending
         else
             #in_port = first(filter(p->parse(Int,p[2][2:end]) == lpath[i_prev],ports))
             in_port = first([ first(p) for p in ports if parse(Int,p[2][2:end]) == lpath[i_prev]])
            #  log_info("FIltered equal to: prev: $(lpath[i_prev]) in: $in_port")
         end
         out_port = 0
         
         if i < length(lpath)

            next_port = filter(p->parse(Int,p[2][2:end]) == lpath[i+1],ports)
            # log_info(model.ticks,a.id,"--> $next_port")
            out_port = first(first(next_port))
         end
 
         flow = Flow(  sne.id
                 ,MRule(string(in_port)
                 ,string(r_src)
                 ,string(r_dst))
                 ,[out_port]
                 ,OFS_Output)
         qid = msg.id
         install_msg = OFMessage(next_ofmid!(model), model.ticks,e,1,OFPR_ADD_FLOW,(flow=flow,qid=qid))
         send_msg!(e,install_msg,model)

         next_sne = out_port > 0 ? lpath[i+1] : lpath[i]
        #  log_info(model.ticks,a.id,"--> ($(sne.id),$(next_sne))")
    end
end

function process_msg!(a::Agent,msg::OFMessage,model)
    
    # log_info(model.ticks,a.id,18,"Processing msg: $msg")
    
    @match msg.reason begin
        Ofp_Protocol(1) =>  
                        begin
                            #log_info("[$(model.ticks)]($(a.id)) -> match one")
                            #previous = filter(x->x[1]==msg.id,a.of_started)
                            #if isempty(previous) || (model.ticks - last(first(previous))) < model.ofmsg_reattempt
                            
                            # open(data_dir*"exp_raw/"*"$(model.ticks)-test$(a.id).txt", "w") do io
                                #     #for i=1:nv(ntw_graph)
                                # b = @benchmark in_packet_handler($a,$msg,$model)
                                in_packet_handler(a,msg,model)
                                # show(io,MIME"text/plain"(),b)
                                #     #end
                            # end;
                            
                            #elseif  (model.ticks - last(first(previous))) < model.ofmsg_reattempt
                                #return package to queue as it does not know what to do with it
                            #    push!(a.pending,msg)
                           # end
                        
                        end
        Ofp_Protocol(2) => 
                            begin
                                #log_info("[$(model.ticks)]($(a.id)) -> match two")
                                port_delete_handler(a,msg,model)
                            end
        _ => begin
            log_info("[$(model.ticks)]($(a.id)) -> match default")
            end
    end

    state = get_state(a)
    state.in_of_msg+=1.0
    set_state!(a,state)
end

"""
msg: SimNE.id, in_port, DPacket
"""
function in_packet_handler(a::Agent,msg::OFMessage,model)

    path::Array{Int64,1} = []
    found = false
   
    if msg.dpid != dst
        path = do_query!(msg,a,model)
        found = isempty(path) ? false : true
    else
        found = true
    end
   
    
   
    if found 
        #install_flows!(msg.dpid,msg.in_port,path,model) 
        #log_info("[$(model.ticks)]($(a.id)) msg-> $(msg), path ==> $(path)")
        # log_info("[$(model.ticks)]($(a.id)) in pkt handler: path $path")
        install_flow!(a,path,model,msg)
    else
        #add to pending list only if has not been
        #started already (no reprocessing)
        started = filter(m->first(m) == msg.id,a.of_started)
        if isempty(started)
            push!(a.pending,(model.ofmsg_reattempt,msg))
        end
    end
    
    push!(a.of_started,(msg.id,model.ticks))
    
    # TODO
    # Need to implement asynchronous msgs
    # Need to control when msgs come and come because of being pushed to pending
    # If path is not found, it has to keep track of pending OFMessage if Any
    # and once any path is received it should install the flows for the path
    
end


# function do_query!(a::Agent,model,of_mid::Int64,query::Tuple{Int64,Int64})
#     lg = a.params[:ntw_graph]
#     found = query_path(lg,query)
#     path = []
    
#     previous = filter(x->x[1]==of_mid,a.of_started)
#     log_info("[$(model.ticks)]($(a.id)) do_query! => $(found) -- previous $previous")
#     if isempty(found.paths) &&  isempty(previous)# forward to neighbor controllers
       
#        ntw_edgel = [ e for e in edges(lg) if src(e) <  dst(e) ]
#        ntw_equiv = [(v,lg[v,:eid]) for v in vertices(lg)]
#        nbody = Dict(:query=>query,:trace=>[a.id],:ntw_edgel => ntw_edgel, :ntw_equiv=>ntw_equiv, :of_mid=>of_mid)
#        msg_template = AGMessage(-1,model.ticks,a.id,-1,QUERY_PATH,nbody)
#        send_to_nbs!(msg_template,a,model)
#     else
#         path = isempty(found.paths) ? [] : [a.params[:ntw_graph][v,:eid] for v in first(found.paths)]
#     end
#     return path#found.paths
# end

"""
    Initial query by controller receiving OF message
"""
function do_query!(msg::OFMessage,a::Agent,model)
    #do query
    query = (msg.dpid,msg.data.dst)
    query_time = model.ticks
    
    query_paths = a.paths
    query_graph = a.params[:ntw_graph]
    
    sdir = data_dir 
    
    if model.benchmark 
        record_benchmark!(sdir,model.run_label,a.id,query_time,query,query_graph,query_paths) 
    end
    
    path = do_query(query_time,query,query_graph,query_paths)
    
    # log_info(model.ticks,a.id,18,"path found: $path")

    if isempty(path)
        lg = a.params[:ntw_graph]
        ntw_edgel = [ e for e in edges(lg) if src(e) <  dst(e) ]
        ntw_equiv = [(v,lg[v,:eid]) for v in vertices(lg)]
        trace = [a.id]
        of_mid = msg.id 
        body = Dict(:query=>query,:trace=>trace,:ntw_edgel => ntw_edgel, :ntw_equiv=>ntw_equiv, :of_mid=>of_mid)
        msg_template = AGMessage(-1,model.ticks,a.id,-1,QUERY_PATH,body)
        send_to_nbs!(msg_template,a,model)
    end
    
    new_state = get_state(a)
    new_state.q_queries += 1.0
    if !isempty(path) && msg.dpid != msg.data.dst #&&  msg.data.src in first(get_controlled_assets(a.id,model))
        #body: $(msg.body[:query])
        #log_info("[$(model.ticks)]($(a.id))   in:  $(msg.data.src in first(get_controlled_assets(a.id,model))) -- ca: $(first(get_controlled_assets(a.id,model))) -- query: $(msg.dpid) - $(msg.data.dst)  -> score: $(path)") 
        push!(new_state.path_scores,(msg.dpid,msg.data.dst,path[2]))
    end
    set_state!(a,new_state)


    return isempty(path) ? [] : last(path)
end

"""
    Query local calculated paths and local graph
"""
function do_query(time::Int64,query::Tuple{Int64,Int64},lg::MetaGraph,paths::Dict{Tuple{Int64,Int64},Array{Tuple{Int64,Float64,Array{Int64}}}})
    path = []
    cp_path = []
    lg_path = []
    #query pre-calculated (cache) paths
    query_paths = haskey(paths,query) ? paths[query] : []
    
    #log_info(time,"Precalc Paths found: $paths")
    
    if !isempty(query_paths) 
        #assumes query_paths is sorted by tick,score
        cp_path = first(query_paths)
    end

    #query graph path regardless of cache, in case there is another
    path_state = query_path(lg,query)

    if !isempty(path_state.paths)
        lg_path = (time,last(path_state.dists),last(path_state.paths))
    end

    if !isempty(lg_path)
        path = lg_path
    elseif !isempty(cp_path)
        path = cp_path
    end
    

    # log_info("Path found: $path")
    
    
    return path
end

function pending_pkt_handler(a::Agent,model)
    # if model.ticks in 80:1:90 && a.id == 10
    # end
    new_pending = []
    if !isempty(a.pending)
        # log_info("[$(model.ticks)]($(a.id)) pending: $(length(a.pending))")
        for msgt in a.pending
            # log_info("[$(model.ticks)]($(a.id)) pending_msgt: $msgt")
            remaining = first(msgt) - 1  #msgt[1]: timeout
            if remaining <= 0 
                put!(a.queue,last(msgt)) #msgt[2]: msg
            else
                push!(new_pending,msgt)
            end
         end
         a.pending = new_pending
         
    end
end

function do_drop!(msg::OFMessage,a::Agent,model)
    lg = a.params[:ctl_graph]
    lv = to_local_vertex(lg,a.id)
    nbs = [ lg[nb,:aid] for nb in neighbors(lg,lv) ]

    for nb in nbs
        nbs_nb = setdiff(nbs,[nb])
        body = Dict(new_nbs=>nbs_nb,dpid=>msg.data)
        nb_msg = AGMessage(next_amid!(model),model.ticks,a.id,nb,NEW_NB,body)
        send_msg!(nb,nb_msg_model)
    end
    
    
    #remove edges from "actual" control graph
    soft_remove_vertex(model.ctl_graph,a.id)
    set_down!(a) 
end

function set_down!(a::Agent)
    state = get_state(a)
    state.up = false
    set_state!(a,state)
end
"""
    It processes OF msg sent by controlled NE  to
    remove a given port from its graph
    
"""
function port_delete_handler(a::Agent,msg::OFMessage,model)
    # init_agent!(a,model)
    new_paths_dict = Dict()
    dpid = msg.data 
    ces = get_controlled_assets(a.id,model)

    if dpid in ces
        do_drop!(msg,a,model)
    else
        # log_info("[$(model.ticks)]($(a.id)) Existing paths: $(get_state(a).paths)")
        
        #delete pre-computed paths containing dropping node
        for path_k in keys(a.paths)
            v_paths = a.paths[path_k]
            new_paths = []
            for path in v_paths
                if !(msg.data in last(path))
                    push!(new_paths,path)
                end
            end
            if !isempty(new_paths)
                new_paths_dict[path_k] = new_paths 
            end
        end
        a.paths = new_paths_dict
        #state = get_state(a)
        #OJO active paths
        #state.paths = new_paths_dict
        #set_state!(a,state)
        #delete dropping node from local graph
        lv = to_local_vertex(a.params[:ntw_graph],msg.data)
        a.params[:ntw_graph] = soft_remove_vertex(a.params[:ntw_graph],lv)
        # log_info("[$(model.ticks)]($(a.id)) New paths: $(get_state(a).paths)")
    end

end


