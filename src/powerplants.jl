#############################################################################
# Joulia
# A Large-Scale Spatial Power System Model for Julia
# See https://github.com/JuliaEnergy/Joulia.jl
#############################################################################
# This file contains functions and structs for power plants

mutable struct PowerPlants
    id
    node
    fuel
    capacity
    mc

    function PowerPlants(pp::DataFrame; avail::DataFrame,
            prices::DataFrame)

        P = pp[1]
        pp_dict = df_to_dict_with_id(pp)
        avail_dict = df_to_dict(avail)
        prices_dict = df_to_dict(prices)

        return new(P, pp_dict[:Node],
                   pp_dict[:Fuel],
                   get_avail_powerplants(pp_dict, avail_dict),
                   calc_mc(pp_dict, prices_dict),
                   )
    end
end

"""
    calc_mc(pp_dict, prices_dict)

Calculate marginal costs from fuel price, efficiency, CO2 price and variable costs.
"""
function calc_mc(pp_dict, prices_dict)

    mc = Dict{String, Array{Float64, 1}}()

    for p in keys(pp_dict[:Fuel])
        f = Symbol(pp_dict[:Fuel][p])
        price = prices_dict[f]
        eff = pp_dict[:Efficiency][p]
        co_price = prices_dict[:CO2]
        emission = pp_dict[:Emission][p]
        vc = pp_dict[:VariableCost][p]

        mc[p] = price / eff + co_price * emission .+ vc
    end

    return mc
end

"""
    get_avail_powerplants(pp_dict, avail)

Determine power plant availability
"""
function get_avail_powerplants(pp_dict, avail)
    P = keys(pp_dict[:Fuel])
    avail_dict = Dict(p => avail[Symbol(pp_dict[:Fuel][p])] for p in P)
    return Dict(p => avail_dict[p] .* pp_dict[:Capacity][p] for p in P)
end
