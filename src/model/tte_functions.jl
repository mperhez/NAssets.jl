"""
    Basic implementation of Weibull function with 2-parameters
    κ: shape parameter, κ > 0
    λ: scale parameter, λ > 0

"""
weibull_f(t,λ,κ) = t >= 0 ? (κ / λ) * ((t/ λ)^(κ - 1))*(ℯ^-(t/λ)^κ) : 0
#f2(params::Tuple,t) = params[1]*(1.0 - ℯ^(-(params[2])*(params[3] - (t%params[3]))))
