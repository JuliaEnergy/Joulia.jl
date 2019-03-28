#############################################################################
# Joulia
# A Large-Scale Spatial Power System Model for Julia
# See https://github.com/JuliaEnergy/Joulia.jl
#############################################################################
# This file contains functions and structs for renewables

"""
    get_res_dict(res_df::DataFrame)

Load renewables.
"""
function get_res_dict(res_df::DataFrame)
	stacked_res = melt(res_df, :Node, variable_name=:Technology,
			           value_name=:Capacity)

	stacked_res[:id] = Symbol.(string.(stacked_res[:Technology]) .* "_"
		                      .* string.(stacked_res[:Node]))

	stacked_res = stacked_res[[:id, :Node, :Technology, :Capacity]]
	stacked_res = stacked_res[stacked_res[:Capacity] .> 0, :]
	res_dict = df_to_dict_with_id(stacked_res)

	return stacked_res[:id], res_dict
end

"""
    get_avail_dict(avail::Dict, res_dict)

Determine renewables availablity.
"""
function get_avail_dict(avail::Dict, res_dict)

	tech = res_dict[:Technology]
	node = res_dict[:Node]

	avail_dict = Dict{Symbol,Array{Float64, 1}}()
	for id in keys(tech)

		t = tech[id]
		n = Symbol(node[id])

		if haskey(avail, t)
			if Symbol(node[id]) in names(avail[t])
				avail_dict[id] = avail[t][n]
			else
				avail_dict[id] = fill(0.0, 8760)
			end
		else
			avail_dict[id] = avail[:global][t]
		end
	end

	return avail_dict
end

"""
    calc_infeed(cap_dict, avail_dict)

Determine renewables infeed.
"""
function calc_infeed(cap_dict, avail_dict)

	infeed = map(collect(keys(cap_dict))) do id
		cap = cap_dict[id]
		avail = avail_dict[id]

		id => avail * cap
	end |> Dict

	return infeed
end

mutable struct RenewableEnergySource
	id
	technology
	node
	infeed

	function RenewableEnergySource(res_df::DataFrame, avail::Dict)

		ids, res_dict = get_res_dict(res_df)
		avail_dict = get_avail_dict(avail,res_dict)
		infeed = calc_infeed(res_dict[:Capacity], avail_dict)

		return new(ids, res_dict[:Technology], res_dict[:Node], infeed)
	end
end
