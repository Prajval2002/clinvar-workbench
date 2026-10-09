#!/usr/bin/env python3

import csv
import html
from collections import Counter
from pathlib import Path

OUT = Path.home() / "clinngs-work/results/HG002_dev_chr1/annotation"

FILES = {
    "all": OUT / "HG002_dev_chr1.prioritized.tsv",
    "review": OUT / "HG002_dev_chr1.review_queue.tsv",
    "quality": OUT / "HG002_dev_chr1.quality_followup.tsv",
    "secondary": OUT / "HG002_dev_chr1.secondary_candidates.tsv",
}

REPORT = OUT / "HG002_dev_chr1.clinvar_workbench_report.html"


def read_tsv(path):
    if not path.is_file():
        raise FileNotFoundError(f"Required file not found: {path}")

    with path.open("r", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def esc(value):
    return html.escape(str(value if value not in (None, "") else "."))


def make_table(rows, columns, limit=None):
    shown = rows if limit is None else rows[:limit]

    head = "".join(
        f"<th>{esc(label)}</th>" for label, _ in columns
    )

    body = []
    for row in shown:
        cells = "".join(
            f"<td>{esc(row.get(key, '.'))}</td>"
            for _, key in columns
        )
        body.append(f"<tr>{cells}</tr>")

    if not body:
        body.append(
            f'<tr><td colspan="{len(columns)}">No rows in this section.</td></tr>'
        )

    note = ""
    if limit is not None and len(rows) > limit:
        note = (
            f'<p class="muted">Showing {limit} of {len(rows)} rows. '
            f'The complete data are available in the TSV file.</p>'
        )

    return (
        '<div class="table-wrap"><table><thead><tr>'
        + head
        + "</tr></thead><tbody>"
        + "".join(body)
        + "</tbody></table></div>"
        + note
    )


def download_link(path):
    return f'<a href="{esc(path.name)}">{esc(path.name)}</a>'


def main():
    data = {key: read_tsv(path) for key, path in FILES.items()}

    all_rows = data["all"]
    review = data["review"]
    quality = data["quality"]
    secondary = data["secondary"]

    total = len(all_rows)
    passed = sum(row.get("FILTER") == "PASS" for row in all_rows)
    filtered = total - passed

    clinvar_record_count = sum(
        row.get("ClinVar_AlleleID", ".") != "."
        or row.get("ClinVar_Significance", ".") != "."
        for row in all_rows
    )
    clnsig_count = sum(
        row.get("ClinVar_Significance", ".") != "."
        for row in all_rows
    )

    categories = Counter(
        row.get("Priority_Category", "Unclassified")
        for row in all_rows
    )

    category_rows = [
        {"category": name, "count": count}
        for name, count in sorted(
            categories.items(),
            key=lambda item: (-item[1], item[0])
        )
    ]

    review_columns = [
        ("CHROM", "Chromosome"),
        ("POS", "Position"),
        ("REF", "REF"),
        ("ALT", "ALT"),
        ("Gene", "Gene_Symbol"),
        ("Consequence", "VEP_Consequence"),
        ("Impact", "VEP_Impact"),
        ("ClinVar significance", "ClinVar_Significance"),
        ("Review status", "ClinVar_Review_Status"),
        ("GT", "Genotype"),
        ("DP", "DP"),
        ("GQ", "GQ"),
        ("Priority", "Priority_Category"),
        ("Reason", "Priority_Reason"),
    ]

    quality_columns = [
        ("CHROM", "Chromosome"),
        ("POS", "Position"),
        ("REF", "REF"),
        ("ALT", "ALT"),
        ("FILTER", "FILTER"),
        ("Gene", "Gene_Symbol"),
        ("Consequence", "VEP_Consequence"),
        ("GT", "Genotype"),
        ("DP", "DP"),
        ("GQ", "GQ"),
        ("QC flags", "QC_Flags"),
        ("Priority", "Priority_Category"),
    ]

    all_columns = [
        ("CHROM", "Chromosome"),
        ("POS", "Position"),
        ("REF", "REF"),
        ("ALT", "ALT"),
        ("FILTER", "FILTER"),
        ("Gene", "Gene_Symbol"),
        ("Consequence", "VEP_Consequence"),
        ("Impact", "VEP_Impact"),
        ("ClinVar significance", "ClinVar_Significance"),
        ("Review status", "ClinVar_Review_Status"),
        ("GT", "Genotype"),
        ("DP", "DP"),
        ("GQ", "GQ"),
        ("QC flags", "QC_Flags"),
        ("Priority", "Priority_Category"),
    ]

    links = "".join(
        f"<li>{download_link(path)}</li>"
        for path in [
            FILES["all"],
            FILES["review"],
            FILES["quality"],
            FILES["secondary"],
        ]
    )

    category_table = make_table(
        category_rows,
        [("Priority category", "category"), ("Record count", "count")]
    )

    review_table = make_table(review, review_columns)
    quality_table = make_table(quality, quality_columns, limit=25)
    secondary_table = make_table(secondary, all_columns, limit=25)
    full_table = make_table(all_rows, all_columns, limit=315)

    document = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>ClinVar Workbench — Development Report</title>
<style>
:root {{
  color-scheme: light;
  --ink: #17212b;
  --muted: #5d6a76;
  --line: #dce3e8;
  --surface: #ffffff;
  --page: #f3f6f8;
  --accent: #236b65;
}}
* {{ box-sizing: border-box; }}
body {{
  margin: 0;
  background: var(--page);
  color: var(--ink);
  font: 15px/1.55 system-ui, -apple-system, "Segoe UI", sans-serif;
}}
header {{
  background: #162d38;
  color: white;
  padding: 32px max(20px, calc((100% - 1400px)/2));
}}
header h1 {{ margin: 0 0 8px; font-size: 28px; }}
header p {{ margin: 4px 0; color: #d9e5e9; }}
main {{ max-width: 1400px; margin: 24px auto; padding: 0 20px 40px; }}
section {{
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: 10px;
  padding: 20px;
  margin-bottom: 20px;
}}
h2 {{ font-size: 20px; margin: 0 0 14px; }}
h3 {{ font-size: 16px; margin: 16px 0 8px; }}
.metrics {{
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(165px, 1fr));
  gap: 12px;
  margin-bottom: 20px;
}}
.metric {{
  background: white;
  border: 1px solid var(--line);
  border-radius: 10px;
  padding: 16px;
}}
.metric .label {{ color: var(--muted); font-size: 13px; }}
.metric .value {{ display: block; margin-top: 4px; font-size: 28px; font-weight: 700; }}
.muted {{ color: var(--muted); font-size: 13px; }}
.table-wrap {{ overflow-x: auto; max-width: 100%; }}
table {{ border-collapse: collapse; width: 100%; font-size: 13px; }}
th, td {{
  text-align: left;
  padding: 8px 10px;
  border-bottom: 1px solid var(--line);
  vertical-align: top;
  max-width: 360px;
  overflow-wrap: anywhere;
}}
th {{ background: #eef3f5; position: sticky; top: 0; }}
a {{ color: var(--accent); }}
.notice {{
  border-left: 4px solid var(--accent);
  padding: 12px 16px;
  background: #f0f6f5;
}}
footer {{ color: var(--muted); font-size: 12px; padding: 4px 0 20px; }}
@media print {{
  body {{ background: white; }}
  section, .metric {{ break-inside: avoid; }}
  .table-wrap {{ overflow: visible; }}
}}
</style>
</head>
<body>
<header>
  <h1>ClinVar Workbench</h1>
  <p>Germline variant analysis — development report</p>
  <p>Sample: HG002_dev_chr1 | Region: chr1:900000–1100000 (200 kb)</p>
  <p>Generated from the current local VEP and ClinVar annotation tables.</p>
</header>

<main>
  <div class="notice">
    <strong>Research-use report only.</strong>
    This is a development-region demonstration, not a clinical diagnostic report.
    Variant rankings are heuristics. ClinVar classifications, transcript relevance,
    genotype quality and other evidence require independent review.
    Missing ClinVar evidence does not mean benignity.
  </div>

  <div class="metrics" style="margin-top:20px">
    <div class="metric"><span class="label">Total records</span><span class="value">{total}</span></div>
    <div class="metric"><span class="label">GATK PASS</span><span class="value">{passed}</span></div>
    <div class="metric"><span class="label">GATK filtered</span><span class="value">{filtered}</span></div>
    <div class="metric"><span class="label">ClinVar allele/significance entries</span><span class="value">{clinvar_record_count}</span></div>
    <div class="metric"><span class="label">Records with CLNSIG</span><span class="value">{clnsig_count}</span></div>
    <div class="metric"><span class="label">Focused review queue</span><span class="value">{len(review)}</span></div>
    <div class="metric"><span class="label">PASS records with QC flags</span><span class="value">{len(quality)}</span></div>
    <div class="metric"><span class="label">Secondary clean PASS candidates</span><span class="value">{len(secondary)}</span></div>
  </div>

  <section>
    <h2>Priority category summary</h2>
    {category_table}
  </section>

  <section>
    <h2>Focused review queue</h2>
    <p class="muted">PASS variants selected by the current research triage rules with no DP/GQ warning. This is a review aid, not a list of confirmed disease-causing variants.</p>
    {review_table}
  </section>

  <section>
    <h2>Quality follow-up</h2>
    <p class="muted">The first 25 of {len(quality)} PASS records with a DP below 10 and/or GQ below 20, sorted according to the existing prioritization table. QC flags indicate follow-up needs, not proven invalid calls.</p>
    {quality_table}
  </section>

  <section>
    <h2>Secondary candidates</h2>
    <p class="muted">The first 25 of {len(secondary)} other PASS records without current DP/GQ flags. They remain in the complete table and are not classified as benign just because they are not in the focused queue.</p>
    {secondary_table}
  </section>

  <section>
    <h2>All variant records</h2>
    <p class="muted">All {total} records are retained, including GATK-filtered calls.</p>
    <details>
      <summary>Expand the complete table</summary>
      {full_table}
    </details>
  </section>

  <section>
    <h2>Download the TSV outputs</h2>
    <ul>{links}</ul>
    <p class="muted">The TSV files contain the complete column-level data for downstream analysis.</p>
  </section>

  <footer>
    Generated locally by scripts/generate_report.py.
    No clinical interpretation or diagnosis is made by this report.
  </footer>
</main>
</body>
</html>
"""

    REPORT.write_text(document, encoding="utf-8")
    print(f"Report created: {REPORT}")
    print(f"Report size: {REPORT.stat().st_size:,} bytes")
    print(f"Records: {total} | PASS: {passed} | filtered: {filtered}")
    print(f"Focused review: {len(review)} | QC follow-up: {len(quality)}")


if __name__ == "__main__":
    main()
