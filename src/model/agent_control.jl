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
    # log_info("[$(model.ticks)]($(a.id)) sending to $(length(gid_nbs)) nbs: $(gid_nbs)")
    # log_info("[$(model.ticks)]($(a.id)) sending to $(length(random_nbs)) random_nbs: $(random_nbs)")
    #log_info("[$(model.ticks)]($(a.id)) body: $(msg_template.body)")
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
    # log_info(model.ticks,a.id,[20],"do_match! -> msg : $(msg), end ag => $(first(msg.body[:trace]))")
    # if msg.mid == 4786
    #     log_info(model.ticks,a.id,"is_up? $(get_state(a).up) --> do_match! -> msg : $(msg), end ag => $(first(msg.body[:trace]))")
    # end
    new_path = msg.body[:path]
    ces = get_controlled_assets(a.id,model)


    #elements this agent controls that are in path
    ces_in_path  = intersect(ces,last(new_path))
    
    #due diligence: check if path is invalid according to local Knowledge to avoid using/propagating rubbish. 
    invalid_path = is_invalid_path(new_path,ces_in_path,model)

    if !invalid_path
        # is this agent the original requester of path?
        if first(msg.body[:trace]) == a.id

            for ce in ces_in_path
                spath = last(new_path)[first(indexin(ce,last(new_path))):end]
        
                for i=1:1#length(spath)-1
                    epaths = []
                    if haskey(a.paths,(spath[i],last(spath)))
                        epaths = a.paths[(spath[i],last(spath))]
        
                        push!(epaths,new_path)
                        
                        #sort by score, reverse = false
                        sort!(epaths,lt=isless_paths)
        
                        if length(epaths) > model.max_cache_paths
                            pop!(epaths)
                        end
                        
                        #TODO cases of older paths
                    else
                        epaths = [new_path]
                    end
                    a.paths[(spath[i],last(spath))] = epaths
                
                    # log_info("[$(model.ticks)]($(a.id)) do_match! -- path added: $(spath[i:end])")
                end
            end




            #reprocess of msg right after
            new_pending = []
            for p in a.pending
                if last(p).id == msg.body[:of_mid]
                    push!(new_pending,(0,last(p)))
                else
                    push!(new_pending,p)
                end
            end
            a.pending = new_pending
            # log_info("[$(model.ticks)]($(a.id)) do_match! -- NEW_PENDING: $(a.pending)")
        else # This agent is not the original requester of the path
            #continue back propagation of msg
            trace_bk = msg.body[:trace_bk]
            msg.body[:trace_bk] = trace_bk[1:end-1]
            msg.rid = trace_bk[end-1]
            msg.sid = a.id
            send_msg!(trace_bk[end-1],msg,model)
        end
    end
end

"""
    Prepare MATCH reply
"""
function do_match!(found_path::Tuple{Int64,Float64,Array{Int64}},msg::AGMessage,a::Agent,model)
    #log_info(model.ticks,a.id,[22],"*do_match! -> msg : $(msg) -> found: $(found_path)")
    query = msg.body[:query]
    trace = msg.body[:trace]
    trace_bk = deepcopy(msg.body[:trace])
    of_mid = msg.body[:of_mid]

    nbody = Dict(:of_mid=>of_mid,:query=>query,:trace=>trace,:trace_bk=>trace_bk[1:end-1],:path=>found_path)
    # log_info("[$(model.ticks)]{$(a.id)} =-do_match! -> receiver : $(trace_bk)")
    rpy_msg = AGMessage(next_amid!(model),model.ticks,a.id,trace_bk[end-1],MATCH_PATH,nbody)
    send_msg!(trace_bk[end-1],rpy_msg,model)
end


function process_msg!(a::Agent,msg::AGMessage,model)
    #log_info(model.ticks,a.id,18,"->processing $(msg)")
    
    if !get_state(a).up
        log_info(model.ticks,a.id,"--> is_up? $(get_state(a).up) -- > Processing AG msg: $msg ")
    end

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

"""
    Query by neighbour control agent after receiving AGMessage
"""
function do_query!(msg::AGMessage,a::Agent,model)

    #define criteria for ignoring a msg from other agent
    ignore = false 
    if haskey(a.previous_queries,msg.body[:query]) 
        if model.ticks - a.previous_queries[msg.body[:query]] < model.query_cycle
            bdst = Binomial(1,model.prob_eq_queries_cycle)
            ignore = ~Bool(first(rand(bdst,1)))
        end
    end 

    if !ignore 

        # visited control ag
        trace = msg.body[:trace]
        push!(trace,a.id)

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
        
        query = msg.body[:query]
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

        a.previous_queries[msg.body[:query]] = model.ticks
        new_state = get_state(a)
        new_state.q_queries += 1.0
        set_state!(a,new_state)
        
        #TODO consider case where multiple paths are found
    end

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

# """
#     It processes the simulated AG msg sent by itself to 
#     indicate that one of its controlled NEs is down.
#     In a real setting this could come from a process where
#     the NE sends periodic heartbeats and when this is not received
#     the control agent send itself this msg.

# """
# function do_ne_down(a::Agent,msg::AGMessage,model)
    
# end

"""
 It simulates a NE-controller link down
 In reality this is the routine that checks heartbeats 
 from controlled NEs.
"""

function link_down!(a::Agent,dpn_id::Int,model)
    # ld_msg = AGMessage(next_amid!(model),model.ticks,a.id,a.id,NE_DOWN,Dict(:did => dpn_id))
    # send_msg!(agent.id,ld_msg,model)

    set_control_agent!(dpn_id,0,model)
    init_agent!(a,model)
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
    #log_info("invalidity check: $path")
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
