require 'sqlite3'
require 'json'
require 'bio'
require 'fileutils'

#
# References
# * Official specification of GFF3 -- https://github.com/The-Sequence-Ontology/Specifications/blob/master/gff3.md
#

module Ezgff

  class GffDb

    #===
    # sqlite3 schema
    #
    # gff_records (
    #   line_num     integer primary key,
    #   record       text,            # original record
    #   id           text,
    #   parent       text,
    #   seqid        text not null,
    #   source       text,
    #   type         text,
    #   start        integer not null,
    #   end          integer not null,
    #   score        real,
    #   strand       varchar(1),
    #   phase        integer,
    #   attributes   text,
    #   attributes_json json
    # )

    def self.build_db(gff_in, ezdb_base = nil)
      ezdb_base = (ezdb_base || ".")
      ezdb_path = ezdb_base + "/" + File.basename(gff_in) + ".ezdb"
      gff_file = ezdb_path + "/" + File.basename(gff_in)
      Dir.mkdir(ezdb_path)
      File.open(gff_file, "w") do |o|
        File.open(gff_in).each do |l|
          break if /^\#\#FASTA/.match(l)
          ## skip header section
          next if /^\#/.match(l)
          o.puts l
        end
      end
      
  #    FileUtils.cp(gff_in, gff_file)
      sq3_file = gff_file + ".sqlite3"

      ## Create table in sqlite3 RDBMS
      ##   table name: gff_record

      sq3_db = SQLite3::Database.new(sq3_file)

      sql = <<-SQL
      CREATE TABLE gff_records (
        line_num     integer primary key,
        record       text,
        id           text,
        parent       text,
        seqid        text not null,
        source       text,
        type         text,
        start        integer not null,
        end          integer not null,
        score        real,
        strand       varchar(1),
        phase        integer,
        attributes   text,
        attributes_json json
      );
      SQL

      sq3_db.execute(sql)

      ## Read GFF file and insert data into 
      ## the sqlite3 table

      sq3_db.transaction do 
        File.open(gff_file).each_with_index do |l, i|
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
      
          sql = "INSERT INTO gff_records (line_num, record, id, parent, seqid, source, type, start, end, score, strand, phase, attributes, attributes_json)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
          values = [
            i,       # line number
            l.chomp, # raw record
            id,      # ID
            parent,  # parent ID
            a[0],    # seqid
            a[1],    # source
            a[2],    # type
            a[3],    # start
            a[4],    # end
            (a[5] == "." ? nil : a[5]),    # score
            a[6],    # strand
            (a[7] == "." ? nil : a[7]),    # phase
            a[8],    # attributes
            attributes_as_json(l)]
          sq3_db.execute(sql, values)
        end
      end

      ## Indexing the sqlite3 table
      table = "gff_records"
      %w{id parent source type}.each do |col|
        idxname = "index_#{table}_on_#{col}"
        sql = "CREATE INDEX #{idxname} ON #{table}(#{col})"
        sq3_db.execute(sql)
      end

      return ezdb_path

    end

    def self.build_tabix(gff_in)
      ## sort gff by position
      gfffile_sorted = gff_in + ".gz"
      cmd = %Q{(grep ^"#" #{gff_in}; grep -v ^"#" #{gff_in} | sort -t $'\t' -k1,1 -k4,4n) | bgzip > #{gfffile_sorted};}
      STDERR.puts cmd
      system cmd

      cmd = "tabix -p gff #{gfffile_sorted}"
      STDERR.puts cmd
      system cmd
      
      STDERR.puts "#{gfffile_sorted} and #{gfffile_sorted}.tbi were generated."
    end

    def self.attributes_as_json(gffline)
      keys_multi_val_allowed = %{Parent Alias Note Dbxref Ontology_term}

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
      h.each do |key, values|
        if key == "Dbxref2" # dummy (not used currently)
          h3 = Hash.new
          values.each do |val|
            m = /(.+?):/.match(val)
            dbtag = m[1]
            dbval = m.post_match
            h3.update({dbtag => dbval})
          end
          h2[key] = h3
        elsif key == "Ontology_term" || key == "Alias" || key == "Dbxref"
          h2[key] = values
        else
          h2[key] = values.join(",")
        end
      end
      h2.to_json
    end

    def initialize(path)
      @db = SQLite3::Database.new(path)
    end

    def each_record
      sql = "SELECT * FROM gff_records"
      @db.execute(sql).each do |r|
        an = Annotation.new(@db)
        an.build_from_db_record(r)
        yield an
      end
    end

    def get(id)
      sql = %Q{SELECT * FROM gff_records WHERE id=="#{id}";}
  #    puts sql
      res = @db.execute(sql)
      if res.size == 1
        an = Annotation.new(@db)
        an.build_from_db_record(res[0])
        return an
      else
        if res.size >= 2
          raise "multiple hits"
        elsif res.size == 0
          raise "not found: #{id}"
        end
      end
    end

    def get_by_line_number(n)
      sql = %Q{SELECT * FROM gff_records WHERE line_num=="#{n}";}
      res = @db.execute(sql)
      if res.size == 1
        an = Annotation.new(@db)
        an.build_from_db_record(res[0])
        return an
      else
        if res.size >= 2
          raise "multiple hits"
        elsif res.size == 0
          raise "not found: #{id}"
        end
      end
    end

    def search(query, num_limit=100, type=nil)
      sql = %Q{SELECT * FROM  gff_records WHERE id LIKE "%#{query}%" OR parent LIKE "%#{query}%" OR attributes LIKE "%#{query}%" }
      if type
        sql += %Q{ AND type=="#{type}"}
      end
      sql += %Q{ LIMIT #{num_limit} } ;
      STDERR.puts sql
      res = @db.execute(sql)
      res2 = res.map{|r| an = Annotation.new(@db); an.build_from_db_record(r); an}
      res2
    end

    class Annotation

      def initialize(db = nil)
        @db = db
        @seqid
        @source
        @type
        @start
        @end
        @score
        @strand
        @phase
        @attributes
        @id
        @parent_id
        @gffline
      end

      attr_accessor :seqid, :source, :type, :start, :end, :score, :strand, :phase, :attributes
      attr_accessor :id, :parent_id, :gffline, :line_num

      def to_s
        gffline
      end

      def to_hash
        h = {
          'seqid' => seqid,
          'source' => source,
          'type' => type,
          'start' => start,
          'end' => self.end,
          'score' => score,
          'strand' => strand,
          'phase' => phase,
          'line_num' => line_num,
          'id' => id,
          'parent_id' => parent_id,
          'attributes' => attributes
        }
      end

      alias :to_h :to_hash

      def to_json
        self.to_hash.to_json
      end

      def build_from_db_record(sql_result)
        ## sql_result: Array returned by @db.execute(sql)
        v = sql_result
        @seqid = v[4]
        @source  = v[5]
        @type = v[6]
        @start = v[7]
        @end = v[8]
        @score = v[9]
        @strand = v[10]
        @phase = v[11]
        @line_num = v[0]
        @gffline = v[1]
        @id = v[2]
        @parent_id = v[3]
        @attributes = JSON.parse(v[13])
      end

      def parent
        if parent_id
          sql = %Q{SELECT * FROM gff_records WHERE id=="#{parent_id}";}
  #        puts sql
          res = @db.execute(sql)
          an = Annotation.new(@db)
          an.build_from_db_record(res[0])
          return an
        else
          return nil
        end
      end

      def children
        ary = []
        sql = %Q{SELECT * FROM gff_records WHERE parent=="#{id}";}
  #      puts sql
        res = @db.execute(sql)
        res.each do |r|
          an = Annotation.new(@db)
          an.build_from_db_record(r)
          ary << an
        end
        ary
      end

      def descendants
        ary = []
        sql = %Q{WITH RECURSIVE r AS (
          SELECT * FROM gff_records WHERE id=="#{id}"
          UNION ALL
          SELECT gff_records.* FROM gff_records, r WHERE gff_records.parent == r.id
          )
          SELECT * FROM r}
        res = @db.execute(sql)
        res.each do |r|
          an = Annotation.new(@db)
          an.build_from_db_record(r)
          ary << an
        end
        ary
      end

      def ancestors
        ary = []
        sql = %Q{WITH RECURSIVE  ancestor AS (
          SELECT * FROM gff_records WHERE id=="#{id}"
          UNION ALL
          SELECT gff_records.* FROM gff_records, ancestor
          WHERE ancestor.parent = gff_records.id
          )
          SELECT * FROM ancestor;}
        res = @db.execute(sql)
        res.each do |r|
          an = Annotation.new(@db)
          an.build_from_db_record(r)
          ary << an
        end
        ary
      end


      def length
        len = @end - @start + 1
        raise unless len > 0
        return len
      end

      def dbxrefs
        h = Hash.new
        if attributes["Dbxref"]
          attributes["Dbxref"].split(/,/).each do |x|
            m = /(.+?):/.match(x)
            key = m[1]
            val = m.post_match
            h.update({key => val})
          end
        end
        h
      end

    end

  end

end

if __FILE__ == $0
  dbname = ARGV[0]
  query = ARGV[1]
  db = GffDb.new(dbname)
  ann = db.get(query)
  p ann
  puts ann.to_s
  p ann.to_hash
  exit
  db.each_line do |an|
    p an
#    p [an.id, an.seqid, an.start, an.end, an.attributes["protein_id"]]
  end
end