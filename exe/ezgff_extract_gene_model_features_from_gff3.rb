#!/usr/bin/env ruby

require_relative '../lib/ezgff'
# require 'thor'

include Ezgff

def path_to_root(ary, pdata)
  #  p ary
  #  p pdata
    if par = pdata[ary.last]
      newary = [ary, par].flatten
      path_to_root(newary, data)
    else
      return ary
    end
  end

def descendant_paths(paths, cdata)
  #  puts "input:"
  #  p paths
    if  paths.map{|pa| cdata[pa.last].size}.all?{|v| v == 0}
      return paths
    else
      newpaths = []
      paths.each do |pa|
  #p      pa
  #p      cdata[pa.last][:children]
        if cdata[pa.last].size > 0
          cdata[pa.last].each do |c|
            newary = [pa, c].flatten
            newpaths << newary
          end
        else
          newpaths << pa
        end
      end
  #    puts  "generated:"
  #    p newpaths
      descendant_paths(newpaths, cdata)
    end
end

gff_file = ARGV[0]
out_file = ARGV[1]
outfile_not_found_parents = out_file + ".ParentsNoteFound.txt"

include_features = ["gene", "mRNA", "exon", "CDS", "five_prime_UTR", "three_prime_UTR", "ncRNA","polyA_site", "pre_miRNA", "pseudogene", "rRNA", "snRNA", "snoRNA", "tRNA"]
exclude_features = ["match", "match_part", "orthologous_to", "paralogous_to", "oligo", "sgRNA"]

data = {}   # key: line_num (int); value: gff_feature (Bio::GFF::GFF3::Record)
id2ln = {}  # key: ID; value: line_num (reference to key of data)
pdata = {}  # Hash to store parent relations
            # key: line_num (int); value: ID

STDERR.puts "#{Time.now} Loading data..."            
File.open(gff_file).each_with_index do |l, i|
  STDERR.print "#{i} lines loaded\r" if i % 100000 == 0

  #    puts l
  a = l.chomp.split(/\t/)
#  next if exclude_features.include?(a[2])
  next unless include_features.include?(a[2])
  ## skip FASTA seq section
  break if /^\#\#FASTA/.match(l)

  ## skip header section
  next if /^\#/.match(l)
  gr = Bio::GFF::GFF3::Record.new(l.chomp)
  data[i] = gr

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
  id2ln[id] = i
end

STDERR.puts "#{Time.now} Loading data: done."
STDERR.puts "parent-children relations are beeing analyzed..."


notfound = []
data.each do |i, v|
  gr = v
  parent =  ((gr.attributes.select{|a| a[0] == "Parent"}[0]) || [])[1]
  if parent
    begin
      pdata[i] = id2ln.fetch(parent)
    rescue
      notfound << [i, parent]
    end
  else
    pdata[i] = nil
  end
end
STDERR.puts "parent database were created.\nchildren database is being created..."

require 'pp'

#p data
#p id2ln
#pp pdata

## build children data from pareint data (pdata)
cdata = Hash.new()
## init cdata
pdata.each do |k, v|
  unless cdata.has_key?(k)
    cdata[k] = []
  end
end
pdata.each do |k, v|
  if v
    parent = v
    cdata[v] << k
  end
end

#pp cdata
STDERR.puts "children databse created."
STDERR.puts "parent-children databases were successfully created."

STDERR.puts "gene and descendant features are being extracted..."

passed_paths = []
data.keys.sort.each do |i|
  gr = data[i]
  if gr.feature == "gene"
#    puts gr 
  passed_paths << descendant_paths([[i]], cdata)
  end
#  break if i > 100
end

#p passed_paths
File.open(out_file, "w") do |o|
  passed_paths.flatten.sort.uniq.each do |i|
      o.puts  data[i]
  end
end

STDERR.puts "target features were successfully extracted."

File.open(outfile_not_found_parents, "w") do |o|
  notfound.each do |i, parent|
    o.puts [i, parent, data[i]].join("\t")
  end
end