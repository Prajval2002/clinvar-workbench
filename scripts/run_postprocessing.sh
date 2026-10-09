#!/usr/bin/env bash
set -euo pipefail

BASE="$HOME/clinngs-work"
SAMPLE="HG002_dev_chr1"
OUT="$BASE/results/$SAMPLE/annotation"
CLINVAR="$BASE/reference/GRCh38/clinvar/clinvar.chr.vcf.gz"
VARIANTS="$BASE/results/$SAMPLE/variants"
IMAGE="quay.io/biocontainers/bcftools:1.22--h3a4d415_0"

test -s "$VARIANTS/$SAMPLE.filtered.vcf.gz"
test -s "$OUT/$SAMPLE.vep.vcf.gz"
test -s "$CLINVAR"
test -s "$CLINVAR.tbi"

docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$BASE/reference/GRCh38/clinvar:/clinvar:ro" \
  -v "$VARIANTS:/variants:ro" \
  -v "$OUT:/out" "$IMAGE" \
  bcftools annotate \
  -a /clinvar/clinvar.chr.vcf.gz \
  -c INFO/ALLELEID,INFO/CLNSIG,INFO/CLNREVSTAT,INFO/CLNDN,INFO/CLNDISDB,INFO/CLNHGVS,INFO/CLNVC,INFO/MC \
  -Oz -o "/out/$SAMPLE.clinvar.vcf.gz" \
  "/variants/$SAMPLE.filtered.vcf.gz"

docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$OUT:/out" "$IMAGE" \
  bcftools index -f -t "/out/$SAMPLE.clinvar.vcf.gz"

python3 scripts/prioritize_variants.py
python3 scripts/generate_report.py

echo "Post-processing complete."
ls -lh "$OUT/$SAMPLE.clinvar_workbench_report.html"
