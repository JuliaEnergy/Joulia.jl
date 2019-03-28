#############################################################################
# Joulia
# A Large-Scale Spatial Power System Model for Julia
# See https://github.com/JuliaEnergy/Joulia.jl
#############################################################################
# This file contains utility functions

function df_to_dict_with_id(df::DataFrame)
    Dict(col[1] => Dict(zip(df[1], col[2])) for col in eachcol(df, true))
end

function df_to_dict(df::DataFrame)
    Dict(col[1] => col[2] for col in eachcol(df, true))
end

function dictzip(df::DataFrame, which::Tuple{Symbol, Symbol})
    return Dict(zip(df[which[1]], df[which[2]]))
end

function insert_default!(dict::Dict, default, keys)
	for k in keys
		haskey(dict, k) || (dict[k] = default)
	end
end

function jumpvar_to_df(jv::JuMP.JuMPArray;
		dim_names::Array{Symbol, 1} = Symbol[],
		dual::Bool=false)
	dim_arr = jv.indexsets
	dims = length(dim_arr)
	if dual
		arr = getdual(jv).innerArray
	else
		arr = getvalue(jv).innerArray
	end

	length(dim_names) == 0 && (dim_names = [Symbol("x$i") for i in 1:ndims(arr)])

	rows = []
	for ind in CartesianIndices(size(arr))
		row_ind = [dim_arr[dim][ind.I[dim]] for dim in 1:dims]
		push!(rows, (row_ind..., arr[ind]))
	end
	rows = vcat(rows...)

	k = [dim_names[i] => [row[i] for row in rows] for i in 1:length(dim_names)]
	kv = vcat(k..., :Value => [row[length(row)] for row in rows])

	return DataFrame(kv...)
end

get_variable_names(m::JuMP.Model) = [v.name for (k,v) in m.varData]

week_slices(sec_w::Int) = [1:sec_w-1, [t+167 > 8760 ? (t:8760) : (t:t+167) for t in sec_w:168:8760]...]
