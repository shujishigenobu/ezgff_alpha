#!/usr/bin/env ruby

require_relative '../lib/ezgff'
require 'thor'

include Ezgff

gff_file = ARGV[0]

File.open(gff_file).each_with_index do |l, i|
  puts l
  ## skip FASTA seq section
  break if /^\#\#FASTA/.match(l)
end