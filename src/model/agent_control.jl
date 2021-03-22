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
    println("[$(model.ticks)] From $(msg.sid) to  $(receiver) ==> $(msg)")
    push!(rag.msgs_links[size(rag.msgs_links,1),i],msg)
    
end    

function send_to_nbs!(msg_template::AGMessage,a::Agent,model)
    cg = a.params[:ctl_graph]
    nbs = neighbors(cg,to_local_vertex(cg,a.id,:aid))
    gid_nbs = [cg[v,:aid] for v in nbs]
    println("[$(model.ticks)]($(a.id)) sending to nbs: $(gid_nbs)")
    for nb in gid_nbs
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
    println("[$(model.ticks)]{$(a.id)} =+do_match! -> msg : $(msg), end ag => $(first(msg.body[:trace]))")
    new_path = msg.body[:path]
    ces = get_controlled_assets(a.id,model)
    ces_in_path  = intersect(ces,new_path)

    for ce in ces_in_path
        spath = new_path[first(indexin(ce,new_path)):end]

        for i=1:length(spath)-1
            push!(a.state.paths,(spath[i],last(spath),spath[i:end]))
            println("[$(model.ticks)]($(a.id)) do_match! -- path added: $(spath[i:end])")
        end
    end

    #continue back propagation of msg
    if first(msg.body[:trace]) != a.id
        trace_bk = msg.body[:trace_bk]
        msg.body[:trace_bk] = trace_bk[1:end-1]
        msg.rid = trace_bk[end-1]
        msg.sid = a.id
        send_msg!(trace_bk[end-1],msg,model)
    end
end

"""
    Prepare MATCH reply
"""
function do_match!(found_path::Vector{Int64},msg::AGMessage,a::Agent,model)
    println("[$(model.ticks)]{$(a.id)} =*do_match! -> msg : $(msg) -> found: $(found_path)")
    query = msg.body[:query]
    trace = msg.body[:trace]
    trace_bk = deepcopy(msg.body[:trace])
    of_mid = msg.body[:of_mid]

    nbody = Dict(:of_mid=>of_mid,:query=>query,:trace=>trace,:trace_bk=>trace_bk[1:end-1],:path=>found_path)
    println("[$(model.ticks)]{$(a.id)} =-do_match! -> receiver : $(trace_bk)")
    rpy_msg = AGMessage(next_amid!(model),model.ticks,a.id,trace_bk[end-1],MATCH_PATH,nbody)
    send_msg!(trace_bk[end-1],rpy_msg,model)
end


function process_msg!(a::Agent,msg::AGMessage,model)
    println("[$(model.ticks)]($(a.id)) -> processing $(msg.reason)")
    
    @match msg.reason begin
        AG_Protocol(1) =>  
                        do_query!(msg,a,model)
        
        AG_Protocol(2) =>  
                        do_match!(msg,a,model)                        
        _ => begin
                println("[$(model.ticks)]($(a.id)) -> match default")
            end
    end
end

"""
    Query by neighbor control agent after receiving AGMessage
"""
function do_query!(msg::AGMessage,a::Agent,model)
    println("[$(model.ticks)]($(a.id)) -> TODO Local search")
    
    query = msg.body[:query]
    trace = msg.body[:trace]
    of_mid = msg.body[:of_mid]
    # visited control ag
    push!(trace,a.id)
    msg_ntw_g = create_subgraph(msg.body[:ntw_edgel],msg.body[:ntw_equiv],:eid)
    a.params[:ntw_graph] = join_subgraphs(a.params[:ntw_graph],msg_ntw_g)
    ntw_edgel = [ e for e in edges(a.params[:ntw_graph]) if src(e) <  dst(e) ]
    ntw_equiv = [(v,a.params[:ntw_graph][v,:eid]) for v in vertices(a.params[:ntw_graph])]

    found = query_path(a.params[:ntw_graph],query)

    if !isempty(found.paths)
       #TODO consider case where multiple paths are found
       path = [a.params[:ntw_graph][v,:eid] for v in first(found.paths)]
       do_match!(path,msg,a,model)
    else # forward to neighbor controllers
        nbody = Dict(:query=>query,:trace=>trace,:ntw_edgel => ntw_edgel, :ntw_equiv=>ntw_equiv, :of_mid=>of_mid)
        msg_template = AGMessage(-1,model.ticks,a.id,-1,QUERY_PATH,nbody)
        send_to_nbs!(msg_template,a,model)
    end

end