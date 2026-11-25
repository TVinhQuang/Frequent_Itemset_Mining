"""Run the complementary experiments. Only the Julia workers perform Apriori mining."""

import argparse
import csv
import hashlib
import itertools
import json
import os
import platform
import random
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
import zipfile
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKER = ROOT / "bin/benchmark-optimized.jl"
ENGINES = ("baseline", "bitset", "streaming")
MID = {"Retail": 500, "Chess": 7500, "Mushrooms": 1750, "Pumsb": 9200}
WIDTHS = (5, 10, 20, 30, 40, 50)
SEED = 42
N = 10_000
BATCH = 10_000


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def write_rows(path, rows):
    if rows:
        with path.open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)


def read_rows(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def synthetic_rows(n, width):
    # Fixed random permutation per TID gives nested baskets across all widths.
    rng = random.Random(SEED)
    for tid in range(n):
        order = rng.sample(range(3, 101), 98)
        planted = [1, 2] if tid % 2 == 0 else []
        yield sorted(planted + order[:width - len(planted)])


def width_pilot(out):
    # Prespecified selection rule at the widest point, before any timed runs.
    pairs = Counter()
    for row in synthetic_rows(1000, max(WIDTHS)):
        pairs.update(itertools.combinations(row, 2))
    records = []
    for bp in (2500, 2800, 3200, 3600):
        n_pairs = sum(count >= (bp + 9) // 10 for count in pairs.values())
        records.append(dict(n=1000, width=max(WIDTHS), minsup_bp=bp, frequent_pairs=n_pairs))
    write_rows(out / "pilot.csv", records)
    return next(r["minsup_bp"] for r in records if 1 <= r["frequent_pairs"] <= 100)


def read_mapping(lines):
    mapping = {}
    duplicates = 0
    for raw in lines:
        line = raw.strip()
        if not line or line.startswith((b"#", b"@", b"%")):
            continue
        items, count = line.split(b"#SUP:")
        key = b" ".join(str(i).encode() for i in sorted(map(int, items.split())))
        duplicates += key in mapping
        mapping[key] = int(count)
    return mapping, duplicates


def canonical(mapping):
    h = hashlib.sha256()
    for key, count in sorted(mapping.items()):
        h.update(key + b" #SUP: " + str(count).encode() + b"\n")
    return h.hexdigest()


def archive_reference(dataset, bp, sample):
    folder = next((ROOT / "benchmarks" / dataset).glob("*/results.csv")).parent
    row = next(r for r in read_rows(folder / "results.csv")
               if r["sample_pct"] == "100" and int(r["minsup_bp"]) == bp)
    if row["sample_sha256"] != sha(sample):
        raise ValueError("Historical SPMF sample hash mismatch")
    with zipfile.ZipFile(next(folder.glob("*.zip"))) as archive:
        with archive.open(f"p100-bp{bp}/rep-1/spmf.txt") as stream:
            reference, duplicates = read_mapping(stream)
    if duplicates or canonical(reference) != row["spmf_output_sha256"]:
        raise ValueError("Invalid reference in archived run")
    return reference


def sample_file(dataset, scratch):
    """Reproduce the full APRIORI-V1 sample in source order using LF line endings."""
    name = dataset.lower()
    source = ROOT / "data" / "benchmarks" / (name + ".txt")
    sample = Path(scratch) / (name + "-100pct.txt")
    with source.open(encoding="utf-8-sig") as rows, sample.open("w", encoding="ascii", newline="\n") as out:
        for row in rows:
            row = row.strip()
            if row and not row.startswith(("#", "@", "%")):
                items = sorted(set(map(int, row.split())))
                out.write(" ".join(map(str, items)) + "\n")
    return sample


def cases(part, out, scratch, args):
    if part == "width":
        bp = width_pilot(out)
        for width in WIDTHS:
            source = scratch / f"width-{width}.txt"
            with source.open("w", encoding="ascii", newline="\n") as f:
                for row in synthetic_rows(N, width):
                    f.write(" ".join(map(str, row)) + "\n")
            ref = scratch / f"width-{width}-spmf.txt"
            subprocess.run(["java", "-XX:-UsePerfData", "-Djava.io.tmpdir=" + str(scratch),
                            "-jar", str(args.jar), "run", "Apriori", str(source), str(ref),
                            f"{bp / 100:g}%"], check=True, timeout=args.timeout,
                           stdout=subprocess.DEVNULL)
            with ref.open("rb") as f:
                reference, duplicates = read_mapping(f)
            if duplicates:
                raise ValueError("Duplicate itemset in SPMF output")
            yield "Synthetic", width, bp, source, reference
    elif part == "size":
        base = sample_file("Retail", scratch)
        original = archive_reference("Retail", MID["Retail"], base)
        for factor in (1, 2, 5, 10):
            source = base
            if factor > 1:
                source = scratch / f"retail-{factor}x.txt"
                with source.open("wb") as target:
                    for _ in range(factor):
                        with base.open("rb") as f:
                            shutil.copyfileobj(f, target)
            yield "Retail", factor, MID["Retail"], source, {k: v * factor for k, v in original.items()}
    else:
        for dataset, middle in MID.items():
            sample = sample_file(dataset, scratch)
            archive_csv = next((ROOT / "benchmarks" / dataset).glob("*/results.csv"))
            grid = sorted({int(r["minsup_bp"]) for r in read_rows(archive_csv)
                           if r["sample_pct"] == "100"}, reverse=True)
            # The lowest and middle minsup already have all three optimized timings.
            missing = [bp for bp in grid if bp not in (middle, min(grid))]
            grid_to_run = {"exact": [middle], "lowest": [min(grid)], "minsup": missing}[part]
            for bp in grid_to_run:
                yield dataset, bp, bp, sample, archive_reference(dataset, bp, sample)


def describe(path):
    counts = Counter()
    n = occurrences = 0
    with path.open("rb") as stream:
        for row in stream:
            items = row.split()
            n += 1
            occurrences += len(items)
            counts.update(items)
    return dict(transactions=n, distinct_items=len(counts), mean_width=occurrences / n,
                singleton_min=min(counts.values()), singleton_median=statistics.median(counts.values()),
                singleton_max=max(counts.values()), input_bytes=path.stat().st_size, input_sha256=sha(path))


def compare_full_outputs(args, destination, tmp):
    """Compare cold processes through completion of the output file, against basic Scan."""
    out = destination / "output"
    out.mkdir()
    logs = out / "logs"
    logs.mkdir()
    engines = ("scan", "bitset", "streaming")
    raw, summaries = [], []
    with tempfile.TemporaryDirectory(dir=tmp) as scratch:
        for dataset, bp in MID.items():
            source = sample_file(dataset, scratch)
            stats = describe(source)
            threshold = (stats["transactions"] * bp + 9999) // 10000
            reference = archive_reference(dataset, bp, source)
            reference_hash = canonical(reference)
            for rep in range(3):
                for engine in engines[rep:] + engines[:rep]:
                    key = f"{dataset}-{engine}-{rep + 1}"
                    target = Path(scratch) / (key + ".txt")
                    command = [args.julia, "--threads=1", "--startup-file=no", "--project=.",
                               str(ROOT / "bin/study-output-worker.jl"), str(source), str(target),
                               str(threshold), engine]
                    print("output", key, flush=True)
                    row = dict(dataset=dataset, minsup_bp=bp, min_count=threshold, engine=engine,
                               repeat=rep + 1, sample_sha256=stats["input_sha256"], status="FAILED",
                               wall_ms="", peak_mib="", itemsets="", missing="", extra="",
                               wrong_support="", duplicates="", spmf_sha256=reference_hash, output_sha256="")
                    log = logs / (key + ".log")
                    with log.open("w", encoding="utf-8") as stream:
                        started = time.perf_counter_ns()
                        try:
                            completed = subprocess.run(command, cwd=ROOT, stdout=stream,
                                                       stderr=subprocess.STDOUT, timeout=args.timeout)
                        except subprocess.TimeoutExpired:
                            row["status"] = "TIMEOUT"
                        else:
                            row["wall_ms"] = (time.perf_counter_ns() - started) / 1e6
                            stream.flush()
                            if completed.returncode == 0:
                                peak = next(line for line in log.read_text().splitlines()
                                            if line.startswith("PEAK_BYTES|"))
                                row["peak_mib"] = int(peak.split("|")[1]) / 2**20
                                with target.open("rb") as f:
                                    observed, duplicates = read_mapping(f)
                                row.update(itemsets=len(observed), duplicates=duplicates,
                                           missing=len(reference.keys() - observed.keys()),
                                           extra=len(observed.keys() - reference.keys()),
                                           wrong_support=sum(observed[k] != reference[k]
                                                             for k in observed.keys() & reference.keys()),
                                           output_sha256=canonical(observed),
                                           status="PASS" if observed == reference and not duplicates else "MISMATCH")
                    raw.append(row)
                    write_rows(out / "raw.csv", raw)
                    target.unlink(missing_ok=True)
            case = []
            for engine in engines:
                trials = [r for r in raw if r["dataset"] == dataset and r["engine"] == engine]
                ok = all(r["status"] == "PASS" for r in trials)
                values = [r["wall_ms"] for r in trials]
                case.append(dict(dataset=dataset, minsup_bp=bp, engine=engine,
                                 status="PASS" if ok else "INCOMPLETE", sample_sha256=stats["input_sha256"],
                                 median_ms=statistics.median(values) if ok else "",
                                 min_ms=min(values) if ok else "", max_ms=max(values) if ok else "",
                                 median_peak_mib=statistics.median(r["peak_mib"] for r in trials) if ok else "",
                                 speedup_vs_scan="", ram_reduction_pct_vs_scan=""))
            baseline = case[0]
            for row in case:
                if row["status"] == baseline["status"] == "PASS":
                    row["speedup_vs_scan"] = baseline["median_ms"] / row["median_ms"]
                    row["ram_reduction_pct_vs_scan"] = 100 * (1 - row["median_peak_mib"] / baseline["median_peak_mib"])
            summaries.extend(case)
            write_rows(out / "results.csv", summaries)
    return all(r["status"] == "PASS" for r in raw)


def run_part(part, args, destination, tmp):
    if part == "output":
        return compare_full_outputs(args, destination, tmp)
    timed = part not in ("exact", "lowest")
    out = destination / part
    out.mkdir()  # Preserve earlier measurements, including interrupted runs.
    (out / "logs").mkdir()
    summaries, samples = [], []
    with tempfile.TemporaryDirectory(dir=tmp) as work:
        scratch = Path(work)
        for idx, (ds, axis, bp, source, ref) in enumerate(cases(part, out, scratch, args)):
            stats = describe(source)
            threshold = (stats["transactions"] * bp + 9999) // 10000
            ref_hash = canonical(ref)
            # Adjacent level files coexist until the new frequent level is complete.
            level_bytes = Counter()
            for key in ref:
                k = key.count(b" ") + 1
                level_bytes[k] += 8 * k
            disk_bytes = max((v + level_bytes[k - 1] for k, v in list(level_bytes.items())), default=0)
            case = []
            for engine in ENGINES[idx % 3:] + ENGINES[:idx % 3]:
                key = f"{ds}-{axis}-{engine}"
                emitted = scratch / (key + ".txt")
                args_jl = (["--export", str(source), str(threshold), engine, str(emitted)]
                           if not timed else
                           ["--worker", str(source), str(threshold), engine, "hash-tree", "1", "3",
                            str(BATCH), str(emitted)])
                command = [args.julia, "--startup-file=no", "--threads=1", "--project=.", str(WORKER), *args_jl]
                log = out / "logs" / (key + ".log")
                row = dict(dataset=ds, axis=axis, minsup_bp=bp, min_count=threshold, engine=engine, **stats,
                           status="FAILED", itemsets="", missing="", extra="", wrong_support="", duplicates="",
                           output_sha256="", spmf_sha256=ref_hash, candidates="", levels="", median_ms="",
                           min_ms="", max_ms="", peak_mib="", speedup="", time_reduction_pct="",
                           ram_reduction_pct="", adjacent_level_bytes=disk_bytes)
                started = time.monotonic()
                print(part, key, flush=True)
                with log.open("w", encoding="utf-8") as f:
                    try:
                        subprocess.run(command, cwd=ROOT, stdout=f, stderr=subprocess.STDOUT,
                                       check=True, timeout=args.timeout)
                    except subprocess.TimeoutExpired:
                        row["status"] = "TIMEOUT"
                    except subprocess.CalledProcessError:
                        f.flush()
                        if "OutOfMemoryError" in log.read_text(errors="replace"):
                            row["status"] = "OOM"
                    else:
                        with emitted.open("rb") as stream:
                            observed, dup = read_mapping(stream)
                        row.update(itemsets=len(observed), missing=len(ref.keys() - observed.keys()),
                                   extra=len(observed.keys() - ref.keys()), duplicates=dup,
                                   wrong_support=sum(ref[k] != v for k, v in observed.items() if k in ref),
                                   output_sha256=canonical(observed))
                        row["status"] = "PASS" if observed == ref and not dup else "MISMATCH"
                        emitted.unlink()
                        if timed:
                            records = {l.split("|")[0]: l.split("|")[1:] for l in log.read_text().splitlines()
                                       if l.startswith(("RESULT|", "SAMPLES|", "PEAK_BYTES|"))}
                            times = list(map(float, records["SAMPLES"]))
                            result = records["RESULT"]
                            assert len(times) == 3 and min(times) > 0 and int(records["PEAK_BYTES"][0]) > 0
                            assert int(result[4]) == stats["transactions"] and int(result[5]) == threshold
                            assert int(result[6]) == len(observed) and int(result[7]) == sum(observed.values())
                            row.update(median_ms=statistics.median(times), min_ms=min(times), max_ms=max(times),
                                       candidates=int(result[8]), levels=int(result[9]),
                                       peak_mib=int(records["PEAK_BYTES"][0]) / 2**20)
                            samples.extend(dict(dataset=ds, axis=axis, minsup_bp=bp, engine=engine,
                                                repeat=i, ms=t) for i, t in enumerate(times, 1))
                row["worker_wall_s_including_verification"] = round(time.monotonic() - started, 3)
                case.append(row)
                write_rows(out / "results.csv", summaries + case)
                write_rows(out / "raw.csv", samples)
            if timed:
                base = next(r for r in case if r["engine"] == "baseline")
                for r in case:
                    if r["status"] == base["status"] == "PASS":
                        r["speedup"] = base["median_ms"] / r["median_ms"]
                        r["time_reduction_pct"] = 100 * (1 - r["median_ms"] / base["median_ms"])
                        r["ram_reduction_pct"] = 100 * (1 - r["peak_mib"] / base["peak_mib"])
            summaries.extend(case)
            write_rows(out / "results.csv", summaries)
    return all(r["status"] == "PASS" for r in summaries)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--julia", default="julia")
    parser.add_argument("--jar", type=Path, help="SPMF JAR for width experiments")
    parser.add_argument("--output", type=Path, required=True, help="New results directory")
    parser.add_argument("--scratch", type=Path, default=ROOT / "output/study-tmp")
    parser.add_argument("--parts", nargs="+", choices=["width", "size", "minsup", "exact", "lowest", "output"],
                        default=["width", "size", "minsup", "exact", "lowest"])
    parser.add_argument("--timeout", type=int, default=360, help="Seconds per worker including verification")
    args = parser.parse_args()
    if "width" in args.parts and not (args.jar and args.jar.is_file()):
        parser.error("--jar is required for the width experiment")
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    tmp = args.scratch.resolve()
    tmp.mkdir(parents=True, exist_ok=True)
    for key in ("TEMP", "TMP", "TMPDIR"):
        os.environ[key] = str(tmp)
    config = subprocess.check_output([args.julia, "--startup-file=no", "-e",
                                     "println(Sys.cpu_info()[1].model); println(Sys.CPU_THREADS); "
                                     "println(Sys.total_memory()); println(VERSION)"], text=True).splitlines()
    source = [*sorted((ROOT / "src").glob("*.jl")), WORKER, Path(__file__).resolve()]
    if "output" in args.parts:
        source.append(ROOT / "bin/study-output-worker.jl")
    metadata = dict(utc=datetime.now(timezone.utc).isoformat(), cpu=config[0], logical_cpus=int(config[1]),
                    physical_ram_bytes=int(config[2]), julia=config[3], os=platform.platform(),
                    python=platform.python_version(), git=subprocess.check_output(["git", "rev-parse", "HEAD"],
                    cwd=ROOT, text=True).strip(), git_status=subprocess.check_output(
                    ["git", "status", "--porcelain"], cwd=ROOT, text=True).splitlines(),
                    sha256={p.relative_to(ROOT).as_posix(): sha(p) for p in source}, seed=SEED,
                    julia_threads=1, warmup=1, repeats=3, timeout_s=args.timeout, batch=BATCH,
                    spmf_jar_sha256=sha(args.jar) if args.jar else None,
                    java=subprocess.run(["java", "-version"], capture_output=True, text=True).stderr.splitlines()[0]
                    if args.jar else None, parts=args.parts, peak="Sys.maxrss before verification export",
                    memory_limit="No OS limit; internal membership index budgets use project defaults",
                    argv=sys.argv, working_directory=str(ROOT))
    if "output" in args.parts:
        metadata["output_protocol"] = dict(warmup=0, fresh_processes_per_engine=3,
            time="parent clock from spawn to exit, including read, mining and complete SPMF file",
            peak="Sys.maxrss in each fresh process after output is closed; median of three peaks")
        if args.parts == ["output"]:
            metadata.update(warmup=0, peak=metadata["output_protocol"]["peak"])
    (out / "metadata.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    with zipfile.ZipFile(out / "source.zip", "x", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in source:
            archive.write(path, path.relative_to(ROOT))
    statuses = [run_part(part, args, out, tmp) for part in args.parts]
    return 0 if all(statuses) else 1


if __name__ == "__main__":
    raise SystemExit(main())
