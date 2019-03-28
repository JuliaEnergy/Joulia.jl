#############################################################################
# Joulia
# A Large-Scale Spatial Power System Model for Julia
# See https://github.com/JuliaEnergy/Joulia.jl
#############################################################################
# This file contains functions and structs for nodes

mutable struct Nodes
	id
	load
	exchange

	function Nodes(nodes_df::DataFrame, load_df::DataFrame, exchange_df::DataFrame)
		N = Symbol.(nodes_df[1])
		load_dict = df_to_dict(load_df)
		insert_default!(load_dict, fill(0.0, 8760), N)

		exchange_dict = df_to_dict(exchange_df)
		insert_default!(exchange_dict, fill(0.0, 8760), N)

		return new(N, load_dict, exchange_dict)
	end
end
