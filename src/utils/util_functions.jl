function get_random(seed,sequence,distribution)
    Random.seed!(seed)
    return last(rand(distribution,sequence))
end
function get_random(seed,sequence,list)
    Random.seed!(seed)
    return last(rand(list,sequence))
end
function get_random(seed,sequence)
    return get_random(seed,sequence,Uniform())
end

"""
Helper function that checks if x value is in vector V
"""
is_in(x::Int64,V) = x in V
