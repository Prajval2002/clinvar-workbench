#!/usr/bin/env bash
set -euo pipefail

WORK="$HOME/clinngs-work"
SAMPLE="HG002_dev_chr1"
VARIANTS="$WORK/results/$SAMPLE/variants"
OUT="$WORK/results/$SAMPLE/annotation"
IMAGE="ensemblorg/ensembl-vep:release_116.1"
BCFTOOLS="quay.io/biocontainers/bcftools:1.22--h3a4d415_0"

mkdir -p "$OUT"

INPUT="$VARIANTS/$SAMPLE.filtered.vcf.gz"
RAW="$OUT/$SAMPLE.vep.new.vcf"
TEMP_GZ="$OUT/$SAMPLE.vep.new.vcf.gz"
FINAL="$OUT/$SAMPLE.vep.vcf.gz"

test -s "$INPUT" || {
    echo "ERROR: Missing input VCF: $INPUT" >&2
    exit 1
}

echo "Running VEP database-mode annotation."
echo "This uses the remote Ensembl database and may take time."
echo "Log: $OUT/vep.log"

rm -f "$RAW" "$TEMP_GZ" "$TEMP_GZ.tbi"

if ! timeout 45m docker run --rm \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -v "$VARIANTS:/input:ro" \
    -v "$OUT:/output" \
    "$IMAGE" \
    vep \
      --input_file "/input/$SAMPLE.filtered.vcf.gz" \
      --output_file "/output/$SAMPLE.vep.new.vcf" \
      --format vcf \
      --vcf \
      --database \
      --species homo_sapiens \
      --assembly GRCh38 \
      --symbol \
      --canonical \
      --hgvs \
      --variant_class \
      --pick \
      --no_stats \
      --verbose \
      2>&1 | tee "$OUT/vep.log"
then
    echo "ERROR: VEP failed or exceeded the 45-minute limit." >&2
    echo "Inspect $OUT/vep.log before retrying." >&2
    exit 1
fi

test -s "$RAW" || {
    echo "ERROR: VEP did not produce a non-empty VCF." >&2
    exit 1
}

docker run --rm \
    --user "$(id -u):$(id -g)" \
    -v "$OUT:/out" \
    "$BCFTOOLS" \
    bcftools view -Oz \
      -o "/out/$SAMPLE.vep.new.vcf.gz" \
      "/out/$SAMPLE.vep.new.vcf"

docker run --rm \
    --user "$(id -u):$(id -g)" \
    -v "$OUT:/out" \
    "$BCFTOOLS" \
    bcftools index -f -t "/out/$SAMPLE.vep.new.vcf.gz"

# Replace the previous annotation only after the new file exists.
docker run --rm \
    -v "$VARIANTS:/variants:ro" \
    -v "$OUT:/out:ro" \
    "$BCFTOOLS" \
    sh -eu -c '
      input_count=$(bcftools view -H "/variants/HG002_dev_chr1.filtered.vcf.gz" | wc -l)
      output_count=$(bcftools view -H "/out/HG002_dev_chr1.vep.new.vcf.gz" | wc -l)
      [ "$input_count" -eq "$output_count" ] || {
        echo "Record-count mismatch: input=$input_count output=$output_count" >&2
        exit 1
      }
      bcftools view -h "/out/HG002_dev_chr1.vep.new.vcf.gz" |
        grep -q "^##INFO=<ID=CSQ,"
    '

mv -f "$TEMP_GZ" "$FINAL"
mv -f "$TEMP_GZ.tbi" "$FINAL.tbi"
rm -f "$RAW"

echo "VEP annotation validated:"
echo "$FINAL"
ls -lh "$FINAL" "$FINAL.tbi"
