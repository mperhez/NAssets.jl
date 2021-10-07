function create_amsg!(sender,receiver,template,model)
    mid = next_amid!(model)
    msg = deepcopy(template)
    msg.id =mid
    msg.sid = sender
    msg.rid = receiver
    msg.ticks = model.ticks
    return msg
end

function send_msg!(receiver::Int64,msg::AGMessage,model)
    rag = getindex(model,receiver)
    #TODO get delay of link in ticks
    g = rag.ctl_graph
    lv = to_local_vertex(g,msg.sid,:aid)
    lva = to_local_vertex(g,rag.id,:aid) 
    #need index of nbs 
    nbs = neighbors(g,lva)
    i = first(indexin(lv,nbs))
    log_info(model.ticks,"From $(msg.sid) to  $(receiver) ==> $(msg) ~~~> $(size(rag.msgs_links,1)) --- $i")
    push!(rag.msgs_links[size(rag.msgs_links,1),i],msg)
    
end    

function send_to_nbs!(msg_template::AGMessage,a::Agent,model)::Array{Int64}
    cg = a.ctl_graph
    nbs = neighbors(cg,to_local_vertex(cg,a.id,:aid))
    gid_nbs = [cg[v,:aid] for v in nbs]
    gid_nbs = [gid for gid in gid_nbs if ~(gid in msg_template.body[:trace]) ]
    random_nbs = rand(Binomial(1,model.prob_random_walks),length(gid_nbs))
    random_nbs = [rnb for rnb in random_nbs .* gid_nbs if rnb > 0]
    msgs_sent::Array{Int64} = []
    log_info(model.ticks,a.id,"sending msg: $msg_template  to $(length(gid_nbs)) nbs: $(gid_nbs)")
    
    #disable msgs
    for nb in random_nbs
        if ~(nb in msg_template.body[:trace])
            body = deepcopy(msg_template.body)
            fw_msg = create_amsg!(a.id,nb,msg_template,model)
            send_msg!(nb,fw_msg,model)
            push!(msgs_sent,nb)
        end
    end

    log_info(model.ticks,a.id,"msgs sent: $(msgs_sent)")

    return msgs_sent

end

"""
    Processing for MATCH_PATH msg
"""
function do_match!(msg::AGMessage,a::Agent,model)
    log_info(model.ticks,a.id,"do_match! -> msg : $(msg)")
    
    query = msg.body[:query]
    new_path = msg.body[:path]# (tick,confidence,score,path)
    ces = get_controlled_assets(a.id,model)


    #elements this agent controls that are in path
    ces_in_path  = intersect(ces,last(new_path))
    
    #due diligence: check if path is invalid according to local Knowledge to avoid using/propagating rubbish.
    #however new check required when path query is done locally, as nodes
    # might have dropped since the time the path is received here. 
    invalid_path = is_invalid_path(new_path,ces_in_path,model)
    log_info(model.ticks,a.id,25,"invalidity check: $new_path ==> $invalid_path")
    if !invalid_path
        
        trace_bk = msg.body[:trace_bk]
        if length(trace_bk) > 1
            save_ctl_path!(a,reverse(trace_bk[1:end-1]))
        end
        # is this agent the original requester of path?
        if first(msg.body[:trace]) == a.id
            for ce in ces_in_path
                spath = last(new_path)[first(indexin(ce,last(new_path))):end]
                # log_info(model.ticks,a.id," procs match for $ce ===> spath: $(spath)")              
                #only deals with the exact path, e.g. [7,3,1], not [3,1].
                for i=1:1#length(spath)-1
                    epaths = []
                    if haskey(a.paths,(spath[i],last(spath)))
                        epaths = a.paths[(spath[i],last(spath))]

                        # log_info(model.ticks,a.id," BEFORE: epaths: $epaths")
                        push!(epaths,new_path)
                        # log_info(model.ticks,a.id," AFTER: epaths: $epaths")
                        
                        #sort by score, reverse = false
                        sort!(epaths,lt=isless_paths)
                        
                        #Make sure only model.max_cache_paths are stored
                        if length(epaths) > model.max_cache_paths
                            pop!(epaths)
                        end
                        
                        #TODO cases of older paths
                    else
                        epaths = [new_path]
                    end
                    a.paths[(spath[i],last(spath))] = epaths
                end
            end
            mark_reprocess_of_msg!(a,msg)
            log_info(model.ticks,a.id,"new path ENDING do_match: => $(a.paths) ++++++++===> $(a.pending)")
        else # This agent is not the original requester of the path
            #continue back propagation of msg
            msg.body[:trace_bk] = trace_bk[1:end-1]
            msg.rid = trace_bk[end-1]
            msg.sid = a.id
            send_msg!(trace_bk[end-1],msg,model)
        end
    else # the path is invalid
        #TODO  
    end
end

"""
    Prepare MATCH reply
"""
function do_match!(found_path::Tuple{Int64,Float64,Float64,Array{Int64}},msg::AGMessage,a::Agent,model)
    log_info(model.ticks,a.id,"*do_match! -> msg : $(msg) -> found: $(found_path)")
    query = msg.body[:query]
    trace = deepcopy(msg.body[:trace])
    append!(trace,a.id)
    trace_bk = deepcopy(trace)
    save_ctl_path!(a,reverse(trace_bk[1:end-1]))
    of_mid = msg.body[:of_mid]

    nbody = Dict(:of_mid=>of_mid,:query=>query,:trace=>trace,:trace_bk=>trace_bk[1:end-1],:path=>found_path)
    # log_info("[$(model.ticks)]{$(a.id)} =-do_match! -> receiver : $(trace_bk)")
    rpy_msg = AGMessage(next_amid!(model),model.ticks,a.id,trace_bk[end-1],MATCH_PATH,nbody)
    send_msg!(trace_bk[end-1],rpy_msg,model)
end


function process_msg!(a::Agent,msg::AGMessage,model)
    #log_info(model.ticks,a.id,18,"->processing $(msg)")
    
    # if model.ticks >= 41
        #  log_info(model.ticks,a.id,"--> is_up? $(get_state(a).up) -- > Processing AG msg: $msg ")
    # end

    @match msg.reason begin
        AG_Protocol(1) => 
                        #Query coming from other agent
                        do_query!(msg,a,model)
        
        AG_Protocol(2) =>  
                        do_match!(msg,a,model)                        
        
        AG_Protocol(3) =>  
                        do_new_nb!(msg,a,model)                        
        AG_Protocol(4) => 
                        do_ne_down(a,msg,model)
        
        # AG_Protocol(5) => 
        #                 do_update_local_graph!(a,msg,model)
                     
        _ => begin
                log_info("[$(model.ticks)]($(a.id)) -> match default!!")
            end
    end

    state = get_state(a)
    state.in_ag_msg+=1.0
    set_state!(a,state)
end


function do_new_nb!(msg::AGMessage,a::Agent,model)
    
    new_nbs = msg.body[:new_nbs]
    lg = a.ctl_graph
    ls = to_local_vertex(lg,a.id)
    for nb in new_nbs
        ld = to_local_vertex(lg,nb)
        if !has_edge(lg,ls,ld)
            add_edge!(lg,ls,ld)
        end
        if !has_edge(lg,a.id,nb)
            add_edge!(model.ctl_graph,a.id,nb)
        end
    end

end

 """
    It process a msg from a neighbor controller notifying a sne is down
 """
function do_ne_down(a::Agent,msg::AGMessage,model)
    remove_drop_sne!(a,msg.body[:dpid],model.ticks)
    if !isempty(msg.body[:ctl_trace])
        propagate_drop_sne!(a,msg.body[:dpid],msg.body[:ctl_trace],model)
    end
end 

"""
 It simulates a NE-controller link down
 In reality this is the routine that checks heartbeats 
 from controlled NEs.
"""
function controlled_sne_down!(a::Agent,dpn_id::Int,model)
    
    set_control_agent!(dpn_id,a.id*-1,model)
    # init_agent!(a,model)
    if isempty(get_live_snes(a,model))
        s = get_state(a)
        s.up = false
        set_state!(a,s)
    end

    lvb = to_local_vertex(a.base_ntw_graph,dpn_id)
    lvc = to_local_vertex(a.ntw_graph,dpn_id)
    a.base_ntw_graph = soft_remove_vertex(a.base_ntw_graph,lvb)
    a.ntw_graph = soft_remove_vertex(a.ntw_graph,lvc)

    #TODO implement when a control agent is down too
    # do_drop!(msg,a,model)
end

"""
 It simulates a NE-controller link up
 In reality this is the routine that checks heartbeats 
 from controlled NEs.
"""

function controlled_sne_up!(a::Agent,rjn_id::Int,live_nbs::Array{Int64},model::ABM)
    
    set_control_agent!(rjn_id,a.id,model)

    if !is_up(a)
        set_up!(a)
    end

    lvb = to_local_vertex(a.base_ntw_graph,rjn_id)
    lvc = to_local_vertex(a.ntw_graph,rjn_id)
    # add_vertex!(a.base_ntw_graph)
    # add_vertex!(a.ntw_graph)
    
    # set_prop!(a.base_ntw_graph,nv(a.base_ntw_graph),:eid,rjn_id)
    # set_prop!(a.ntw_graph,nv(a.ntw_graph),:eid,rjn_id)

    #just added vertices, last id
    # lvb = nv(a.base_ntw_graph)
    # lvc = nv(a.ntw_graph)

    a.base_ntw_graph = add_edges_gids(a.base_ntw_graph,lvb,live_nbs,:eid)
    a.ntw_graph = add_edges_gids(a.ntw_graph,lvc,live_nbs,:eid)
end

function get_state(a::Agent)::State
    return last(a.state_trj)
end
function set_state!(a::Agent,new_state::ControlAgentState)
    pop!(a.state_trj)
    push!(a.state_trj,new_state)
end

# function get_throughput(a::Agent,model)
#     a.msgs_in
# end

function get_state_trj(a::Agent)::Vector{State}
    return a.state_trj
end

function get_throughput_up(a::Agent,model)
    v_msg_in = [ s.in_ag_msg for s in a.state_trj ]

    # log_info("[$(model.ticks)] ($(a.id)) msg in  ==> $v_msg_in")
    v_up = [ s.up for s in a.state_trj ]
    v_tpt = get_throughput(v_msg_in,model.:interval_tpt)
    return [ v_up[i] ? v_tpt[i] : 0.0   for i=1:length(v_tpt)]
end


"""
 Check if path is invalid according to local knowledge. It does not mean is valid as this agent might not have all info to check validity.
 Only flags invalid if 100% sure.
 cnes:controlled nes by this agent (a)
"""
function is_invalid_path(path,cnes,model)
    result = false
    
    for cne in cnes
        if last(last(path)) != cne
            sne = getindex(model,cne)
            cne_i = first(indexin(cne,last(path)))
            ports_path = filter(p->p[2]=="s$(last(path)[cne_i+1])",get_port_edge_list(sne))
            result = isempty(ports_path) ? true : result
        end
    end
    return result
end


function save_ctl_path!(a::Agent,path::Array{Int64})
    already_in = false
    for p in a.ctl_paths
        if isless(path,p) || p == path#is path a strict subset or equal to p ?
            already_in = true
        end
    end
    if !already_in
        push!(a.ctl_paths,path)
    end
end

function propagate_drop_sne!(a::Agent,dpid::Int64,ctl_trace::Array{Int64},model)
    sid = a.id
    rid = first(ctl_trace)
    rem_path = length(ctl_trace) > 1 ? ctl_trace[2:end] : []
    dmsg = AGMessage(next_amid!(model),model.ticks,sid,rid,NE_DOWN,Dict(:dpid=>dpid,:ctl_trace=>rem_path))
    send_msg!(rid,dmsg,model)
end

"""
    It removes a dropped sne node from local paths and graph
"""
function remove_drop_sne!(a::Agent,dpid::Int64,drop_time::Int64)
    log_info(drop_time,a.id,"Existing paths: $(a.paths)")
    new_paths_dict = Dict()
    #delete pre-computed paths containing dropping node
    for path_k in keys(a.paths)
        v_paths = a.paths[path_k]
        new_paths = []
        for path in v_paths
            if !(dpid in last(path))
                push!(new_paths,path)
            end
        end
        if !isempty(new_paths)
            new_paths_dict[path_k] = new_paths 
        end
    end
    #update agent pre-computed paths
    a.paths = new_paths_dict


    #update graphs used by the control agent accordingly

   #is dpid in base ntw graph?
   lvb = to_local_vertex(a.base_ntw_graph,dpid)
   lvc = to_local_vertex(a.ntw_graph,dpid)

   log_info(drop_time,a.id," Removing dpid: $dpid from local base: $lvb --- local curr: $lvc")

   if lvb != 0
    a.base_ntw_graph = soft_remove_vertex(a.base_ntw_graph,lvb)
   end
   if lvc != 0
        a.ntw_graph = soft_remove_vertex(a.ntw_graph,lvc)
   end

   state = get_state(a)
   new_ap = Dict()
   for p in pairs(state.active_paths)
        if !(dpid in last(p))
          new_ap[first(p)] = last(p)
        end
   end

   state.active_paths = new_ap
   set_state!(a,state)
end

"""
It deals with prediction of unavailability (for a given time window) of a set of NEs under control.

"""
function do_update_flows_from_changes!(a::Agent,ntw_changes::Vector{Int64},model::ABM)
    #TODO operation for other than centralised agent
    if get_state(a).up

        log_info(model.ticks,a.id,"Pred_Down: ntw_changes!!!!!! $(ntw_changes)")

        joining_nodes = filter(x->x>0,ntw_changes)
        dropping_nodes = -1 * filter(x->x<0,ntw_changes)
        
        query_graph = deepcopy(a.ntw_graph)
        
        #add nodes
        for jng_id in joining_nodes
            query_graph = soft_remove_vertex(query_graph,jng_id)

            base_g = a.base_ntw_graph

            lv = to_local_vertex(base_g,jng_id)
            nbs = neighbors(base_g,lv)

            #TODO check if nbs is up?

            for nb_id in nbs
                add_edge!(query_graph,nb_id,jng_id)
                add_edge!(query_graph,jng_id,nb_id)
            end
        end

        #remove nodes
        for dpn_id in dropping_nodes
            query_graph = soft_remove_vertex(query_graph,dpn_id)
        end

        query_time = model.ticks
        
        #Only trigger queries if maintenance policy is not predictive (where routes/flows come from the optimisation algorithm)
        queries = a.maintenance.policy != PredictiveM  ? model.ntw_services : []

        for query in queries
            query_paths = Dict{Tuple{Int64,Int64},Array{Tuple{Int64,Float64,Float64,Array{Int64}}}}()

            path = do_query(query_time,query,query_graph,query_paths)
            
            if isempty(path)
                 log_info(model.ticks,a.id,"Not path found")
            #     # if !haskey(a.previous_queries,query)
            #     #     sent_to = query_nbs!(a,msg,jg,query,trace,model)
            #     #     a.previous_queries[query] = (model.ticks,sent_to)
            #     # end
            else
            #     # do_match!(path,msg,a,model)
            #     # clear_pending_query!(a,query)
                do_update_flows_from_path!(a,last(path),model)
            end

        end

        

    end
end

"""
Update flows of the snes controlled by the agent a and for the path given, 
"""
function do_update_flows_from_path!(a::Agent,path::Array{Int64,1},model::ABM)
    msg = OFMessage(-1, model.ticks,-1,0,OFPR_ADD_FLOW,[])
    
    install_flow!(a,path,model,msg)
    if length(path) > 1
        k = (first(path),last(path))
        # log_info(model.ticks,a.id,"key: $(k) ==> Ag Path: $spath")
        get_state(a).active_paths[k] = path
    end
end