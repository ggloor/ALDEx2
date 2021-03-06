################
#  This script sums reads per functional unit using the following steps
#  1) Take Aitchison mean for all readcounts per refseq, this is a centered log-ratio value
#  2) Divide by length of refseq
#  3) Divide by sum of all transformed counts for the sample (column) - This makes everything sum to 1
#  4) Multiply by the size factor (total reads for the sample)
#  5) Sum by functional unit, i.e., seed subsys4, or KEGG KO or any other functional identifier
#  6) rounds the final values to get integer counts
###############

###############
#  INPUT file format A
#
#  column 1 contains accession number, gene name, for the feature, etc.
#  column 2 contains the length of the feature in nucleotides
#  columns 3-(n-1) contain the read counts per feature
#  column n contains the function name. This can be plain text (K00001), a number, etc
#  alternatively, there could be more than one column before the feature read count columns
#
#  INPUT file format B
#
#  column 1 contains accession number, gene name, for the feature, etc.
#  column 2 contains alternate accession number. We use protein ID
#  column 3 contains the length of the feature in nucleotides
#  columns 4-(n-1) contain the read counts per feature
#  column n contains the function name. This can be plain text (K00001), a number, etc
#  alternatively, there could be more than one column before the feature read count columns
#
#############

#############
#  INVOCATION and OUTPUT
#
#  if input format A - one annotation column (i.e., length is column 2)
#  R CMD BATCH '--args in_filename out_filename 3' SumByAitchisonTransform.r log.txt 
#
#  if input format B - two annotation columns (i.e., length is column 3)
#  R CMD BATCH '--args in_filename out_filename 4' SumByAitchisonTransform.r log.txt
#
#  OUTPUT is to a user-defined file
#############

args <- commandArgs(trailingOnly = TRUE)

inputFile <- as.character(args[1])
outputFile <- as.character(args[2])
firstsubjectindex <- as.numeric(args[3])

# perform Aitchison transform on one subject (ie. set of counts from one sample)
# Input is a vector of non-negative integer counts.
# Output is a probability vector of expected frequencies.
# If log-frequencies are requested, the uninformative subspace is removed.
# this function was generated by Andrew Fernandes and modified by Ruth Wong
	
# Example usage: If we observe 5 heads and 3 tails from coin-flipping,
#                then the expected proportion of heads versus tails
#                is 'aitchison.mean( c(5,3) )'.

aitchison.mean <- function( n, log=FALSE ) {
	
    n <- round( as.vector( n, mode="numeric" ) )
    if ( any( n < 0 ) ) stop("counts cannot be negative")

#add pseudocount
    a <- n + 0.5
    sa <- sum(a)

#digamma is log space
#sample from digamma dist
    log.p <- digamma(a) - digamma(sa)
#subspace removal
    log.p <- log.p - mean(log.p)
		
    if ( log ) return(log.p)
	
    p <- exp( log.p - max(log.p) )
    p <- p / sum(p)
    return(p)
}


# file should have columns for refseq_id, length, subjects, and grouping, in that order
originaldata <- read.table(inputFile, header = TRUE, sep= "\t", stringsAsFactors=F, quote = "", check.names = FALSE, comment.char = "")

# d is data that will be messed with. Original data is left alone, just in case.
d <- originaldata

#setting variables with information about the number and indices of the subjects

lastsubjectindex = ncol(d) - 1 
reads <- originaldata[,firstsubjectindex:lastsubjectindex]
group <- originaldata[,ncol(originaldata)] #last column
nreads <- apply(reads, 2, sum)
length <- originaldata[ ,firstsubjectindex -1]

# Aitchison transform, includes summing data to 1
d <- apply(reads, 2, function(x){aitchison.mean(x)})

# divide by length
z <- d/length

#  close the data
z.corr <- apply(z, 2, function(x) {x/sum(x)})

#  multiply the values back out to the number of counts
for(i in 1:ncol(z.corr) ){
	z.corr[,i] <- z.corr[,i] * as.numeric(nreads[i])
}

#  group by function
agg <- aggregate(z.corr, by = list(group), FUN = "sum")

#  get integer values
agg.round <- round(agg[ ,2:ncol(agg)])

#  add back the function names
rownames(agg.round) <- agg[,1]

#  print the sucker
write.table(agg.round, file = outputFile, append = FALSE, quote = FALSE, sep = "\t", col.names=NA)

