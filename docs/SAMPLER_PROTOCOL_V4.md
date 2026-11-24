# Sampler protocol update (v4)

This update changes only benchmark sample construction and its audit metadata; the three mining engines and their external-memory implementations are unchanged.

## Protocol now implemented by `bin/benchmark-optimized.jl`

1. Parse transactions through `read_spmf` in source order. Blank and metadata lines are skipped; item IDs within each transaction are sorted and de-duplicated. Duplicate transactions remain separate records.
2. Number valid transactions from 1 to N.
3. Rank TID `i` by the lowercase hexadecimal SHA-256 digest of the UTF-8 string `apriori-v1|SEED|i`, ascending, with TID ascending as an explicit tie-break. Default and group seed: 42.
4. For percentage `p`, select exactly `floor(N*p/100)` TIDs from the ranked prefix, then restore source order before writing the sample.
5. Write normalized transactions with one space between item IDs and LF line endings.
6. Record `source_sha256`, `sample_sha256`, and `selected_tid_sha256` in the sample manifest; the benchmark CSV includes input, sample, and selected-TID hashes.

For Chess (N=3,196), sample sizes are now 319, 799, 1,598, 2,397, and 3,196 for 10%, 25%, 50%, 75%, and 100%. The earlier v3 runner used Fisher-Yates plus ceiling; its 320-transaction Chess 10% results are exploratory and should not be mixed with runs produced by this sampler.

## Files changed

- `bin/benchmark-optimized.jl`: protocol implementation, manifest/CSV/report hashes, progress description.
- `test/benchmark_optimized_sampling.jl`: exact rank, floor, nesting, normalization, determinism, and Chess 319-TID regression checks.
- `test/runtests.jl`: includes the sampler regression suite.
- `docs/chuong-toi-uu-apriori.md`: benchmark protocol documentation aligned with `benchmarks/AGENTS.md`.

## Verification status

The editing environment does not contain Julia. Static review and an independent Python SHA-256 calculation were performed, but the Julia test suite has not been executed here. Run `julia --project=. test/runtests.jl` on the Windows machine before collecting new benchmark measurements.

## Independent Chess hashes for seed 42

For the checked-in `data/benchmarks/chess.txt` (raw SHA-256 `a12ea887df58a396709430af5bf0a9a32d1f6eba8e7c13dd41f28b98572c5db2`), the expected sample counts and hashes are:

| Sample | TIDs | sample_sha256 | selected_tid_sha256 |
|---:|---:|---|---|
| 10% | 319 | `5d8b4aceb1319bf8ce43f8c6791a70387cc495e160fba3fe4076020d90809a6c` | `aaa8b4bf695fa5d7008ef34cc4b9a0af55320a7c6435dff1f4a5cad69e2a49f2` |
| 25% | 799 | `4590906d980f42eeabc0fb9a29167ad650ab7384c36430992aea3a8e7c0d5e95` | `02b1ef5554d79316669fa2cd767f1572620a01eda32bf3c87b3fe5c5a93721db` |
| 50% | 1,598 | `feeedf0b3eb840e4bae81cdf03d55ba3f999bb2a8244ca4d93e9053c726bffc6` | `a22227da2ea32a6f30467a7c001d95b28a6923950e3da6e205fdf831f356c0c4` |
| 75% | 2,397 | `a999155381d982619d407838889d56e31e211e3dc9ce33ebf9d8de253e0425c0` | `0579445aaefe7e9019ebf87449e7e0bcb3ab3a8a09dca0fbda492200968618dd` |
| 100% | 3,196 | `341d0ff8676e053dd3b417d61f84c732736154f987ce56975a099b07460957f5` | `9839ab3742fa5c949f6dacaeb5b8930277a6cf0410b68cf9be1392dd1eb8e43f` |

These are protocol checksums, not benchmark measurements. Compare them with the new `output/*.samples/manifest.csv` before interpreting runtime results.
