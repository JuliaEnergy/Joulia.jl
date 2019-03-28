#############################################################################
# Joulia
# A Large-Scale Spatial Power System Model for Julia
# See https://github.com/JuliaEnergy/Joulia.jl
#############################################################################
# This file contains functions and structs for storages

mutable struct Storages
	id
	node
	technology
	power
	storage
	efficiency
	vc

	function Storages(df::DataFrame)
		d = df_to_dict_with_id(df)

		new(df[:id], d[:Node], d[:Technology], d[:Power], d[:Storage],
			d[:Efficiency], d[:VariableCost])
	end

end
