function create_amsg!(sender,receiver,template,model)
    mid = next_amid!(model)
    msg = deepcopy(template)
    msg.mid =mid
    msg.sid = sender
    msg.rid = receiver
    msg.ticks = model.ticks
    return msg
end

function send_msg!(receiver::Int64,msg::AGMessage,model)
    rag = getindex(model,receiver)
    #TODO get delay of link in ticks
    g = rag.params[:ctl_graph]
    lv = to_local_vertex(g,msg.sid,:aid)
    lva = to_local_vertex(g,rag.id,:aid) 
    #need index of nbs 
    nbs = neighbors(g,lva)
    i = first(indexin(lv,nbs))
    # log_info("[$(model.ticks)] From $(msg.sid) to  $(receiver) ==> $(msg.reason) -> $(msg.body[:query])")
    push!(rag.msgs_links[size(rag.msgs_links,1),i],msg)
    
end    

function send_to_nbs!(msg_template::AGMessage,a::Agent,model)
    cg = a.params[:ctl_graph]
    nbs = neighbors(cg,to_local_vertex(cg,a.id,:aid))
    gid_nbs = [cg[v,:aid] for v in nbs]
    gid_nbs = [gid for gid in gid_nbs if ~(gid in msg_template.body[:trace]) ]
    random_nbs = rand(Binomial(1,model.prob_random_walks),length(gid_nbs))
    random_nbs = [rnb for rnb in random_nbs .* gid_nbs if rnb > 0]
    log_info(model.ticks,a.id,"sending msg: $msg_template  to $(length(gid_nbs)) nbs: $(gid_nbs)")
    # log_info("[$(model.ticks)]($(a.id)) sending to $(length(random_nbs)) random_nbs: $(random_nbs)")
    #log_info("[$(model.ticks)]($(a.id)) body: $(msg_template.body)")
    
    
    #disable msgs
    for nb in random_nbs
        if ~(nb in msg_template.body[:trace])
            body = deepcopy(msg_template.body)
            fw_msg = create_amsg!(a.id,nb,msg_template,model)
            send_msg!(nb,fw_msg,model)
        end
    end


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

    if !invalid_path
        # is this agent the original requester of path?
        trace_bk = msg.body[:trace_bk]
        if length(trace_bk) > 1
            save_ctl_path!(a,reverse(trace_bk[1:end-1]))
        end

        if first(msg.body[:trace]) == a.id
            for ce in ces_in_path
                spath = last(new_path)[first(indexin(ce,last(new_path))):end]              
                #only deals with the exact path, e.g. [7,3,1], not [3,1].
                for i=1:1#length(spath)-1
                    epaths = []
                    if haskey(a.paths,(spath[i],last(spath),last(query)))
                        epaths = a.paths[(spath[i],last(spath),last(query))]

                        log_info(model.ticks,a.id," BEFORE: epaths: $epaths")
                        push!(epaths,new_path)
                        log_info(model.ticks,a.id," AFTER: epaths: $epaths")
                        
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
            #reprocess of msg right after, to do local query with new path found
            new_pending = []
            for p in a.pending
                if last(p).id == msg.body[:of_mid]
                    push!(new_pending,(0,last(p)))
                else
                    push!(new_pending,p)
                end
            end
            a.pending = new_pending
            log_info(model.ticks,a.id,"new path ENDING do_match: => $(a.paths)")
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
    trace = msg.body[:trace]
    trace_bk = deepcopy(msg.body[:trace])
    save_ctl_path!(a,reverse(trace_bk[1:end-1]))
    of_mid = msg.body[:of_mid]

    nbody = Dict(:of_mid=>of_mid,:query=>query,:trace=>trace,:trace_bk=>trace_bk[1:end-1],:path=>found_path)
    # log_info("[$(model.ticks)]{$(a.id)} =-do_match! -> receiver : $(trace_bk)")
    rpy_msg = AGMessage(next_amid!(model),model.ticks,a.id,trace_bk[end-1],MATCH_PATH,nbody)
    send_msg!(trace_bk[end-1],rpy_msg,model)
end


function process_msg!(a::Agent,msg::AGMessage,model)
    #log_info(model.ticks,a.id,18,"->processing $(msg)")
    
    # if model.ticks == 83
    #     log_info(model.ticks,a.id,"--> is_up? $(get_state(a).up) -- > Processing AG msg: $msg ")
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
                     
        _ => begin
                log_info("[$(model.ticks)]($(a.id)) -> match default")
            end
    end

    state = get_state(a)
    state.in_ag_msg+=1.0
    set_state!(a,state)
end


function do_new_nb!(msg::AGMessage,a::Agent,model)
    
    new_nbs = msg.body[:new_nbs]
    lg = a.params[:ctl_graph]
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
    
    set_control_agent!(dpn_id,0,model)
    # init_agent!(a,model)
    if isempty(get_live_snes(a,model))
        s = get_state(a)
        s.up = false
        set_state!(a,s)
    end

    #TODO implement when a control agent is down too
    # do_drop!(msg,a,model)
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
    log_info("invalidity check: $path ==> $result")
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
   lvb = to_local_vertex(a.params[:base_ntw_graph],dpid)
   lvc = to_local_vertex(a.params[:ntw_graph],dpid)

   log_info(drop_time,a.id," Removing dpid: $dpid from local base: $lvb --- local curr: $lvc")

   if lvb != 0
    a.params[:base_ntw_graph] = soft_remove_vertex!(a.params[:base_ntw_graph],lvb)
   end
   if lvc != 0
        a.params[:ntw_graph] = soft_remove_vertex!(a.params[:ntw_graph],lvc)
   end



   
    # if lvb != 0 # node is not in local graph
        

    #     a.params[:last_cache_graph] = drop_time
    # end
end