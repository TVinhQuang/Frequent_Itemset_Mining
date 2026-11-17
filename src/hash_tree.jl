"""A hash-tree node: candidate IDs in a leaf, bucket-to-node indices otherwise."""
mutable struct HashTreeNode
    candidate_ids::Vector{Int}
    children::Dict{Int,Int}
end

"""A same-width candidate hash tree whose IDs are input candidate positions."""
struct HashTree{K}
    candidates::Vector{NTuple{K,Int}}
    compressed_candidates::Vector{NTuple{K,Int}}
    nodes::Vector{HashTreeNode}
    item_positions::Dict{Int,Int}
    bucket_count::Int
    leaf_capacity::Int
end

function _hash_positive_int(value, name)
    if !(value isa Integer) || value isa Bool || value < 1 || value > typemax(Int)
        throw(ArgumentError("$name must be a positive integer fitting Int"))
    end
    return Int(value)
end

function _hash_candidate_item(item)
    if !(item isa Integer) || item isa Bool || item < 0 || item > typemax(Int)
        throw(ArgumentError("candidate items must be nonnegative integers fitting Int"))
    end
    return Int(item)
end

function HashTree(candidates::AbstractVector; bucket_count=17, leaf_capacity=8)
    buckets = _hash_positive_int(bucket_count, "bucket_count")
    capacity = _hash_positive_int(leaf_capacity, "leaf_capacity")
    if isempty(candidates)
        candidate_type = eltype(candidates)
        if !(candidate_type <: Tuple) || !isconcretetype(candidate_type)
            throw(ArgumentError("empty candidates must have a concrete tuple element type"))
        end
        width = fieldcount(candidate_type)
    else
        first(candidates) isa Tuple || throw(ArgumentError("candidates must be tuples"))
        width = length(first(candidates))
    end
    width > 0 || throw(ArgumentError("candidates must be nonempty tuples"))
    canonical = NTuple{width,Int}[]
    sizehint!(canonical, length(candidates))
    for candidate in candidates
        candidate isa Tuple && length(candidate) == width ||
            throw(ArgumentError("candidates must be tuples of the same width"))
        converted = ntuple(index -> _hash_candidate_item(candidate[index]), width)
        for index in 2:width
            converted[index - 1] < converted[index] ||
                throw(ArgumentError("candidate items must be strictly increasing"))
        end
        push!(canonical, converted)
    end
    return _build_hash_tree(canonical, buckets, capacity)
end

function _build_hash_tree(candidates::Vector{NTuple{K,Int}}, buckets::Int,
                          capacity::Int) where {K}
    positions = Dict{Int,Int}()
    for candidate in candidates, item in candidate
        if !haskey(positions, item)
            positions[item] = length(positions) + 1
        end
    end
    compressed = NTuple{K,Int}[ntuple(i -> positions[candidate[i]], K)
                               for candidate in candidates]
    nodes = HashTreeNode[HashTreeNode(collect(eachindex(candidates)), Dict{Int,Int}())]
    tree = HashTree{K}(candidates, compressed, nodes, positions, buckets, capacity)
    _split_hash_leaf!(tree, 1, 1)
    return tree
end

function _split_hash_leaf!(tree::HashTree{K}, node_id::Int, depth::Int) where {K}
    node = tree.nodes[node_id]
    if length(node.candidate_ids) <= tree.leaf_capacity || depth > K
        return
    end
    for candidate_id in node.candidate_ids
        bucket = mod(tree.candidates[candidate_id][depth], tree.bucket_count)
        child_id = get(node.children, bucket, 0)
        if child_id == 0
            push!(tree.nodes, HashTreeNode(Int[], Dict{Int,Int}()))
            child_id = length(tree.nodes)
            node.children[bucket] = child_id
        end
        push!(tree.nodes[child_id].candidate_ids, candidate_id)
    end
    empty!(node.candidate_ids)
    for child_id in values(node.children)
        _split_hash_leaf!(tree, child_id, depth + 1)
    end
    return
end

"""Reusable query buffers; results remain valid only until the next query."""
struct HashQueryWorkspace
    membership::BitVector
    touched_items::Vector{Int}
    visited_leaves::BitVector
    touched_leaves::Vector{Int}
    result_ids::Vector{Int}
end

HashQueryWorkspace(tree::HashTree) = HashQueryWorkspace(
    falses(length(tree.item_positions)), Int[], falses(length(tree.nodes)), Int[], Int[])

function _query_hash_node!(workspace::HashQueryWorkspace, tree::HashTree{K},
                           node_id::Int, transaction::Vector{Int}, start::Int,
                           depth::Int) where {K}
    node = tree.nodes[node_id]
    if isempty(node.children)
        workspace.visited_leaves[node_id] && return
        workspace.visited_leaves[node_id] = true
        push!(workspace.touched_leaves, node_id)
        for candidate_id in node.candidate_ids
            candidate = tree.compressed_candidates[candidate_id]
            if all(index -> workspace.membership[index], candidate)
                push!(workspace.result_ids, candidate_id)
            end
        end
        return
    end
    # A node may be reached through several transaction prefixes. Only leaves
    # can be skipped globally, after their complete candidates were checked.
    for index in start:(length(transaction) - (K - depth))
        bucket = mod(transaction[index], tree.bucket_count)
        child_id = get(node.children, bucket, 0)
        if child_id != 0
            _query_hash_node!(workspace, tree, child_id, transaction, index + 1, depth + 1)
        end
    end
    return
end

"""Return matching candidate IDs in workspace-owned storage.

Transactions are sorted, unique vectors of nonnegative Int item IDs, as produced
by the miner's normalization. Create the workspace for the tree being queried.
"""
function matching_ids!(workspace::HashQueryWorkspace, tree::HashTree{K},
                       transaction::Vector{Int}) where {K}
    for index in workspace.touched_items
        workspace.membership[index] = false
    end
    for node_id in workspace.touched_leaves
        workspace.visited_leaves[node_id] = false
    end
    empty!(workspace.touched_items)
    empty!(workspace.touched_leaves)
    empty!(workspace.result_ids)
    for item in transaction
        index = get(tree.item_positions, item, 0)
        if index != 0 && !workspace.membership[index]
            workspace.membership[index] = true
            push!(workspace.touched_items, index)
        end
    end
    if length(transaction) >= K
        _query_hash_node!(workspace, tree, 1, transaction, 1, 1)
    end
    return workspace.result_ids
end

"""Return an independently owned vector of matching candidate IDs."""
function matching_ids(tree::HashTree, transaction::Vector{Int})
    return matching_ids!(HashQueryWorkspace(tree), tree, transaction)
end
