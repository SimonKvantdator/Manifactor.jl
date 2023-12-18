# Approximate a function f: [-1, 1]^3 -> Seg((k, k))
using Manifolds
using ManiFactor
using ApproximatingMapsBetweenLinearSpaces: chebfun
using TensorToolbox: hosvd
using LinearAlgebra
using Random
using Plots; pyplot()

m=3
Ns=2:1:16

s=100
M = Segre((s, s))

# f(x) is the closest rank 1 approximation to
#   exp(a x1) exp(V x2) diag(2^-1, 2^-2, ...) exp(W x2)
Random.seed!(4)
W1 = rand(s, s); W1 = (W1 - W1') / 2; W1 = W1 / norm(W1)
W2 = rand(s, s); W2 = (W2 - W2') / 2; W2 = W2 / norm(W2)
i = [1, zeros(s - 1)...]
function f(x) # :: [-1, 1]^m -> Segre((k, k))
    return [
        [exp(x[1])],
        exp(W1 * x[2]) * i,
        exp(W2 * x[3]) * i
        ]
end

H = -exp(2) # Lower bound for curvature

# Loop over nbr of interpolation points
es = [NaN for _ in Ns]
bs = [NaN for _ in Ns]
for (i, N) = enumerate(Ns)
    local fhat = approximate(
        m,
        M,
        f;
        univariate_scheme=chebfun(N),
        decomposition_method=hosvd,
        eps_rel=1e-15,
        )

    local p = get_p(fhat)
    local ghat = get_ghat(fhat)
    local g = (X -> get_coordinates(M, p, X, DefaultOrthonormalBasis())) ∘ (x -> log(M, p, f(x)))
    local sigma = maximum([ distance(M, p, f(x)) for x in [2 * rand(m) .- 1.0 for _ in 1:1000]])

    xs = [2 * rand(m) .- 1.0 for _ in 1:1000]
    es[i] = maximum([
        distance(M, f(x), fhat(x))
        for x in xs])
    bs[i] = let
            epsilon = maximum([norm(g(x) - ghat(x)) for x in xs])
            epsilon + 2 / sqrt(abs(H)) * asinh(epsilon * sinh(sqrt(abs(H)) * sigma) / (2 * sigma))
        end
end

p = plot(;
    xlabel="N",
    xticks=Ns,
    yaxis=:log,
    ylims=(1e-16, 2 * maximum([es..., bs...])),
    yticks=([1e0, 1e-5, 1e-10, 1e-15]),
    legend=:topright,
    )
plot!(p, Ns[1:end-3], bs[1:end-3]; label="error bound")
scatter!(p, Ns, es; label="measured error")
display(p)

# # To save figure and data to file:
# using CSV
# using DataFrames: DataFrame
# savefig("Example3.png")
# CSV.write("Example3.csv", DataFrame([:Ns => Ns, :es => es, :bs => bs]))
