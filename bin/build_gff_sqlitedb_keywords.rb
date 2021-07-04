require 'sqlite3'
require 'bio'
require 'json'
require './gffsqlitedb'

def insert_data(record, key, db_kw)
  rec = record
  att = rec.attributes
  xdb = rec.dbxrefs
  if val = att[key]
    sql = "INSERT INTO gff_keywords (line_num, key, value) VALUES (?, ?, ?)"
    values = [rec.line_num, key, val]
    puts sql
    p values
    db_kw.execute(sql, values)
  end
end

def insert_data_dbxref(record, key, db_kw)
  rec = record
  xdb = rec.dbxrefs
  val = xdb[key]
  sql = "INSERT INTO gff_keywords (line_num, key, value, category) VALUES (?, ?, ?, ?)"
  values = [rec.line_num, key, val, "Dbxref"]
  puts sql
  p values
  db_kw.execute(sql, values)
end

gfffile = ARGV[0]

db_file = gfffile + ".sqlite3" # altready built
#db_keywards = gfffile + ".keywords.sqlite3"

gffdb = GffDb.new(db_file) # altready built
db = SQLite3::Database.new(db_file)

sql = <<-SQL
CREATE TABLE gff_keywords (
  id           integer primary key,
  line_num     integer,
  key          text not null,
  value        text,
  category     text
);
SQL

db.execute(sql)

db.transaction do 
  gffdb.each_record do |r|
    insert_data(r, "Name", db)
    insert_data(r, "gbkey", db)
    insert_data(r, "gene", db)
    insert_data(r, "product", db)
    insert_data(r, "transcript_id", db)
    r.dbxrefs.keys.each do |k|
      insert_data_dbxref(r, k, db)
    end
  end
end

#===
# create index
table = "gff_keywords"
%w{id line_num key value}.each do |col|
  idxname = "index_#{table}_on_#{col}"
  sql = "CREATE INDEX #{idxname} ON #{table}(#{col})"
  db.execute(sql)
end
