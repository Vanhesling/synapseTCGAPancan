require(cafr)
require(synapseClient)

clusterAttractorsFromSynapse <- function(synIDs, numGenes=100, strength.pos=10, min.basins=2, datasetTags=NULL, tempDir = tempdir()){
  nf <- length(synIDs)
  if(is.null(datasetTags)){
    datasetTags <- paste("Dataset", sprintf("%03d",1:nf))
  }
  if(length(datasetTags) != nf){
    stop("Length of datasetTags and fileNames must be equal!!!")
  }

  # Load in attractors 
  attractorPool <- list()
  env <- new.env()
  for(fn in 1:nf){
    can <- synIDs[fn]
    tag <- datasetTags[fn]
    syn <- synGet(can, downloadFile=TRUE, downloadLocation=tempDir)
    cat("Processing", tag, "...\n");flush.console()
    nm <- load(getFileLocation(syn), env)[1]
    x <- env[[nm]]
    na <- nrow(x)
    for(i in 1:na){
		o <- order(x[i,], decreasing=TRUE)
		if(min.basins > 0){
		# if the attractor has less than 2 attractees, skip
			if(rownames(x)[i] %in% colnames(x)[o[1:min.basins]]) next
		}
		aid <- paste(tag, sprintf("%03d", i), sep="")
		attractorPool[[aid]] <- Attractor$new(
				id = aid,
				numgenes = numGenes,
				a = x[i,],
				genenames=colnames(x), 
				src=tag,
				qt=strength.pos)
    }
  }

  cat(length(attractorPool), "attractors loaded.\n");flush.console()
  attractorPool <- attractorPool[order(sapply(attractorPool, function(a){a$strength}), decreasing=T)]

  # Calculate all pairwise similarities bewteen attractors
  cat("Caculate all pairwise similarities between attractors and attractor sets...\n");flush.console()
  allPairIdx <- combn(names(attractorPool), 2)
  simList <- apply(allPairIdx, 2, function(pr){
    if(attractorPool[[pr[1]]]$src == attractorPool[[pr[2]]]$src) return (NULL)
    sim <- attractorPool[[pr[1]]]$getOverlapNum( attractorPool[[pr[2]]])
    if(sim < 1) return (NULL)
    return (c(pr[1], pr[2],sim))
  })

  simList <- simList[sapply(simList,function(x){!is.null(x)})]
  o <- order(unlist(sapply(simList, function(x){ as.numeric(as.vector(x[3])) })), decreasing=TRUE)
  simList <- simList[o]

  cnt.clust <- 0

  #clustering attractors
  cat("Clustering attractors...\n");flush.console()
  while(length(simList) > 0){
    p <- simList[[1]]
    cat(p, "\n");flush.console()
    simList <- simList[-1]
    as <- AttractorSet$new(paste("AttractorSet", sprintf("%03d", cnt.clust), sep=""), attractorPool[[p[1]]], nf)
    successMerge <- as$add(attractorPool[[p[2]]])
    if(successMerge){
      attractorPool[[ p[1] ]] <- NULL
      attractorPool[[ p[2] ]] <- NULL
      killIdx <- sapply(simList, function(x){x[1]}) %in% p[1:2] | sapply(simList, function(x){x[2]}) %in% p[1:2]
      if(length(killIdx)>0) simList <- simList[!killIdx]
      addList <- lapply(attractorPool, function(a){
			sim <- as$getOverlapNum( a )
			if(sim < 1) return (NULL)
			return (c(as$id, a$id,sim))
			})
      addList <- addList[sapply(addList,function(x){!is.null(x)})]
      simList <- c(simList, addList)
      if(length(simList) == 0) break
      o <- order(unlist(sapply(simList, function(x){ as.numeric(as.vector(x[3])) })), decreasing=TRUE)
      simList <- simList[o]
		
      attractorPool[[ as$id ]] <- as
      cnt.clust <- cnt.clust + 1
    }
  }


  alist <- attractorPool
  sizes <- unlist(lapply(alist, function(x){if(class(x)=="Attractor") return (1); return(length(x$attractors))}))
  alist[sizes < 6] <- NULL

  topOvlp <- unlist(lapply(alist, function(x){if(class(x) == "Attractor") return (1); return ( x$getGeneTable(1)[1] )}))
  alist <- alist[topOvlp >= 6]

  na <- length(alist)

  for(i in 1:na){
	aa <- alist[[i]]
	if(class(aa)!="AttractorSet") next
	scores <- as.numeric(as.vector(alist[[i]]$getGeneMatrix(5)[,6]))
	alist[[i]]$medStrength <- mean(scores[order(scores, decreasing=T)[1:6]])
  }
  scores <- unlist(lapply(alist, function(x){x$medStrength} ))
  alist <- alist[order(scores, decreasing=T)]
  topOvlp = unlist(lapply(alist, function(x){if(class(x)=="Attractor") return(1); return(x$getGeneTable(1)[1])}))
  alist[topOvlp < 6] = NULL


  return (alist)

}


