## EdgeR
## RNA-seq differential expression
library(limma)
library(edgeR)

# load the counts files and combine into one file
mergecounts=function(name,outname)
{
  count_table=read.table(paste(name[1,1],'_count.txt',sep=''),stringsAsFactors = F,sep='\t')
  count_table=count_table[1:(nrow(count_table)-5),]
  n1=strsplit(name[1,1],'_')[[1]][1]
  n2=strsplit(name[1,1],'_')[[1]][2]
  n=paste(n1,n2,sep='_')
  colnames(count_table)=c('gene',n)
  for (i in 2:72)
  {
    tmp=read.table(paste(name[i,1],'_count.txt',sep=''),stringsAsFactors = F,sep='\t')
    tmp=tmp[1:(nrow(tmp)-5),]
    n1=strsplit(name[i,1],'_')[[1]][1]
    n2=strsplit(name[i,1],'_')[[1]][2]
    n=paste(n1,n2,sep='_')
    colnames(tmp)=c('gene',n)
    count_table=merge(count_table,tmp,by='gene')
  }
  write.table(count_table,outname,sep='\t',col.names = T,row.names = F,quote=F)
}

##
# load the count table generated by htseq-count
x <- read.delim("count/htseq_count_merged.txt",row.names = 'gene')
group <- factor(rep(1:36, each=2))
y <- DGEList(counts=x,group=group)

# load the information table
#targets=read.delim('~/Desktop/rnaseq/rnaseq_timecourse.txt',row.names = 1)
#group <- factor(paste(targets$Treat,targets$Time,sep="."))
#cbind(targets,group=Group)
#design <- model.matrix(~0+group)
#colnames(design) <- levels(group)
#fit <- glmFit(y, design)

# filter out lowly expressed genes
#Users should also filter with count-per-million (CPM) rather than filtering on the counts directly, as the latter does not account for differences in library sizes between samples.
# a CPM of 1 corresponds to a count of 6-7 in the smallest sample
# Usually a gene is required to have a count of 5-10 in a library to be considered expressed in that library.
# This ensures that a gene will be retained if it is only expressed in both samples in group 2.
keep <- rowSums(cpm(y)>1) >= 2
y <- y[keep, , keep.lib.sizes=FALSE]

# Normalization
# The calcNormFactors function normalizes for RNA composition by finding a set of scaling factors for the library sizes that minimize the log-fold changes between the samples for most genes.
y <- calcNormFactors(y)
y <- estimateCommonDisp(y,verbose=T)
#y$samples

# Estimating dispersions
# load the information table
targets=read.delim('rnaseq_timecourse.txt',row.names = 1)
#Group <- factor(paste(targets$Treat,targets$Time,sep="."))
#design <- model.matrix(~0+Group)
#colnames(design) <- levels(Group)
design <- model.matrix(~Treat + Time + Treat:Time, data=targets)

# Testing for DE genes
fit <- glmFit(y, design)


#To compare 2 vs 1:
lrt.2vs1 <- glmLRT(fit, coef=2)
topTags(lrt.2vs1)
t=lrt.2vs1$table
t.01=t[which(t[,'PValue']<=0.01),]
write.table(t.01,'PM263_genes.txt',sep='\t',col.names = T,row.names = T,quote=F)
t=t[row.names(t)!='EBNA',]
with(t, plot(logFC, -log10(PValue), pch=20,main="Volcano plot"))
# To compare 3 vs 1:
lrt.3vs1 <- glmLRT(fit, coef=3)
topTags(lrt.3vs1)
t=lrt.3vs1$table
t.01=t[which(t[,'PValue']<=0.01),]
# To compare 4 vs 1:
lrt.4vs1 <- glmLRT(fit, coef=4)
topTags(lrt.4vs1)
t=lrt.4vs1$table
t.01=t[which(t[,'PValue']<=0.01),]
# To compare 5 vs 1:
lrt.5vs1 <- glmLRT(fit, coef=5)
topTags(lrt.5vs1)
t=lrt.5vs1$table
t.01=t[which(t[,'PValue']<=0.01),]
# To compare 6 vs 1:
lrt.6vs1 <- glmLRT(fit, coef=6)
topTags(lrt.6vs1)
t=lrt.6vs1$table
t.01=t[which(t[,'PValue']<=0.01),]
# To compare 3 vs 2:
lrt.3vs2 <- glmLRT(fit, contrast=c(0,-1,1))
# To find genes different between any of the groups:
lrt <- glmLRT(fit, coef=c(3,5))
topTags(lrt)

#To perform quasi-likelihood F-tests:
# To apply the QL method to the above example and compare 2 vs 1:
fit <- glmQLFit(y, design)
qlf.2vs1 <- glmQLFTest(fit, coef=2)
topTags(qlf.2vs1)

# log2-fold-changes for 1 vs 2 are significantly greater than 1
fit <- glmFit(y, design)
tr <- glmTreat(fit, coef=2, lfc=1)
topTags(tr)

# Gene ontology (GO) and pathway analysis
qlf <- glmQLFTest(fit, coef=2)
go <- goana(qlf, species="Hs")
topGO(go, sort="up")
keg <- kegga(qlf, species="Hs")
topKEGG(keg, sort="up")

#################################################################
##  length of the genes
genes=read.table('genes_with_l1.gtf',sep='\t',stringsAsFactors = F,quote="\'")[,c(1,3,4,5,9)]
genes=subset(genes,V3=='exon')
split=function(x){strsplit(x,split='"')[[1]][2]}
genes[,5]=apply(data.frame(genes[,5]),1,split)
u=unique(genes[,5])
len=matrix(0,nrow=length(u),ncol=2)
for (i in 1:length(u))
{
  tmp=subset(genes,V9==u[i])
  len[i,1]=u[i]
  len[i,2]=sum(tmp[,4]-tmp[,3])
}
write.table(len,'gene_length.txt',quote=F,col.names=F,row.names=F,sep='\t')

########################################################################
# calculate FKPM
x <- read.delim("count/htseq_count_merged.txt",row.names = 'gene')
len=read.table('gtf/gene_length.txt',sep='\t',stringsAsFactors = F)
colsums=colSums(x)
out=data.frame(matrix(0,nrow=nrow(x),ncol=ncol(x)))
rownames(out)=rownames(x)
colnames(out)=colnames(x)
for (i in 1:nrow(x))
{
  len_tmp=subset(len,V1==rownames(x)[i])[,2]
  out[i,]=(x[i,]*1000000000)/(colsums*len_tmp)
  print (i)
}
write.table(out,'FKPM.txt',quote=F,sep='\t',col.names = T,row.names = T)

########################################################################




