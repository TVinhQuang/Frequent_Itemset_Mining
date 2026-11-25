"""Plot benchmark CSVs as a vector PDF and high-resolution PNGs. No mining takes place here."""

import argparse
import csv
import math
import os
from pathlib import Path

from reportlab.lib import colors
from reportlab.pdfgen.canvas import Canvas
import pypdfium2 as pdfium


PALETTE = {"baseline": "#375a80", "bitset": "#b24d0c", "streaming": "#187561"}
NAMES = {"baseline": "Hash-tree", "bitset": "Bitset", "streaming": "Streaming"}
SET_METRICS = {"itemsets", "candidates"}
PANELS = [("median_ms", "Runtime (s)"), ("peak_mib", "Peak process RAM (MiB)"),
          ("speedup", "Speedup vs Hash-tree (x)"), ("itemsets", "Frequent itemsets"),
          ("candidates", "Candidates incl. singletons"), ("ram_reduction_pct", "RAM reduction (%)")]


def records(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))

def save_records(path, rows):
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer=csv.DictWriter(stream,fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def historical(path, axis):
    data = []
    for r in records(path):
        if axis == "minsup" and r["sample_pct"] != "100":
            continue
        data.append(dict(engine=r["engine"].replace("baseline-hash-tree", "baseline"),
                         x=float(r["minsup_ratio"])*100 if axis == "minsup" else int(r["sample_pct"]),
                         median_ms=float(r["median_ms"]), min_ms=float(r["minimum_ms"]),
                         max_ms=float(r["maximum_ms"]), peak_mib=float(r["peak_ram_mib"]),
                         speedup=float(r["speedup_vs_baseline"]), candidates=int(r["candidates_total"]),
                         itemsets=int(r["frequent_itemsets"]), ram_reduction_pct=float(r["ram_reduction_pct"]),
                         time_reduction_pct=100*(1-1/float(r["speedup_vs_baseline"])),
                         source_csv=path, sample_sha256=r["sample_sha256"],
                         old=True, status="PASS" if r["same_as_baseline"] == "true" else "MISMATCH"))
    return data


def label(c, x, y, s, size=9, style="Helvetica"):
    c.setFillColor(colors.HexColor("#172330"))
    c.setFont(style, size)
    c.drawString(x, y, s)


def panel(c, x, y, rows, metric, title, xlabel, reverse, categories):
    chosen = [r for r in rows if r["status"] == "PASS" and
              (metric not in SET_METRICS or r["engine"] == "baseline")]
    if not chosen:
        label(c, x, y+116, title, 11, "Helvetica-Bold")
        label(c, x, y+70, "No completed observations")
        return
    scale = 1000 if metric == "median_ms" else 1
    xs = sorted({float(r["x"]) for r in rows}, reverse=reverse)
    left, right, low, high = x+39, x+252, y+25, y+105
    values = [float(r[metric])/scale for r in chosen]
    if metric == "median_ms":
        values.extend(float(r["min_ms"])/scale for r in chosen)
        values.extend(float(r["max_ms"])/scale for r in chosen)
    log_axis = (metric in {"median_ms", "speedup", "itemsets", "candidates"}
                and min(values) > 0 and max(values) / min(values) >= 100)
    if log_axis:
        ymin, ymax = math.floor(math.log10(min(values))), math.ceil(math.log10(max(values)))
        ticks = [10 ** exponent for exponent in range(ymin, ymax + 1)]
        title += " [log10]"
    else:
        ymin, ymax = min(0, min(values)), max(0, max(values))
        if ymin == ymax:
            ymax += 1
        ticks = sorted({0, ymin, ymax, (ymin + ymax) / 2})
    label(c, x, y+116, title, 11, "Helvetica-Bold")
    def px(v):
        return left+(float(v)-xs[0])/(xs[-1]-xs[0] or 1)*(right-left)
    def py(v):
        if log_axis:
            v = math.log10(v)
        return low+(v-ymin)/(ymax-ymin)*(high-low)
    for v in ticks:
        if v and not log_axis and abs(py(v) - py(0)) < 9:
            continue
        c.setStrokeColor(colors.HexColor("#d2d9de"))
        c.setLineWidth(0.4)
        c.line(left, py(v), right, py(v))
        c.setFillColor(colors.black)
        c.setFont("Helvetica", 7)
        c.drawRightString(left-3, py(v)-2, f"{v:,.0f}" if abs(v)>=100 else f"{v:.2g}")
    for v in xs:
        c.setFont("Helvetica", 7)
        c.drawCentredString(px(v),low-10,categories[int(v)] if categories else f"{v:g}")
    label(c,left,low-22,xlabel,8)
    for engine_index, (engine, color) in enumerate(PALETTE.items()):
        group = sorted((r for r in chosen if r["engine"] == engine),key=lambda r:float(r["x"]))
        c.setStrokeColor(colors.HexColor(color))
        c.setLineWidth(1)
        # Different historical runs remain distinct observations on the minsup pages.
        connect = not reverse and not categories
        last = None
        for r in group:
            xx, yy = px(r["x"]), py(float(r[metric])/scale)
            if categories and metric not in SET_METRICS:
                xx += (engine_index - 1) * 5
            if connect and last:
                c.line(*last,xx,yy)
            if metric == "median_ms":
                bottom, top = py(float(r["min_ms"])/scale), py(float(r["max_ms"])/scale)
                c.line(xx, bottom, xx, top)
                c.line(xx-1.5, bottom, xx+1.5, bottom)
                c.line(xx-1.5, top, xx+1.5, top)
            c.setFillColor(colors.white if r.get("old") else colors.HexColor(color))
            c.circle(xx,yy,2.2,stroke=1,fill=1)
            last = xx, yy


def page(c, title, rows, xlabel, note, reverse=False, categories=None):
    label(c, 25, 474, title, 16, "Helvetica-Bold")
    label(c, 25, 458, note, 8)
    for i,(engine,color) in enumerate(PALETTE.items()):
        x=25+i*104
        c.setFillColor(colors.HexColor(color))
        c.circle(x+2,443,2.6,stroke=0,fill=1)
        label(c,x+9,440,NAMES[engine],9)
    for i,(metric,heading) in enumerate(PANELS):
        if categories and metric == "candidates":
            metric,heading = "time_reduction_pct","Runtime reduction (%)"
        panel(c,25+(i%2)*280,296-(i//2)*140,rows,metric,heading,xlabel,reverse,categories)
    c.showPage()


def plot_scan_output(run):
    datasets = ("Retail", "Chess", "Mushrooms", "Pumsb")
    rows = records(run / "output/results.csv")
    trials = records(run / "output/raw.csv")
    for row in rows:
        sample = [r for r in trials if r["dataset"] == row["dataset"] and r["engine"] == row["engine"]
                  and r["status"] == "PASS"]
        if len(sample) != 3 or row["status"] != "PASS":
            raise ValueError(f"Incomplete output comparison for {row['dataset']} {row['engine']}")
        row.update(x=datasets.index(row["dataset"]), peak_mib=row["median_peak_mib"],
                   speedup=row["speedup_vs_scan"], ram_reduction_pct=row["ram_reduction_pct_vs_scan"])
        if row["engine"] == "scan":
            row["engine"] = "baseline"
    figures = run / "figures"
    figures.mkdir(exist_ok=True)
    pdf = figures / "scan-output.pdf"
    c = Canvas(str(pdf), pagesize=(595, 360))
    c.setTitle("Full output compared with basic Scan")
    label(c, 25, 335, "Full output compared with basic Scan", 16, "Helvetica-Bold")
    label(c, 25, 319, "Median of three fresh Julia processes per engine. Runtime whiskers span min to max.", 9)
    label(c, 25, 305, "Full datasets. Minimum support: Retail 5%, Chess 75%, Mushrooms 17.5%, Pumsb 92%.", 9)
    for idx, (engine, color) in enumerate(PALETTE.items()):
        x = 25 + 121 * idx
        c.setFillColor(colors.HexColor(color))
        c.circle(x + 2, 289, 2.6, stroke=0, fill=1)
        name = "Basic Scan" if engine == "baseline" else NAMES[engine] + " external"
        label(c, x + 10, 286, name, 9)
    metrics = [("median_ms", "Launch to exit (s)"), ("peak_mib", "Median peak RAM (MiB)"),
               ("speedup", "Speedup vs basic Scan (x)"), ("ram_reduction_pct", "RAM reduction vs basic Scan (%)")]
    for idx, (metric, title) in enumerate(metrics):
        panel(c, 25 + idx % 2 * 280, 153 - idx // 2 * 137, rows, metric, title,
              "Dataset", False, datasets)
    c.save()
    with pdfium.PdfDocument(str(pdf)) as document:
        sheet = document[0]
        bitmap = sheet.render(scale=3)
        bitmap.to_pil().save(figures / "scan-output.png")
        bitmap.close()
        sheet.close()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run",type=Path)
    parser.add_argument("--lowest-run",type=Path,help="Separate output folder if lowest was run separately")
    parser.add_argument("--scan-output", action="store_true", help="Plot the separate full-output comparison with Scan")
    args=parser.parse_args()
    run=args.run
    if args.scan_output:
        plot_scan_output(run)
        return
    charts=run/"figures"
    charts.mkdir(exist_ok=True)
    pdf=charts/"apriori.pdf"
    c=Canvas(str(pdf),pagesize=(595,500))
    c.setTitle("Apriori external-memory experiments")
    pages=[]
    for part,title,xlabel in [("width","Transaction width at fixed support","Items per transaction"),
                              ("size","Retail replication at 5% minimum support","Copies of Retail")]:
        rows=records(run/part/"results.csv")
        for r in rows:
            r["x"]=int(r["axis"])
        page(c,title,rows,xlabel,"Points show medians. Runtime whiskers span three repeats. Counts are shared by all engines.")
        pages.append(part)
    grid=records(run/"minsup/results.csv")
    exact=grid+records(run/"exact/results.csv")+records((args.lowest_run or run)/"lowest/results.csv")
    exact_fields=("dataset","minsup_bp","min_count","engine","transactions","itemsets","missing","extra",
                  "wrong_support","duplicates","status","input_sha256","spmf_sha256","output_sha256")
    save_records(run/"external-correctness.csv",[{k:r[k] for k in exact_fields} for r in exact])
    exact_index={(r["dataset"],int(r["minsup_bp"]),r["engine"]):r for r in exact}
    grid_index=[]
    datasets=("Retail","Chess","Mushrooms","Pumsb")
    middle=[]
    for idx,ds in enumerate(datasets):
        stem=ds.lower()
        rows=[dict(r,x=int(r["minsup_bp"])/100, source_csv=run/"minsup/results.csv",
                   sample_sha256=r["input_sha256"]) for r in grid if r["dataset"]==ds]
        mid=historical(run.parent/"kiem-chung-20261125"/(stem+".csv"),"minsup")
        middle.extend(dict(r,x=idx) for r in mid)
        rows+=mid
        rows+=historical(next(run.parent.glob(stem+"_opt_m*.csv")),"minsup")
        for r in sorted(rows,key=lambda r:(-r["x"], r["engine"])):
            bp=round(r["x"]*100)
            check=exact_index[ds,bp,r["engine"]]
            if r["sample_sha256"]!=check["input_sha256"]:
                raise ValueError(f"Different samples at {ds}, {bp}, {r['engine']}")
            if r["status"] == check["status"] == "PASS" and int(r["itemsets"]) != int(check["itemsets"]):
                raise ValueError(f"Different itemset counts at {ds}, {bp}, {r['engine']}")
            grid_index.append(dict(dataset=ds,minsup_pct=r["x"],engine=r["engine"],median_ms=r["median_ms"],
                                   min_ms=r["min_ms"],max_ms=r["max_ms"],peak_mib=r["peak_mib"],
                                   speedup=r["speedup"],time_reduction_pct=r["time_reduction_pct"],
                                   ram_reduction_pct=r["ram_reduction_pct"],candidates=r["candidates"],
                                   itemsets=r["itemsets"],sample_sha256=r["sample_sha256"],
                                   timing_status=r["status"],exact_status=check["status"],
                                   timing_source=Path(os.path.relpath(r["source_csv"],run)).as_posix()))
        page(c,ds+" by minimum support",rows,"Minimum support (%)",
             "Filled: supplementary run. Open: earlier runs. Ratios compare engines within each run. Runtime whiskers: min to max.",True)
        pages.append(stem+"-minsup")
        scale=historical(run.parent/(stem+"_opt_p10_100.csv"),"size")
        page(c,ds+" by transaction sample size",scale,"Sample (% of transactions)",
             "Historical measurements at fixed relative support. Runtime whiskers span three repeats.")
        pages.append(stem+"-scale")
    save_records(run/"minsup-grid.csv",grid_index)
    page(c,"Optimizations at the middle support threshold",middle,"Dataset",
         "Full inputs. Retail 5%, Chess 75%, Mushrooms 17.5%, Pumsb 92%. November 25 reference runs.",
         categories=datasets)
    pages.append("middle-support")
    c.save()
    with pdfium.PdfDocument(str(pdf)) as document:
        for idx,name in enumerate(pages):
            sheet=document[idx]
            try:
                bitmap=sheet.render(scale=3)
                bitmap.to_pil().save(charts/(name+".png"))
                bitmap.close()
            finally:
                sheet.close()


if __name__=="__main__":
    main()
