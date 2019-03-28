#############################################################################
# Joulia
# A Large-Scale Spatial Power System Model for Julia
# See https://github.com/JuliaEnergy/Joulia.jl
#############################################################################
# This file contains functions and structs for lines

zbase(voltage::Number) = (voltage *1E3)^2 / (500 * 1E6)

"""
    calc_pmax(df::DataFrame)

Calculate thermal limit from line data including TRM.
"""
function calc_pmax(df::DataFrame)
	L = df[1]
	voltage = map(zbase, df[:Voltage])
	reactance = Dict(zip(L, df[:Reactance] ./ df[:Circuits] ./ voltage))
	resistance = Dict(zip(L,  df[:Resistance] ./ df[:Circuits] ./ voltage))

	pmax = Dict(zip(L,df[:ThermalLimit] .* df[:Circuits] .* (1-(20/100)) ))
	return reactance, resistance, pmax
end

mutable struct Lines
    id
    from
    to
	reactance
	resistance
	pmax

    function Lines(df::DataFrame)
		df[:id] = Symbol.(df[:id])
		reactance, resistance, pmax = calc_pmax(df)
        dict = df_to_dict_with_id(df)

        self =  new(df[:id],
                   dict[:From],
                   dict[:To],
				   reactance,
				   resistance,
                   pmax)

        return self
    end
end

"""
    create_incidence(lines::Lines, nodes::Nodes)

Create the incidence matrix from 'lines' and 'nodes'.
"""
function create_incidence(lines::Lines, nodes::Nodes)
	incidence = zeros(Int, length(lines.id), length(nodes.id))
	for (i,l) in enumerate(lines.id)
	    incidence[i, findfirst(nodes.id .== Symbol(lines.from[l]))] = 1
	    incidence[i, findfirst(nodes.id .== Symbol(lines.to[l]))] = -1
	end
	return incidence
end

"""
    calc_h_b(lines::Lines, nodes::Nodes)

Calculate the H and B matrices from 'lines' and 'nodes'.
"""
function calc_h_b(lines::Lines, nodes::Nodes)

	incidence = create_incidence(lines, nodes)
	bvector = [lines.reactance[l] /
		(lines.reactance[l].^2 .+ lines.resistance[l].^2) for l in lines.id]
	h_matrix = bvector .* incidence
	b_matrix = h_matrix' *incidence

	h = Dict((l,n) => h_matrix[i,j]
		for (i,l) in enumerate(lines.id), (j,n) in enumerate(nodes.id))

	b = Dict((n,nn) => b_matrix[i,j]
		for (i,n) in enumerate(nodes.id), (j,nn) in enumerate(nodes.id))

	return h,b
end
