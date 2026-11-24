# Review notes — External-Memory v4 sampler protocol

- Based on the user-tested External-Memory v3 repository.
- Updated `bin/benchmark-optimized.jl` to implement the repository's APRIORI-V1 sample protocol from `benchmarks/AGENTS.md`: normalize baskets with `read_spmf`, rank valid TIDs by SHA-256 of `apriori-v1|seed|tid`, select `floor(N*p/100)`, restore source order, and write LF-normalized samples.
- The sample manifest now records protocol, raw input SHA-256, sample SHA-256, and selected-TID SHA-256. The benchmark CSV/report carry the audit hashes and the protocol identifier.
- Updated the optimization documentation and added sampler regression tests, including Chess N=3,196 => 319 TIDs at 10%.
- Mining algorithms and external-memory engine implementations were not changed.

Verification status: ZIP integrity and static checks passed. Julia is not installed in the build environment, so `julia --project=. test/runtests.jl` has not been executed here. Run it on the Windows machine before collecting new measurements.
