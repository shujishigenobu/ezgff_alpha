require 'sqlite3'
require 'json'

class GffDb

  #===
  # sqlite3 schema
  #
  # gff_records (
  #   line_num     integer primary key,
  #   record       text,
  #   id           text,
  #   parent       text,
  #   seqname      text not null,
  #   source       text,
  #   feature      text,
  #   start        integer not null,
  #   end          integer not null,
  #   score        real,
  #   strand       varchar(1),
  #   frame        integer,
  #   attributes   text,
  #   attributes_json text
  # )

  def initialize(path)
    @db = SQLite3::Database.new(path)
  end

  def each_record
    sql = "SELECT * FROM gff_records"
    @db.execute(sql).each do |r|
      an = Annotation.new()
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

  class Annotation

    def initialize(db = nil)
      @db = db
      @seqname
      @source
      @feature
      @start
      @end
      @score
      @strand
      @frame
      @attributes
      @id
      @parent_id
      @gffline
    end

    attr_accessor :seqname, :source, :feature, :start, :end, :score, :strand, :frame, :attributes
    attr_accessor :id, :parent_id, :gffline, :line_num

    def to_s
      gffline
    end

    def to_hash
      h = {
        'seqname' => seqname,
        'source' => source,
        'feature' => feature,
        'start' => start,
        'end' => self.end,
        'score' => score,
        'strand' => strand,
        'frame' => frame,
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
      @seqname = v[4]
      @source  = v[5]
      @feature = v[6]
      @start = v[7]
      @end = v[8]
      @score = v[9]
      @strand = v[10]
      @frame = v[11]
      @line_num = v[0]
      @gffline = v[1]
      @id = v[2]
      @parent_id = v[3]
      @attributes = JSON.parse(v[13])
    end

    def parent
      if parent_id
        sql = %Q{SELECT * FROM gff_records WHERE id=="#{parent_id}";}
        puts sql
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
      puts sql
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
#    p [an.id, an.seqname, an.start, an.end, an.attributes["protein_id"]]
  end
end