"""
    Basic implementation of Weibull function with 2-parameters
    κ: shape parameter, κ > 0
    λ: scale parameter, λ > 0
    t: current time (generally calculated with wb_t function)

"""
weibull_f(λ,κ,t) = t >= 0 ? (κ / λ) * ((t/ λ)^(κ - 1))*(ℯ^-(t/λ)^κ) : 0

"""
 Weibull scaling function
 ttf: expected time-to-failure
 γ: factor to tune max y (yₙ) value, e.g. for max y=1, with ttf =100,
 λ=0.5, κ=05 => γ=8

 TODO: check if γ might be calculated from ttf, λ and κ
"""
wb_t(γ,ttf,t) = (t%ttf)*γ/ttf

"""
 Basic logistic function
 http://reliawiki.org/index.php/Logistic

"""

log_f(b,k,t) = 1 / ( 1+ b*(ℯ^(-k*t)))

"""
Add random normally distributed  noise to a given value. 
Ensures that always:  0 ⋜  v + ϵ ⋜ y, for a random noise ϵ. 
    
    v: original value without noise
    ϵₛ: noise standard deviation
    ϵ₀: noise μ
    y:  max value the noised value can take
"""
function nnoised(v,ϵₛ,ϵ₀,y) 
    ϵ = 0
    #force only noised values within range
    while true
        ϵ = rand(Normal(ϵ₀,ϵₛ),1)[1]     
        (( v + ϵ ) > y || ( v + ϵ ) < 0)  || break
    end
    return v + ϵ 
end


"""
Add random normally distributed noise between 0 and y=1.
See nnoised(v,ϵₛ,ϵ₀,y).
"""

nnoised(v,ϵₛ) = nnoised(v,ϵₛ,0,1)

"""
    Calculates remaining ttf(time-to-failure) for a given expected ttf
    and current t
    ttf: expected time-to-failure
    t: current time

"""
exp_t(ttf,t) = ttf - (t%ttf)

"""
    Basic implementation of exponential deterioration function
    according to:
    
    * T. Wang, J. Yu, D. Siegel, and J. Lee, “2008 International Conference on Prognostics and Health Management, PHM2008,” 
      2008 Int. Conf. Progn. Heal. Manag. PHM 2008, 2008.
    
      * A. Salvador Palau, M. Dhada, and A. Parlikad, “Multi-Agent System architectures for collaborative prognostics,” 
      J. Intell. Manuf., 2019.

    a: max expected value of condition/health indicator (i.e. 1 if normalised)
    b: curvature parameter
    t: remaining time-to-failure (generally calculated with exp_t function)

"""
exp_f(a,b,t) = a*(1.0 - ℯ^(-(b)*t))


"""
    Scales weibull input t value considering shifting 
    for long term behaviour

    ttf: expected time-to-failure
    γ: factor to tune max y (yₙ) value, e.g. for max y=1, with ttf =100,
    λ=0.5, κ=05 => γ=8
    d: units to shift to the right (near TTF)
       
"""
wb_ts(γ,d,ttf,t) = ((t+d)%ttf)*γ/ttf

"""
    Scales exponential function considering shifting for long term
    behaviour.

    ttf: expected time-to-failure
    t: value to scale
    d: units to shift to the right (near TTF)
"""
exp_ts(d,ttf,t) = ttf - (t%ttf) -d

"""
    Scales logistic function considering shifting for long term
    behaviour.

    ttf: expected time-to-failure
    t: value to scale
    d: units to shift to the right (near TTF)
"""

log_ts(d,ttf,t) = (t+d)%ttf 

"""
Introduces a variation on the x value according to the phase (ϕ)
Used concretely for long-term TTF, we assume:
    * An asset has expected TTF (x)
    * After TTF the asset can be repaired or maintained and then will
      operate for a number of cycles/phases.
    * The current cycle/phase is given by ϕ
    * After every phase ϕ, the asset reduces its TTF by Δᵩ
"""
xᵩ(x,ϕ,Δᵩ) =  x * (1 -  (ϕ * Δᵩ))

"""
    Determines criteria for valid values to TTF for
    the exponential function.
    
        t₀: unused, defined to keep uniformity of function
            (TODO: check if this can be removed)
        t: value to evaluate
"""
exp_c(t₀,t) = t > 0

"""
    Determines criteria for valid values to TTF for
    the weibull function.
    
        t₀: initial value for the cycle/phase
        t: value to evaluate
"""

wb_c(t₀,t) = t >= t₀

"""
    Determines criteria for valid values to TTF for
    the logistics function.
    
        t₀: initial value for the cycle/phase
        t: value to evaluate
"""

log_c(t₀,t) = t >= t₀

"""
    Generates the time series until failure of an asset, given 
    the provided parameters:

    ttf: expected time-to-failure
    n: maximum number of cycles the asset can last
    Δᵩ: Delta of number of time steps that are reduced as the asset
        reaches a new cycle/phase
    ϵₛ: Standard deviation of the gaussian noise 
    f: function to generate values until ttf
    params: params required by the f
    tsf: function to scale t for the given function
    tse: extra parameter required by tsf
    f_c: function that defines criteria for a valid value in the time series.
"""

function values_f(ttf,n,Δᵩ,ϵₛ,f,params,tsf,tse_params,f_c)
    ϕ = 0
    t₀ = 0
    vs = []
    for i=0:n-1
        t = i
        ϕ₀ = ϕ
        ϕ = floor(t/ttf)
        rttf = xᵩ(ttf,ϕ,Δᵩ)
        diff = ttf - rttf 
        t = tsf(tse_params...,diff,ttf,t)
        t₀ = i == 1 ? t : ϕ > ϕ₀ ? t : t₀
        remt = ϕ > ϕ₀ ? (n - i) >= rttf && rttf > 0 : true
        if f_c(t₀,t) && remt
            #push!(vs_f,(t,t₀,ϕ,ϕ₀,rmng,rttf,(n - i),f(params...,t)))
            push!(vs,nnoised(f(params...,t),ϵₛ))
        end
    end
    l = length(vs) + 1
    for i=l:n
        push!(vs,0.0)
    end
    return vs
end


"""
 It illustrates how to use the other TTE functions
"""
function generate_ttf_series()
    n=1000
    ttf = 200
    λ = 1.0 #0.5
    γ = 6.0 #16
    k = 1.0 #0.5
    #p = plot(title="",legend=false)#,xlims=[0,1000])
    ϵₛ = 0.05
    a = 1.0
    b = 0.05
    Δᵩ = 0.05#0.009
    maxᵩ = 9

    vs = []
    funs = [
            (exp_f,(a,b),exp_ts,(),exp_c), 
            (weibull_f,(λ,k),wb_ts,(γ),wb_c),
            (log_f,(50,0.1),log_ts,(),log_c)
            ]
    
    for fs in funs
        push!(vs,values_f(ttf,n,Δᵩ,ϵₛ,fs...))
    end

    # for d=1:length(vs)
    #     p = plot!(p, vs[d])
    # end
    # for c=ttf:ttf:n
    #     p = plot!(p,[c,c],[0,1.0], c=:red, ls=:dash, w=2)
    # end
    # p
end

"""
    It adds downtime to a series
        ot: downtime (time steps)

"""

function add_downtime_to_series(ttf,ot,s_series)

    #println(" RECEIVED adding downtime ==>$(s_series)<==")

    # split s_series in phases/cycles of ttf
    phased_s = [s_series[i:min(i + ttf - 1, end)] for i in 1:ttf:length(s_series)]

    ph_ot = Vector{Float64}()

    for ph in phased_s
        if length(ph) < ttf
            push!(ph_ot,ph...)
        else
            push!(ph_ot,vcat(ph,zeros(Float64,ot))...)
        end
    end
    
    # println(" adding downtime $(size(ph_ot)) --- $(phased_s)")
    return ph_ot
end

"""
 It generates the sensor time series for a given asset
    ttf:time-to-failure
    ot: off-time
"""
function generate_sensor_series(ttf,n,Δᵩ,ϵₛ,ot,funs)
    vs = zeros(Float64,length(funs),n)
    #println("received generate sensor ==> $ot ")
    dim_dtvs = n + Int64(floor(n/ttf)) * ot  #n%ttf > 0 && n >= ttf ? n+ot+1 : n+ot



    dtvs = zeros(Float64,length(funs),dim_dtvs)

    for i=1:length(funs)
        vs[i,:] = values_f(ttf,n,Δᵩ,ϵₛ,funs[i]...)
    end


    for si=1:length(funs)
        s = vs[si,:]
        dtvs[si,:] = add_downtime_to_series(ttf,ot,s)
    end

    return dtvs
end

function generate_rul_series(ttf,Δᵩ,n,ot)
    rul = [  i%xᵩ(ttf,floor((i-1)/ttf),Δᵩ) == 0 ? 0 : round(xᵩ(ttf,floor((i-1)/ttf),Δᵩ) - i%xᵩ(ttf,floor((i-1)/ttf),Δᵩ)) for i=1:n ]
    #rul = [ xᵩ(ttf,floor(i/ttf),Δᵩ) - i%xᵩ(ttf,floor(i/ttf),Δᵩ) + 1 for i=1:n ]
    # print("PRE RUL: $(size(rul))")
    rul = add_downtime_to_series(ttf,ot,rul)
    # print("RUL: $(size(rul))")
    return rul
end

