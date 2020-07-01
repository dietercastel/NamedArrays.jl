## rearrange.jl  methods the manipulated the data inside an NamedArray

## (c) 2013 David A. van Leeuwen

## This code is licensed under the MIT license
## See the file LICENSE.md in this distribution

## this does ' as well '
import Base.adjoint
function adjoint(a::NamedArray)
    ndims(a) ≤ 2 || error("Number of dimension must be ≤ 2")
    if ndims(a) == 1
        NamedArray(a.array', (["1"], names(a, 1)), ("'", a.dimnames[1]))
    else
        NamedArray(a.array', reverse(a.dicts), reverse(a.dimnames))
    end
end

import Base.reverse
function reverse(a::NamedArray{T,N}; dims::Int) where {T,N}
    vdicts = Array{OrderedDict}(undef, N)
    n = size(a,dims)+1
    for i=1:N
        dict = copy(a.dicts[i])
        if i==dims
            newnames = reverse(names(dict))
            empty!(dict)
            for (ind,k) in enumerate(newnames)
                dict[k] = ind
            end
        end
        vdicts[i] = dict
    end
    NamedArray(reverse(a.array, dims=dims), tuple(vdicts...), a.dimnames)
end

## circshift automagically works...
## :' automagically works, how is this possible? it is ctranspose!

import Base.permutedims

function permutedims(v::NamedVector)
    NamedArray(reshape(v.array, (1, length(v.array))),
        (["1"], names(v, 1)),
        ("_", v.dimnames[1]))
end

function permutedims(a::NamedArray, perm::Vector{Int})
    dicts = a.dicts[perm]
    dimnames = a.dimnames[perm]
    NamedArray(permutedims(a.array, perm), dicts, dimnames)
end

import Base.transpose
transpose(a::NamedVector) = permutedims(a)
transpose(a::NamedArray) = permutedims(a, [2,1])

import Base.vec
vec(a::NamedArray) = vec(a.array)

import Base.rotl90, Base.rot180, Base.rotr90
rotr90(n::NamedArray) = transpose(reverse(n, dims=1))
rotl90(n::NamedArray) = transpose(reverse(n, dims=2))
rot180(n::NamedArray) = NamedArray(rot180(n.array), tuple([reverse(name) for name in names(n)]...), n.dimnames)

import Combinatorics.nthperm, Combinatorics.nthperm!
import Base.permute!, Base.invpermute!, Base.reverse, Base.reverse!
import Random.shuffle, Random.shuffle!

function nthperm(v::NamedVector, n::Int)
    newnames = nthperm(names(v, 1), n)
    NamedArray(nthperm(v.array,n), (newnames,), v.dimnames)
end
function nthperm!(v::NamedVector, n::Int)
    setnames!(v, nthperm(names(v, 1), n), 1)
    nthperm!(v.array, n)
    return v
end
function permute!(v::NamedVector, perm::AbstractVector)
    setnames!(v, names(v, 1)[perm], 1)
    permute!(v.array, perm)
    return v
end
invpermute!(v::NamedVector, perm::AbstractVector) = permute!(v, invperm(perm))
shuffle(v::NamedVector) = permute!(copy(v), randperm(length(v)))
shuffle!(v::NamedVector) = permute!(v, randperm(length(v)))
reverse(v::NamedVector, start=1, stop=length(v)) = NamedArray(reverse(v.array, start, stop),  (reverse(names(v, 1), start, stop),), v.dimnames)
function reverse!(v::NamedVector, start=1, stop=length(v))
    setnames!(v, reverse(names(v, 1), start, stop), 1)
    reverse!(v.array, start, stop)
    v
end

import Base: _sortslices, _negdims, DimSelector

function my_compute_itspace(A, ::Val{dims}) where {dims}
    negdims = _negdims(ndims(A), dims)
    axs = Iterators.product(ntuple(DimSelector{dims}(A), ndims(A))...)
    vec(permutedims(collect(axs), (dims..., negdims...))), negdims
end

function _sortslices(A::NamedArray, d::Val{dims}; kws...) where dims
    itspace, negdims = my_compute_itspace(A, d)
    vecs = map(its->view(A, its...), itspace)
    p = sortperm(vecs; kws...)
    if ndims(A) == 2 && isa(dims, Integer) && isa(A.array, Array)
        # At the moment, the performance of the generic version is subpar
        # (about 5x slower). Hardcode a fast-path until we're able to
        # optimize this.
        return dims == 1 ? A[p, :] : A[:, p]
    else
        B = similar(A)
        for (x, its) in zip(p, itspace)
            B[its...] = vecs[x]
        end
        if ndims(A) == 2
            nd = negdims[1]
            setnames!(B, names(B, nd)[p], nd)
        else
            @warn("Can't keep dimnames in sortslices() for ndims ≠ 2")
        end
        B
    end
end

import Base.deleteat!


function deleteat!(n::N, key) where {T,N<:NamedVector{T}}
		idx= n.dicts[1][key]
		deleteat!(n.array,idx)
		delete!(n.dicts[1],key)
		return n
end

function deleteat!(n::N, i::Integer) where {T,N<:NamedVector{T}}
		key = collect(n.dicts[1])[i][1]
		deleteat!(n.array,i)
		delete!(n.dicts[1],key)
		return n
end
