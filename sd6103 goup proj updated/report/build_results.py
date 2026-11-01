"""Reproduce Q1-Q6 result summaries from the PostgreSQL-ready CSVs."""
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "processed"
OUT = ROOT / "report" / "generated"
OUT.mkdir(parents=True, exist_ok=True)

town = pd.read_csv(DATA / "town.csv")
flat = pd.read_csv(DATA / "hdb_flat.csv", dtype={"block": str, "postal_code": str})
tx = pd.read_csv(DATA / "resale_transaction.csv", dtype={"block": str}, parse_dates=["sale_month"])
hawker = pd.read_csv(DATA / "hawker_centre.csv")
hawker["has_fresh_market"] = hawker["has_fresh_market"].astype("boolean")
prox = pd.read_csv(DATA / "flat_hawker_proximity.csv", dtype={"block": str})
prox["proximity_level_id"] = 3
prox.loc[prox.distance_m < 1000, "proximity_level_id"] = 2
prox.loc[prox.distance_m < 500, "proximity_level_id"] = 1
base = tx.merge(flat[["block", "street_name", "town_name"]], on=["block", "street_name"])
base["ppsm"] = base.resale_price / base.floor_area_sqm
base["flat_key"] = base["block"] + "|" + base["street_name"]

latest_month = base.sale_month.max()
q1 = (base[(base.flat_type.isin(["4 ROOM", "5 ROOM"])) &
           (base.sale_month >= latest_month - pd.DateOffset(years=3))]
      .groupby(["town_name", "flat_type"], as_index=False)
      .agg(avg_price_per_sqm=("ppsm", "mean"), transaction_count=("resale_price", "size"))
      .sort_values("avg_price_per_sqm", ascending=False))

base["lease_bucket"] = pd.cut(base.remaining_lease_months, [-1, 599, 839, 1188],
                              labels=["< 50 years", "50-69 years", "70+ years"])
q2 = (base.groupby(["town_name", "lease_bucket"], observed=True, as_index=False)
      .agg(median_resale_price=("resale_price", "median"), avg_price_per_sqm=("ppsm", "mean"),
           transaction_volume=("resale_price", "size")))

three = base[base.flat_type.eq("3 ROOM")].copy()
top_towns = three.groupby("town_name").floor_area_sqm.mean().nlargest(10).index
q3 = (three[three.town_name.isin(top_towns)].assign(sale_year=lambda x: x.sale_month.dt.year)
      .groupby(["town_name", "sale_year"], as_index=False)
      .resale_price.max().rename(columns={"resale_price": "highest_resale_price"}))

nearest = (prox.sort_values(["block", "street_name", "distance_m", "hawker_name"])
           .drop_duplicates(["block", "street_name"])[["block", "street_name", "proximity_level_id"]])
nb = base.merge(nearest, on=["block", "street_name"])
pivot = (nb[nb.proximity_level_id.isin([1, 3])]
         .pivot_table(index=["town_name", "flat_type"], columns="proximity_level_id",
                      values="resale_price", aggfunc="mean").dropna().reset_index())
pivot.columns.name = None
q4 = pivot.rename(columns={1: "avg_price_near_hawker", 3: "avg_price_far_hawker"})
q4["price_diff_percentage"] = ((q4.avg_price_near_hawker-q4.avg_price_far_hawker)
                                * 100/q4.avg_price_far_hawker)

fresh_names = set(hawker.loc[hawker.has_fresh_market.eq(True), "hawker_name"])
freshp = prox[prox.hawker_name.isin(fresh_names)][["block", "street_name", "proximity_level_id"]].drop_duplicates()
q5base = base.merge(freshp, on=["block", "street_name"])
q5 = (q5base.groupby(["town_name", "proximity_level_id"], as_index=False)
      .agg(avg_resale_price=("resale_price", "mean"), transaction_count=("source_row_key", "nunique")))
q5 = q5[q5.avg_resale_price > 200000].sort_values("avg_resale_price", ascending=False)

pq = prox.merge(hawker[["hawker_name", "has_fresh_market"]], on="hawker_name")
q6base = base.merge(pq[["block", "street_name", "proximity_level_id", "has_fresh_market"]],
                    on=["block", "street_name"])
q6 = (q6base.groupby(["town_name", "proximity_level_id", "has_fresh_market"], dropna=False, as_index=False)
      .agg(flat_count=("flat_key", "nunique"), transaction_count=("source_row_key", "nunique"),
           avg_resale_price=("resale_price", "mean")))

for name, frame in {"q1": q1, "q2": q2, "q3": q3, "q4": q4, "q5": q5, "q6": q6}.items():
    frame.to_csv(OUT / f"{name}_results.csv", index=False)

def esc(x):
    return str(x).replace("&", r"\&").replace("_", r"\_").replace("%", r"\%")

def latex_table(frame, columns, headers, n=10):
    rows = []
    for _, row in frame.head(n).iterrows():
        vals=[]
        for col in columns:
            v=row[col]
            if isinstance(v, float):
                vals.append(f"{v:,.2f}")
            else: vals.append(esc(v))
        rows.append(" & ".join(vals) + r" \\")
    spec = "l" + "r"*(len(columns)-1)
    return "\\begin{tabular}{"+spec+"}\n\\toprule\n"+" & ".join(headers)+r" \\\n+\\midrule\n"+"\n".join(rows)+"\n\\bottomrule\n\\end{tabular}\n"

parts = []
parts.append(r"\newcommand{\TownCount}{26}")
parts.append(r"\newcommand{\FlatCount}{9,828}")
parts.append(r"\newcommand{\TransactionCount}{972,461}")
parts.append(r"\newcommand{\HawkerCount}{129}")
parts.append(r"\newcommand{\ProximityCount}{42,909}")
parts.append("\\newcommand{\\QOneTable}{%\n"+latex_table(q1, ["town_name","flat_type","avg_price_per_sqm","transaction_count"], ["Town","Type","Avg. SGD/m$^2$","$n$"])+"}")
parts.append("\\newcommand{\\QFourTable}{%\n"+latex_table(q4.sort_values("price_diff_percentage",ascending=False), ["town_name","flat_type","avg_price_near_hawker","avg_price_far_hawker","price_diff_percentage"], ["Town","Type","Near","Far","Diff. (\\%)"])+"}")
parts.append("\\newcommand{\\QFiveTable}{%\n"+latex_table(q5, ["town_name","proximity_level_id","avg_resale_price","transaction_count"], ["Town","Band","Avg. price","$n$"])+"}")
(OUT / "results.tex").write_text("\n".join(parts), encoding="utf-8")
print({k: len(v) for k,v in {"q1":q1,"q2":q2,"q3":q3,"q4":q4,"q5":q5,"q6":q6}.items()})
