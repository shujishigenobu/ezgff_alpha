gfffile = ARGV[0]
gfffile = "example_gff/apisum_part.gff3"
#gfffile = "example_gff/ApL_HF_liftover_Refseq.gff"

#=== sort gff by position
gfffile_sorted = gfffile + ".gz"
cmd = %Q{(grep ^"#" #{gfffile}; grep -v ^"#" #{gfffile} | sort -k1,1 -k4,4n) | bgzip > #{gfffile_sorted};}
system cmd

cmd = "tabix -p gff #{gfffile_sorted}"
system cmd

STDERR.puts "#{gfffile_sorted} and #{gfffile_sorted}.tbi were generated."