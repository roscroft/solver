using Combinatorics
using CDDLib, Polyhedra
using JuMP, Cbc

function coefficients(n_max)

    function count(order)
        # This function calculates the vision number of a sequence of numbers.
        # For example, count([1 3 2 4 5]) returns 4.
        vision_num = 0
        highest_seen = 0
        for i in order
            if i > highest_seen
                highest_seen = i
                vision_num = vision_num + 1
            end
        end
        return vision_num
    end

    function build_num_dict(print_dict)
        # This function calculates all permutations of the sequence 1:n_max, and then
        # calculates the vision numbers for each permutation. Finally, it returns a dictionary
        # that has all vision numbers for the sequence as its keys, and the corresponding 
        # permutations with that vision number as its values.
        vision_nums = Dict()
        perms = collect(permutations(1:n_max))

        for perm in perms
            perm = hcat(perm)'
            vision_num = count(perm)
            try
                current_val = vision_nums[vision_num]
                vision_nums[vision_num] = vcat(current_val, perm)
                catch error
                    if isa(error, KeyError)
                        vision_nums[vision_num] = perm
                    end
            end
        end
        if print_dict
            println(vision_nums)
            for key in sort(collect(keys(vision_nums)))
                #= println("$key => $(vision_nums[key])") =#
            end
        end
        return vision_nums
    end
    
    function build_ineqs_dict()
        # This function uses the Polyhedral.jl package to make a new dictionary that maps vision
        # numbers to the inequalities that enforce those vision numbers.
        vision_nums = build_num_dict(false)
        #= ineqs = Dict{Int64,Dict{String,Array{Any,Any}}} =#
        ineqs = Dict()
        for idx in 1:n_max
            #= idx_dict = Dict{String,Array{Any,Any}} =#
            idx_dict = Dict()
            denominators = Set([])
            vertices = vision_nums[idx]
            points = SimpleVRepresentation(vertices)
            poly = polyhedron(points, CDDLibrary(:exact))
            removehredundancy!(poly)
            ineq = SimpleHRepresentation(poly)
            ineqA = ineq.A
            ineqb = ineq.b
            lcmA = lcm(denominator.(ineqA))
            ineqA = convert.(Int64, lcmA*ineqA)
            ineqb = convert.(Int64, lcmA*ineqb)
            idx_dict["A"] = ineqA
            idx_dict["b"] = ineqb
            ineqs[idx] = idx_dict
        end
        return ineqs
    end

    return build_ineqs_dict()
end

function solve_tower(n_max, top, right, bottom, left)
    # In this final function, we build and solve the model, using constraints that control the 
    # binary variables responsible for enforcing the uniqueness properties of the solution values,
    # as well as the generated constraints that enforce the appropriate vision numbers for each
    # row and column.
    #= println("N: ",n_max) =#
    #= println("Top: ",top) =#
    #= println("Right: ",right) =#
    #= println("Bottom: ",bottom) =#
    #= println("Left: ",left) =#
    const ineqs = coefficients(n_max)
    model = Model(solver=CbcSolver())
    @variable(model, 1 <= x[1:n_max, 1:n_max] <= n_max, Int)
    @variable(model, b[1:n_max, 1:n_max, 1:n_max], Bin)
    @constraint(model, [i=1:n_max, j=1:n_max], x[i,j] == sum(k*b[i,j,k] for k = 1:n_max))
    @constraint(model, [i=1:n_max, k=1:n_max], sum(b[i,j,k] for j=1:n_max) == 1)
    @constraint(model, [j=1:n_max, k=1:n_max], sum(b[i,j,k] for i=1:n_max) == 1)
    #= print(model) =#
    #= println("Model created.") =#
    #= println(model) =#
    for idx in 1:n_max
        top_set = ineqs[top[idx]]
        bot_set = ineqs[bottom[idx]]
        left_set = ineqs[left[idx]]
        right_set = ineqs[right[idx]]
        # Top
        @constraint(model, top_set["A"]*x[:,idx] .<= top_set["b"])
        @constraint(model, bot_set["A"]*x[end:-1:1,idx] .<= bot_set["b"])
        @constraint(model, left_set["A"]*x[idx,:] .<= left_set["b"])
        @constraint(model, right_set["A"]*x[idx,end:-1:1] .<= right_set["b"])
    end
    #= print(model) =#
    #= println("All constraints added.") =#
    status = solve(model)
    if status != :Optimal
        output = None
    else
        #= println("Model solved!") =#
        soln = convert.(Int64, getvalue(x))
        output = ""
        for idx = 1:n_max
            output = string(output, "\n",soln[idx,:])
        end
        #= println(output) =#
    end
    return output
end
