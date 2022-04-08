require_relative '../lib/ezgff'
include Ezgff

sqlite_path = ARGV[0] # "../../gene_models.gff3.ezdb/gene_models.gff3.sqlite3"
db = GffDb.new(sqlite_path)

db.each_record do |rec|
  if rec.type == "mRNA" || rec.type == "lnc_RNA" || rec.type == "rRNA"
#    puts [rec.seqid, rec.start, rec.strand, rec.type, rec.id].join("\t")
    puts [rec.id, rec.parent_id].join("\t")
  end

end
