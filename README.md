# ezgff_alpha

## What is ezgff_alpha

## Pre-requisites

  * sqlite3

## Install


## Quick start

Build database from GFF3 file.

```bash
ezgff build in.gff3
```

Retrieve GFF3 reacod by ID.

```bash
ezgff view data.ezdb cds-WP_010895901.1 --with=ancestors
```

```
ezgff view data.ezdb cds-WP_010895901.1 --with=ancestors --format=json |jq
```

examples to use jq

```
ezgff_alpha/bin/ezgff view GCF_000009605.1_ASM960v1_genomic.gff.ezdb cds-WP_010895901.1  --with=ancestors --format=json  |jq -r '.gff_records | map(select(.type == "gene"))[0] | [.seqid, .start, .end, .attributes.gene] |@csv'
```
