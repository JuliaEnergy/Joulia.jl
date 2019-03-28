#############################################################################
# Joulia
# A Large-Scale Spatial Power System Model for Julia
# See https://github.com/JuliaEnergy/Joulia.jl
#############################################################################
# This file contains functions and structs for models

mutable struct JouliaModel
	parameters
	solver
	f_build_model
	results

	function JouliaModel(args...)
		self = new()
		self.parameters = Dict{Symbol, Dict}()
		self.f_build_model = create_model(args...)
		self.results = Dict{Symbol, DataFrame}()

		return self
	end
end

"""
	create_model(pp::PowerPlants,
		res::RenewableEnergySource,
		nodes::Nodes
		)

Create the model with 'pp', 'res', and 'nodes'.
"""
function create_model(pp::PowerPlants,
		res::RenewableEnergySource,
		nodes::Nodes
		)

	N = nodes.id
	P = pp.id
	RES = res.id

	mc = pp.mc
	exchange = nodes.exchange
	load = nodes.load
	input_gen = pp.capacity
	input_res = res.infeed

	function build_model(T::Array{Int, 1})

		m = Model()

	    @variables m begin
	        G[P,T] >= 0
	        G_RES[RES,T] >= 0
	        LOST_LOAD[T] >= 0
	        LOST_GENERATION[T] >= 0
	    end

		println("Set model objective")
		@objective(m, Min,
			sum(mc[p][t] * G[p,t] for p in P, t in T)
			+ 1000 * sum(LOST_LOAD[t] + LOST_GENERATION[t] for t in T)
		)

		println("Building constraints:")

	    prog = Progress(length(T), 0.2, "MarketClearing...   ", 50)

	    @constraintref MarketClearing[T]
	    for t=T
	    MarketClearing[t] = @constraint(m,

	        sum(G[p,t] for p in P)
	        + sum(G_RES[r,t] for r in RES)
	        - LOST_GENERATION[t]

	        ==

	        sum(load[n][t] for n in N)
	        - sum(exchange[n][t] for n in N)
	        - LOST_LOAD[t] );

	    next!(prog)
	    end
	    JuMP.registercon(m, :MarketClearing, MarketClearing)

	    @constraintref GenerationRestriction[P,T]
	    prog = Progress(length(P)*length(T), 0.2, "Max generation...   ", 50)

	    for p=P, t=T
	    GenerationRestriction[p,t] = @constraint(m,

	        G[p,t] <= input_gen[p][t] );

	    next!(prog)
	    end

	    @constraintref ResRestriction[RES,T]
	    prog = Progress(length(RES)*length(T), 0.2, "Renewable infeed... ", 50)

	    for r=RES, t=T
	    ResRestriction[r,t] = @constraint(m,

	        G_RES[r,t] <= input_res[r][t] );

	    next!(prog)

	    end

		return m
	end # end of build model

	return build_model
end # end function `create_model`

"""
	create_model(pp::PowerPlants,
		res::RenewableEnergySource,
		storages::Storages,
		nodes::Nodes
		)

Create the model with 'pp', 'res', 'storages', and 'nodes'.
"""
function create_model(
	pp::PowerPlants,
	res::RenewableEnergySource,
	storages::Storages,
	nodes::Nodes
	)

	N = nodes.id
	P = pp.id
	S = storages.id
	RES = res.id

	mc = pp.mc
	exchange = nodes.exchange
	load = nodes.load
	input_gen = pp.capacity
	input_res = res.infeed
	sto_capacity = storages.storage
	sto_power = storages.power
	eff = storages.efficiency

	function build_model(T::Array{Int, 1})

		m = Model()

	    @variables m begin
	        G[P,T] >= 0
	        G_RES[RES,T] >= 0
	        G_STOR[S,T] >= 0
	        W_STOR[S,T] >= 0
	        STOR_LEVEL[S,T] >= 0
	        LOST_LOAD[T] >= 0
	        LOST_GENERATION[T] >= 0
	    end

	    for s in S
	        JuMP.fix(STOR_LEVEL[s,T[1]], 0)
	        JuMP.fix(G_STOR[s,T[1]], 0)
	        JuMP.fix(W_STOR[s,T[1]], 0)
	    end

		println("Set model objective")
		@objective(m, Min,
			sum(mc[p][t] * G[p,t] for p in P, t in T)
			+ 1000 * sum(LOST_LOAD[t] + LOST_GENERATION[t] for t in T)
		)

		println("Building constraints:")

	    prog = Progress(length(T), 0.2, "MarketClearing...   ", 50)

	    @constraintref MarketClearing[T]
	    for t=T
	    MarketClearing[t] = @constraint(m,

	        sum(G[p,t] for p in P)
	        + sum(G_RES[r,t] for r in RES)
	        + sum(G_STOR[s,t] for s in S)
	        - LOST_GENERATION[t]

	        ==

	        sum(load[n][t] for n in N)
	        - sum(exchange[n][t] for n in N)
	        + sum(W_STOR[s,t] for s in S)
	        - LOST_LOAD[t] );

	    next!(prog)
	    end
	    JuMP.registercon(m, :MarketClearing, MarketClearing)

	    @constraintref GenerationRestriction[P,T]
	    prog = Progress(length(P)*length(T), 0.2, "Max generation...   ", 50)

	    for p=P, t=T
	    GenerationRestriction[p,t] = @constraint(m,

	        G[p,t] <= input_gen[p][t] );

	    next!(prog)
	    end

	    @constraintref ResRestriction[RES,T]
	    prog = Progress(length(RES)*length(T), 0.2, "Renewable infeed... ", 50)

	    for r=RES, t=T
	    ResRestriction[r,t] = @constraint(m,

	        G_RES[r,t] <= input_res[r][t] );

	    next!(prog)

	    end

		@constraintref StorageCapGeneration[S,T]
	    @constraintref StorageCapWithdraw[S,T]
	    @constraintref StorageCapLevel[S,T]
	    @constraintref StorageBalance[S,T]
	    prog = Progress(length(S)*length(T), 0.2, "Storages...         ", 50)

	    for s=S, t=T
	    StorageCapGeneration[s,t] = @constraint(m,

	        G_STOR[s,t] <= sto_power[s] );

	    StorageCapWithdraw[s,t] = @constraint(m,

	        W_STOR[s,t] <= sto_power[s] );

	    StorageCapLevel[s,t] = @constraint(m,

	        STOR_LEVEL[s,t] <= sto_capacity[s] );

	    if t != T[end]
	    StorageBalance[s,t] = @constraint(m,

	        STOR_LEVEL[s,t+1]
	        ==
	        STOR_LEVEL[s,t] + (eff[s] * W_STOR[s,t]) - G_STOR[s,t] );

	    elseif t == T[end]
	    StorageBalance[s,t] = @constraint(m,

	        STOR_LEVEL[s,T[1]]
	        ==
	        STOR_LEVEL[s,t] + (eff[s] * W_STOR[s,t]) - G_STOR[s,t] );

	    end #end of if statement
	    next!(prog)
	    end

		return m
	end # end of build model

	return build_model
end # end function `create_model`

"""
	create_model(pp::PowerPlants,
		res::RenewableEnergySource,
		storages::Storages,
		nodes::Nodes,
		lines::Lines
		)

Create the model with 'pp', 'res', 'storages', 'nodes', and 'lines'.
"""
function create_model(pp::PowerPlants,
		res::RenewableEnergySource,
		storages::Storages,
		nodes::Nodes,
		lines::Lines
		)

	N = nodes.id
	P = pp.id
	S = storages.id
	L = lines.id
	RES = res.id

	mc = pp.mc
	map_n_p = Dict(map(n-> n=> [p for p in P if Symbol(pp.node[p]) == n], N))
	map_n_s = Dict(map(n-> n=> [s for s in S if Symbol(storages.node[s]) == n], N))
	map_n_res = Dict(map(n-> n=> [r for r in RES if Symbol(res.node[r]) == n], N))
	h,b = calc_h_b(lines, nodes)
	p_max = lines.pmax
	exchange = nodes.exchange
	load = nodes.load
	input_gen = pp.capacity
	input_res = res.infeed
	sto_capacity = storages.storage
	sto_power = storages.power
	eff = storages.efficiency

	function build_model(T::Array{Int, 1})

		m = Model()

	    @variables m begin
	        G[P,T] >= 0
	        G_RES[RES,T] >= 0
	        G_STOR[S,T] >= 0
	        W_STOR[S,T] >= 0
	        STOR_LEVEL[S,T] >= 0
	        LINEFLOW[L,T]
	        DELTA[N,T]
	        LOST_LOAD[N,T] >= 0
	        LOST_GENERATION[N,T] >= 0
	    end

	    for t in T JuMP.fix(DELTA[Symbol(158),t], 0) end

	    for s in S
	        JuMP.fix(STOR_LEVEL[s,T[1]], 0)
	        JuMP.fix(G_STOR[s,T[1]], 0)
	        JuMP.fix(W_STOR[s,T[1]], 0)
	    end

		println("Set model objective")
		@objective(m, Min,
			sum(mc[p][t] * G[p,t] for p in P, t in T)
			+ 1000 * sum(LOST_LOAD[n,t] + LOST_GENERATION[n,t] for n in N, t in T)
		)

		println("Building constraints:")

	    prog = Progress(length(N)*length(T), 0.2, "MarketClearing...   ", 50)

	    @constraintref MarketClearing[N,T]
	    for n=N, t=T
	    MarketClearing[n,t] = @constraint(m,

	        sum(G[p,t] for p in map_n_p[n])
	        + sum(G_RES[r,t] for r in map_n_res[n])
	        + sum(G_STOR[s,t] for s in map_n_s[n])
	        + 500 * sum(b[n,nn] * DELTA[nn,t] for nn in N)
	        - LOST_GENERATION[n,t]

	        ==

	        load[n][t]
	        - exchange[n][t]
	        + sum(W_STOR[s,t] for s in map_n_s[n])
	        - LOST_LOAD[n,t] );

	    next!(prog)
	    end
	    JuMP.registercon(m, :MarketClearing, MarketClearing)

	    @constraintref GenerationRestriction[P,T]
	    prog = Progress(length(P)*length(T), 0.2, "Max generation...   ", 50)

	    for p=P, t=T
	    GenerationRestriction[p,t] = @constraint(m,

	        G[p,t] <= input_gen[p][t] );

	    next!(prog)
	    end

	    @constraintref ResRestriction[RES,T]
	    prog = Progress(length(RES)*length(T), 0.2, "Renewable infeed... ", 50)

	    for r=RES, t=T
	    ResRestriction[r,t] = @constraint(m,

	        G_RES[r,t] <= input_res[r][t] );

	    next!(prog)

	    end

		@constraintref StorageCapGeneration[S,T]
	    @constraintref StorageCapWithdraw[S,T]
	    @constraintref StorageCapLevel[S,T]
	    @constraintref StorageBalance[S,T]
	    prog = Progress(length(S)*length(T), 0.2, "Storages...         ", 50)

	    for s=S, t=T
	    StorageCapGeneration[s,t] = @constraint(m,

	        G_STOR[s,t] <= sto_power[s] );

	    StorageCapWithdraw[s,t] = @constraint(m,

	        W_STOR[s,t] <= sto_power[s] );

	    StorageCapLevel[s,t] = @constraint(m,

	        STOR_LEVEL[s,t] <= sto_capacity[s] );

	    if t != T[end]
	    StorageBalance[s,t] = @constraint(m,

	        STOR_LEVEL[s,t+1]
	        ==
	        STOR_LEVEL[s,t] + (eff[s] * W_STOR[s,t]) - G_STOR[s,t] );

	    elseif t == T[end]
	    StorageBalance[s,t] = @constraint(m,

	        STOR_LEVEL[s,T[1]]
	        ==
	        STOR_LEVEL[s,t] + (eff[s] * W_STOR[s,t]) - G_STOR[s,t] );

	    end #end of if statement
	    next!(prog)
	    end

	    @constraintref LinecapPositive[L,T]
	    @constraintref LinecapNegative[L,T]
	    @constraintref Lineflow[L,T]

	    prog = Progress(length(L)*length(T), 0.2, "Lineflow...         ", 50)

	    for l=L, t=T

	    LinecapPositive[l,t] = @constraint(m,

	        500 * LINEFLOW[l,t] <= p_max[l] );


	    LinecapNegative[l,t] = @constraint(m,

	        500 * LINEFLOW[l,t] >= - p_max[l] );

	    Lineflow[l,t] = @constraint(m,

	        LINEFLOW[l,t] == sum(h[l,n] * DELTA[n,t] for n in N) );

	    next!(prog)
	    end

		return m
	end # end of build model

	return build_model
end # end function `create_model`

"""
    run_model(em::JouliaModel, T::UnitRange{Int}; solver=error("Set a solver!"))

Run the model.
"""
function run_model(em::JouliaModel, T::UnitRange{Int}; solver=error("Set a solver!"))

	total = @elapsed begin
	elap_build = @elapsed m = em.f_build_model(collect(T))
	@info "Building model took $(round(elap_build, digits=1)) s"

	setsolver(m, solver)
	elap_solve = @elapsed status = solve(m)

	@info "Optimization took $(round(elap_solve, digits=1)) s to solve"

	vars = get_variable_names(m)

	for v in vars
		if haskey(em.results, v)
			df = jumpvar_to_df(getindex(m, v), dim_names=[:id,:hour])
			append!(em.results[v], df)
		else
			em.results[v] = jumpvar_to_df(getindex(m, v), dim_names=[:id,:hour])
		end
	end

	price = jumpvar_to_df(getindex(m, :MarketClearing), dual=true)
	haskey(em.results, :Price) ?
		append!(em.results[:Price], price) : em.results[:Price] = price

end # end of total elapsed

	return (Modelstat=status, Buildtime=elap_build, Solvetime=elap_solve,
		Totaltime=total, Starthour=T[1], Endhour=T[end])
end

"""
    run_model(em::JouliaModel, arr_T::Array{UnitRange{Int}, 1};
		solver=error("Set a solver!"))

Run the model.
"""
function run_model(em::JouliaModel, arr_T::Array{UnitRange{Int}, 1}
	;solver=Error("Set a solver!"))

	stat_arr = []
	for T in arr_T
		@info "Starting interval from $(T[1]) to $(T[end])"
		status = run_model(em, T, solver=solver)
		push!(stat_arr, status)
		status.Modelstat != :Optimal && @warn("Instance from $(T[1]) until $(T[end]) was not optimal!")
	end

	return stat_arr
end
