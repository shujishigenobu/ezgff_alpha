# ezgff

## What is ezgff?

Utilities for GFF3, the genome annotation format. Useful to explore the gene model features.


## Pre-requisites

  * Sqlite3
  * Ruby

## Install

```bash
gem install ezgff
```

## Quick start

ezgff provides the command line interface.

You need build an ezgff database from the gff3 file first by using 'build' subcommand. Once you built ezgff db, you can search and retrieve data from the database by using 'search' and 'view' subcommands.

### Build database from GFF3 file.

```bash
ezgff build gff3_file
```

This command generates gff3_file.ezdb directory which is the ezgff database that will be specified when you use view and search subcommands.

### Retrieve GFF3 reacod by ID.

```
ezgff view DB ID 
```

```
ezgff view DB ID --with=ancestors
```

GFF lines with the ID are displayed.

Data can be formated in JSON. Below are examples to work with jq.

```
ezgff view data.ezdb cds-WP_010895901.1 --with=ancestors --format=json |jq
```

More complicated example
```
ezgff view GCF_000009605.1_ASM960v1_genomic.gff.ezdb cds-WP_010895901.1  --with=ancestors --format=json \
 |jq -r '.gff_records | map(select(.type == "gene"))[0] | [.seqid, .start, .end, .attributes.gene] \
 |@csv'
```

## FAQ
### Can I use GFF2 or GTF for ezgff?
Ans.

No. ezgff takes GFF3 format only. GFF2/GTF can be converted to GFF3 easily. gffread and other tools can be used for conversion.

