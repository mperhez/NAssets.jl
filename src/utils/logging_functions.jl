"""
Log info msg
"""
function log_info(msg)
    #st = string(stacktrace()[2])
    #file_name = lstrip(st[last(findlast("at ",st)):end])
    #file_name = split(file_name,":")
    # file_name = lstrip(st[last(findlast("at ",st)):last(findlast(":",st))-1])
    #method_name = lstrip(st[1:last(findfirst("(",st))-1])
    # logger = get_logger(file_name * "|" * method_name)
    # @info(file_name * "]" * msg)
    #@info msg _module="" _file= replace(first(file_name),".jl"=>"") _line=parse(Int64,last(file_name))
    @info msg
end

"""
logs an info msg for tick and agent_id passed
"""
function log_info(t,aid,msg)
    # if t > 50
        @info "[$(t)]($(aid)) $msg"
    # end
end

"""
logs only for a given agent
"""
function log_info(t,aid,only_id,msg)
        if aid in only_id
            @info "[$(t)]($(aid)) $msg"
        end
end

"""
    logs an info msg for tick passed
"""
function log_info(t,msg)
    # if t > 50
        @info "[$(t)] $msg"
    # end
end

function log_debug(t,aid,msg)
    @debug "[$(t)]($(aid)) $msg"
end

function log_debug(t,msg)
    @debug "[$(t)] $msg"
end

function log_debug(msg)
    @debug msg
end