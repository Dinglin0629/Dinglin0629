from pathlib import Path
import os
import pandas as pd
os.environ.setdefault("MPLCONFIGDIR", str(Path(__file__).resolve().parent / "generated" / ".mplconfig"))
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

root = Path(__file__).resolve().parent
df = pd.read_csv(root / "generated" / "benchmark_summary.csv")
df["indexed"] = df["indexed"].astype(str).str.lower().isin(["t", "true", "1"])
plain = df[~df["indexed"]]
plt.style.use("seaborn-v0_8-whitegrid")
fig, axes = plt.subplots(2, 3, figsize=(11, 6.6), constrained_layout=True)
for q, ax in zip(range(1, 7), axes.ravel()):
    d = plain[plain.query_no == q]
    ax.plot(d.transaction_rows / 1000, d.mean_ms, marker="o", linewidth=2)
    ax.fill_between(d.transaction_rows / 1000, d.mean_ms-d.sd_ms,
                    d.mean_ms+d.sd_ms, alpha=.15)
    ax.set_title(f"Q{q}")
    ax.set_xlabel("Transactions (thousands)")
    ax.set_ylabel("Mean execution time (ms)")
fig.savefig(root / "generated" / "scalability.pdf", bbox_inches="tight")
fig.savefig(root / "generated" / "scalability.png", dpi=180, bbox_inches="tight")

before = plain[plain.size_level == 5].set_index("query_no").mean_ms
after = df[(df.indexed == True) & (df.size_level == 5)].set_index("query_no").mean_ms
cmp = pd.DataFrame({"Without indexes": before, "With indexes": after})
ax = cmp.plot.bar(figsize=(8.5, 4.6), color=["#8da0cb", "#1b9e77"])
ax.set_xlabel("Query")
ax.set_ylabel("Mean execution time (ms)")
ax.set_xticklabels([f"Q{i}" for i in cmp.index], rotation=0)
ax.grid(axis="x")
ax.legend(frameon=False)
plt.tight_layout()
plt.savefig(root / "generated" / "index_comparison.pdf", bbox_inches="tight")
plt.savefig(root / "generated" / "index_comparison.png", dpi=180, bbox_inches="tight")

cmp["change_pct"] = (cmp["With indexes"] / cmp["Without indexes"] - 1) * 100
cmp.to_csv(root / "generated" / "index_comparison.csv")
print(cmp.round(2))
