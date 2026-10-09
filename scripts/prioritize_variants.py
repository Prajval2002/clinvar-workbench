#!/usr/bin/env python3

import csv
import gzip
import re
import sys
from collections import Counter
from pathlib import Path

OUT = Path.home() / "clinngs-work/results/HG002_dev_chr1/annotation"
CLINVAR_VCF = OUT / "HG002_dev_chr1.clinvar.vcf.gz"
VEP_VCF = OUT / "HG002_dev_chr1.vep.vcf.gz"


def parse_info(text):
    result = {}
    if text == ".":
        return result

    for item in text.split(";"):
        if "=" in item:
            key, value = item.split("=", 1)
            result[key] = value
        else:
            result[item] = True

    return result


def parse_format(fmt, sample):
    if not fmt or fmt == "." or not sample:
        return {}

    return dict(zip(fmt.split(":"), sample.split(":")))


def join_unique(values):
    clean = dict.fromkeys(
        str(v) for v in values
        if v not in ("", ".", None)
    )
    return ";".join(clean) if clean else "."


def read_vcf(path, with_csq=False):
    records = {}
    csq_fields = []

    with gzip.open(path, "rt") as handle:
        for line in handle:
            if line.startswith("##INFO=<ID=CSQ,"):
                match = re.search(r"Format: ([^\"]+)", line)
                if match:
                    csq_fields = match.group(1).rstrip(">").split("|")
                continue

            if line.startswith("#"):
                continue

            col = line.rstrip("\n").split("\t")

            chrom, pos, _, ref, alt = col[:5]
            info = parse_info(col[7])
            fmt = parse_format(
                col[8] if len(col) > 8 else "",
                col[9] if len(col) > 9 else ""
            )

            entries = []

            if with_csq and info.get("CSQ") and csq_fields:
                for annotation in str(info["CSQ"]).split(","):
                    values = annotation.split("|")
                    values += [""] * max(
                        0, len(csq_fields) - len(values)
                    )
                    entries.append(dict(zip(csq_fields, values)))

            records[(chrom, pos, ref, alt)] = {
                "chrom": chrom,
                "pos": pos,
                "ref": ref,
                "alt": alt,
                "filter": col[6],
                "info": info,
                "format": fmt,
                "csq": entries,
            }

    return records, csq_fields


def field_value(entries, field):
    return join_unique([entry.get(field, "") for entry in entries])


def as_number(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def get_qc_flags(fmt):
    flags = []

    dp = as_number(fmt.get("DP"))
    gq = as_number(fmt.get("GQ"))

    if dp is not None and dp < 10:
        flags.append("LOW_DP")

    if gq is not None and gq < 20:
        flags.append("LOW_GQ")

    return ";".join(flags) if flags else "."


def classify(record, entries):
    if record["filter"] != "PASS":
        return 99, "Filtered variant", (
            "GATK FILTER is not PASS; review separately."
        )

    info = record["info"]
    raw_sig = str(info.get("CLNSIG", "."))
    sig = raw_sig.lower().replace("_", " ").replace("|", " ")
    sig = re.sub(r"\s+", " ", sig).strip()

    if "conflict" in sig or (
        "pathogenic" in sig and "benign" in sig
    ):
        return 3, "Conflicting ClinVar interpretations", (
            "Review individual assertions and review status."
        )

    if "likely pathogenic" in sig:
        return 2, "ClinVar likely pathogenic", (
            "Reported classification; independently review evidence."
        )

    if "pathogenic" in sig:
        return 1, "ClinVar pathogenic", (
            "Reported classification; independently review evidence."
        )

    if "uncertain significance" in sig:
        return 4, "ClinVar uncertain significance", (
            "Uncertain significance is not proof of pathogenicity."
        )

    if "likely benign" in sig:
        return 10, "ClinVar likely benign", (
            "Reported classification; review evidence and status."
        )

    if "benign" in sig:
        return 11, "ClinVar benign", (
            "Reported classification; review evidence and status."
        )

    biotypes = {
        entry.get("BIOTYPE", "").lower()
        for entry in entries if entry.get("BIOTYPE")
    }
    impacts = {
        entry.get("IMPACT", "").upper()
        for entry in entries if entry.get("IMPACT")
    }

    protein_coding = "protein_coding" in biotypes

    if "HIGH" in impacts and protein_coding:
        return 5, "High-impact protein-coding consequence", (
            "Predicted consequence requiring transcript and evidence review."
        )

    if "MODERATE" in impacts and protein_coding:
        return 6, "Moderate-impact protein-coding consequence", (
            "Predicted consequence requiring further evidence."
        )

    if "HIGH" in impacts and not protein_coding:
        return 7, "High-impact non-coding consequence", (
            "Inspect transcript relevance and technical quality."
        )

    if str(info.get("ALLELEID", ".")) != ".":
        return 7, "ClinVar record without clear significance", (
            "ClinVar record exists but no clear classification was extracted."
        )

    if raw_sig != ".":
        return 8, "Other ClinVar assertion", (
            "Review the assertion type and clinical context."
        )

    return 9, "No prioritized evidence found", (
        "Retain in complete results; no priority category was assigned."
    )


def write_tsv(path, rows, columns):
    with open(path, "w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=columns,
            delimiter="\t",
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)


def main():
    for path in (CLINVAR_VCF, VEP_VCF):
        if not path.is_file() or path.stat().st_size == 0:
            sys.exit(f"ERROR: Input missing or empty: {path}")

    clinvar, _ = read_vcf(CLINVAR_VCF)
    vep, csq_fields = read_vcf(VEP_VCF, with_csq=True)

    if not clinvar or not vep:
        sys.exit("ERROR: An input VCF contains no variant records.")

    if not csq_fields:
        sys.exit("ERROR: VEP CSQ header could not be parsed.")

    print(f"ClinVar VCF records: {len(clinvar)}")
    print(f"VEP VCF records:     {len(vep)}")
    print(f"Exact keys shared:   {len(set(clinvar) & set(vep))}")

    columns = [
        "Chromosome", "Position", "REF", "ALT", "FILTER",
        "Genotype", "DP", "GQ", "AD", "QC_Flags",
        "VEP_Consequence", "VEP_Impact", "Gene_Symbol",
        "Gene_ID", "Transcript", "Biotype", "HGVSc", "HGVSp",
        "Canonical", "Variant_Class",
        "ClinVar_AlleleID", "ClinVar_Significance",
        "ClinVar_Review_Status", "ClinVar_Disease",
        "ClinVar_Disease_IDs", "ClinVar_HGVS",
        "ClinVar_Variant_Type", "ClinVar_Molecular_Consequence",
        "Priority_Rank", "Priority_Category", "Priority_Reason"
    ]

    rows = []

    for key, record in clinvar.items():
        vep_record = vep.get(key, {})
        entries = vep_record.get("csq", [])
        info = record["info"]
        fmt = record["format"]

        rank, category, reason = classify(record, entries)

        rows.append({
            "Chromosome": record["chrom"],
            "Position": record["pos"],
            "REF": record["ref"],
            "ALT": record["alt"],
            "FILTER": record["filter"],
            "Genotype": fmt.get("GT", "."),
            "DP": fmt.get("DP", "."),
            "GQ": fmt.get("GQ", "."),
            "AD": fmt.get("AD", "."),
            "QC_Flags": get_qc_flags(fmt),
            "VEP_Consequence": field_value(entries, "Consequence"),
            "VEP_Impact": field_value(entries, "IMPACT"),
            "Gene_Symbol": field_value(entries, "SYMBOL"),
            "Gene_ID": field_value(entries, "Gene"),
            "Transcript": field_value(entries, "Feature"),
            "Biotype": field_value(entries, "BIOTYPE"),
            "HGVSc": field_value(entries, "HGVSc"),
            "HGVSp": field_value(entries, "HGVSp"),
            "Canonical": field_value(entries, "CANONICAL"),
            "Variant_Class": field_value(entries, "VARIANT_CLASS"),
            "ClinVar_AlleleID": info.get("ALLELEID", "."),
            "ClinVar_Significance": info.get("CLNSIG", "."),
            "ClinVar_Review_Status": info.get("CLNREVSTAT", "."),
            "ClinVar_Disease": info.get("CLNDN", "."),
            "ClinVar_Disease_IDs": info.get("CLNDISDB", "."),
            "ClinVar_HGVS": info.get("CLNHGVS", "."),
            "ClinVar_Variant_Type": info.get("CLNVC", "."),
            "ClinVar_Molecular_Consequence": info.get("MC", "."),
            "Priority_Rank": rank,
            "Priority_Category": category,
            "Priority_Reason": reason,
        })

    rows.sort(key=lambda row: (
        int(row["Priority_Rank"]),
        row["Chromosome"],
        int(row["Position"]),
        row["REF"],
        row["ALT"],
    ))

    full_file = OUT / "HG002_dev_chr1.prioritized.tsv"
    review_file = OUT / "HG002_dev_chr1.review_queue.tsv"
    secondary_file = OUT / "HG002_dev_chr1.secondary_candidates.tsv"
    quality_file = OUT / "HG002_dev_chr1.quality_followup.tsv"
    summary_file = OUT / "HG002_dev_chr1.prioritization_summary.txt"

    # Higher-priority PASS calls with no current DP/GQ flags.
    review_candidates = [
        row for row in rows
        if row["FILTER"] == "PASS"
        and int(row["Priority_Rank"]) <= 7
    ]

    review = [
        row for row in review_candidates
        if row["QC_Flags"] == "."
    ]

    # All PASS calls with DP/GQ flags are retained for technical follow-up.
    quality_followup = [
        row for row in rows
        if row["FILTER"] == "PASS"
        and row["QC_Flags"] != "."
    ]

    # Lower-priority PASS calls without the current QC flags.
    secondary = [
        row for row in rows
        if row["FILTER"] == "PASS"
        and int(row["Priority_Rank"]) in (8, 9)
        and row["QC_Flags"] == "."
    ]

    for path, data in (
        (full_file, rows),
        (review_file, review),
        (secondary_file, secondary),
        (quality_file, quality_followup),
    ):
        write_tsv(path, data, columns)

    categories = Counter(row["Priority_Category"] for row in rows)
    pass_count = sum(row["FILTER"] == "PASS" for row in rows)
    filtered_count = len(rows) - pass_count

    clinvar_marked = sum(
        row["ClinVar_AlleleID"] != "."
        or row["ClinVar_Significance"] != "."
        for row in rows
    )
    clnsig_count = sum(
        row["ClinVar_Significance"] != "."
        for row in rows
    )

    review_flagged = len(review_candidates) - len(review)

    with open(summary_file, "w") as handle:
        handle.write("CLINVAR-WORKBENCH DEVELOPMENT TRIAGE SUMMARY\n")
        handle.write("============================================\n")
        handle.write(f"Total records: {len(rows)}\n")
        handle.write(f"PASS records: {pass_count}\n")
        handle.write(f"Filtered records: {filtered_count}\n")
        handle.write(f"Records with ClinVar AlleleID and/or CLNSIG: {clinvar_marked}\n")
        handle.write(f"Records with non-missing CLNSIG: {clnsig_count}\n")
        handle.write(f"PASS records with DP/GQ flags: {len(quality_followup)}\n")
        handle.write(f"Focused review queue, no DP/GQ flags: {len(review)}\n")
        handle.write(f"Priority candidates held for QC review: {review_flagged}\n")
        handle.write(f"Secondary PASS candidates, no DP/GQ flags: {len(secondary)}\n")
        handle.write("\nPriority-category counts:\n")
        for category, count in sorted(categories.items()):
            handle.write(f"{category}\t{count}\n")

        handle.write(
            "\nCAUTION: Research/development triage only, not a clinical "
            "interpretation. Rankings are heuristics. DP/GQ flags are "
            "screening warnings, not proof that a call is invalid. "
            "Missing ClinVar evidence does not imply benignity.\n"
        )

    print("\nPriority-category counts:")
    for category, count in sorted(categories.items()):
        print(f"{category}: {count}")

    print(f"\nFocused review queue: {len(review)}")
    print(f"Priority candidates held for QC review: {review_flagged}")
    print(f"PASS records in quality follow-up: {len(quality_followup)}")
    print(f"Secondary clean PASS candidates: {len(secondary)}")

    print("\nOutput files:")
    for path in (full_file, review_file, secondary_file, quality_file, summary_file):
        print(f"{path} ({path.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
