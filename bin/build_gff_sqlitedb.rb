require 'sqlite3'
require 'bio'
require 'json'

def attributes_as_json(gffline)
  gr = Bio::GFF::GFF3::Record.new(gffline.chomp)
  h = Hash.new
  gr.attributes.each do |att|
    k, v = att
    unless h.has_key?(k)
      h[k] = []
    end
    h[k] << v
  end
  h2 = Hash.new
  h.each do |k, v|
    h2[k] = v.join(",")
  end
  h2.to_json
end


gfffile = ARGV[0]
#gfffile = "example_gff/apisum_part.gff3"
#gfffile = "example_gff/ApL_HF_liftover_Refseq.gff"

dbname = gfffile + ".sqlite3"

db = SQLite3::Database.new(dbname)

sql = <<-SQL
CREATE TABLE gff_records (
  line_num     integer primary key,
  record       text,
  id           text,
  parent       text,
  seqname      text not null,
  source       text,
  feature      text,
  start        integer not null,
  end          integer not null,
  score        real,
  strand       varchar(1),
  frame        integer,
  attributes   text,
  attributes_json text
);
SQL

db.execute(sql)

db.transaction do 
  File.open(gfffile).each_with_index do |l, i|
#    puts l
    ## skip FASTA seq section
    break if /^\#\#FASTA/.match(l)

    ## skip header section
    next if /^\#/.match(l)
    gr = Bio::GFF::GFF3::Record.new(l.chomp)
#    p gr.attributes
    id = nil
    id_found = gr.attributes.select{|a| a[0] == "ID"}
    if id_found.size == 1
      id = id_found[0][1]
    elsif id_found.size == 0
      ## do nothing (id = nil)
    elsif id_found > 1
      STDERR.puts gr.attributes
      raise "Multiple IDs found."
    end
    parent =  ((gr.attributes.select{|a| a[0] == "Parent"}[0]) || [])[1]
    a = l.chomp.split(/\t/)

    sql = "INSERT INTO gff_records (line_num, record, id, parent, seqname, source, feature, start, end, score, strand, frame, attributes, attributes_json)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    values = [i, l.chomp, id, parent, 
      a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], 
      attributes_as_json(l)]
    db.execute(sql, values)
  end
end

#===
# create index
table = "gff_records"
%w{id parent source feature}.each do |col|
  idxname = "index_#{table}_on_#{col}"
  sql = "CREATE INDEX #{idxname} ON #{table}(#{col})"
  db.execute(sql)
end
