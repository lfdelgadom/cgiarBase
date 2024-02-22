bindObjects <- function(
    object1= NULL,
    object2= NULL,
    verbose=FALSE
){
  ## THIS FUNCTION ROW BINDS TWO MARKER MATRICES AND ASSOCIATED TABLES
  if(is.null(object1)){stop("Please provide the name of the file to be used for analysis", call. = FALSE)}
  if(is.null(object2)){stop("Please provide the name of the file to be used for analysis", call. = FALSE)}
  
  base0 <- list(pheno=data.frame(), pedigree=data.frame(), geno=data.frame(), weather=data.frame(), qtl=data.frame()  )
  mainElements <- list(base0,base0,base0); names(mainElements) <- c("data", "metadata", "modifications")
  mainElements$status <- mainElements$modeling <- mainElements$metrics <- mainElements$predictions <- data.frame()
  ###################################
  # loading the dataset
  for(iMain in 1:length(mainElements)){ #  for each element of data, metadata, modifications, modeling, status, etc ... bind   iMain=3
    if( names(mainElements)[iMain] %in% c("data","metadata","modifications") ){ # user may not have same format
      subItems <- names(mainElements[[names(mainElements)[iMain]]])
      for(iSub in 1:length(mainElements[[names(mainElements)[iMain]]]) ){ # for each nested element
        if(names(mainElements)[iMain] == "data"){ # this are complex, data can be in completely different formats, column names, etc
          # we have to modify both data and metadata at the same time
          if(subItems[iSub] %in% c("pheno","pedigree","weather","qtl") ){
            # bind data tables
            provPheno1 <- object1$data[[subItems[iSub]]][ ,object1$metadata[[subItems[iSub]]]$value, drop=FALSE]
            if(!is.null(provPheno1)){
              colnames(provPheno1) <- cgiarBase::replaceValues(Source = colnames(provPheno1), 
                                                               Search = object1$metadata[[subItems[iSub]]]$value[object1$metadata[[subItems[iSub]]]$parameter != "trait"], 
                                                               Replace = object1$metadata[[subItems[iSub]]]$parameter[object1$metadata[[subItems[iSub]]]$parameter != "trait"])
            }
            provPheno2 <- object2$data[[subItems[iSub]]][ ,object2$metadata[[subItems[iSub]]]$value, drop=FALSE]
            if(!is.null(provPheno2)){
              colnames(provPheno2) <- cgiarBase::replaceValues(Source = colnames(provPheno2), 
                                                               Search = object2$metadata[[subItems[iSub]]]$value[object2$metadata[[subItems[iSub]]]$parameter != "trait"], 
                                                               Replace = object2$metadata[[subItems[iSub]]]$parameter[object2$metadata[[subItems[iSub]]]$parameter != "trait"])
            }
            allNames <- unique(c(colnames(provPheno1), colnames(provPheno2)))
            commonNames <- intersect(colnames(provPheno1), colnames(provPheno2)) #use intersect in a list of vectors
            differentNames <- c( setdiff(colnames(provPheno1), colnames(provPheno2)) , setdiff(colnames(provPheno2), colnames(provPheno1)) )
            if(!is.null(provPheno1)){
              dfg1 <- data.frame(matrix(ncol = length(allNames), nrow = nrow(provPheno1))); colnames(dfg1) <- allNames
              dfg1[,colnames(provPheno1)] <- provPheno1
              dfg1 <- dfg1[,c(commonNames,differentNames), drop=FALSE]
            }else{dfg1 <- data.frame()}
            if(!is.null(provPheno2)){
              dfg2 <- data.frame(matrix(ncol = length(allNames), nrow = nrow(provPheno2))); colnames(dfg2) <- allNames
              dfg2[,colnames(provPheno2)] <- provPheno2
              dfg2 <- dfg2[,c(commonNames,differentNames), drop=FALSE]
            }else{dfg2 <- data.frame()}
            newData <- unique( rbind(dfg1,dfg2) )
            rownames(newData) <- NULL
            mainElements[[names(mainElements)[iMain]]][[subItems[iSub]]] <- newData
            # update metadata
            newMetadata <- rbind(object1$metadata[[subItems[iSub]]],object2$metadata[[subItems[iSub]]])
            newMetadata <- newMetadata[which(!duplicated(newMetadata$parameter)),]
            newMetadata$value <- newMetadata$parameter
            mainElements$metadata[[subItems[iSub]]] <- newMetadata 
          }else if(subItems[iSub] == "geno"){ # if we need to fill the genotype slot
            if( !is.null(object1$data$geno) &  !is.null(object2$data$geno) ){ # ifboth objects have genotype data
              uniqueMarkers <- unique( c( colnames(object1$data$geno), colnames(object1$data$geno) ))
              # only keep new individuals, ignore the others
              newInds <- setdiff( rownames(object2$data$geno), rownames(object1$data$geno) )
              object2$data$geno <- object2$data$geno[newInds, ]
              uniqueIndividuals <- unique( c( rownames(object1$data$geno), rownames(object2$data$geno) ))
              Mx <- matrix(NA, nrow=length(uniqueIndividuals), ncol=length(uniqueMarkers) ) # new marker matrix
              rownames(Mx) <- uniqueIndividuals; colnames(Mx) <- uniqueMarkers
              metaX <- data.frame(marker=uniqueMarkers, chr=NA, pos=NA, refAllele=NA, altAllele=NA ) # new metadata for geno
              ploidyInObject2 <- round(diff(range( object2$data$geno, na.rm=TRUE)))
              for(iMarker in uniqueMarkers){ # for each unique marker  iMarker = uniqueMarkers[1]
                print(iMarker)
                presentIn1 <- intersect(colnames(object1$data$geno), iMarker)
                presentIn2 <- intersect(colnames(object2$data$geno), iMarker)
                if( (length(presentIn1)+length(presentIn2)) == 2 ){ # if marker is present in both objects
                  meta1 <- object1$metadata$geno[object1$metadata$geno$marker == iMarker,]
                  meta2 <- object2$metadata$geno[object2$metadata$geno$marker == iMarker,]
                  differentialAlleles <- setdiff(c(meta1$refAllele, meta1$altAllele), c(meta2$refAllele, meta2$altAllele) )
                  if(length(differentialAlleles) > 0){ # multi-allelic marker, we set to NA all the calls
                    Mx[,iMarker] <- NA # we ignore this ones
                    metaX[metaX$marker == iMarker,] <- meta1
                    metaX[metaX$marker == iMarker,"refAllele"] <- paste(meta1$refAllele, meta2$refAllele, collapse = ",")
                    metaX[metaX$marker == iMarker,"altAllele"] <- paste(meta1$altAllele, meta2$altAllele, collapse = ",")
                  }else{ # confirmed bi-allelic marker, we proceed
                    if(meta1$refAllele == meta2$refAllele){ # we have same reference allele, we do a straigth bind
                      Mx[,iMarker] <- c(object1$data$geno[,iMarker], object2$data$geno[,iMarker])
                    }else{ # we have different reference allele, transform marker matrix
                      Mx[,iMarker] <- c(object1$data$geno[,iMarker], (object2$data$geno[,iMarker] - ploidyInObject2) ) 
                    }
                    metaX[metaX$marker == iMarker,] <- meta1
                  }
                }else{ # if marker is only present in one object
                  if(length(presentIn1) > 0){ # marker is in object 1
                    Mx[,iMarker] <- c(object1$data$geno[,iMarker], rep(NA, nrow(object2$data$geno) ) )
                    metaX[metaX$marker == iMarker,] <-  object1$metadata$geno[object1$metadata$geno$marker == iMarker,]
                  }else if(length(presentIn2) > 0){ # marker is in object 2
                    Mx[,iMarker] <- c( rep(NA, nrow(object1$data$geno) ), object2$data$geno[,iMarker] )
                    metaX[metaX$marker == iMarker,] <-  object2$metadata$geno[object1$metadata$geno$marker == iMarker,]
                  }
                } # end of:  if( (length(presentIn1)+length(presentIn2)) == 2)
              } # end of:  for(iMarker in uniqueMarkers)
              mainElements[[names(mainElements)[iMain]]][[subItems[iSub]]] <- Mx # store new markers
              mainElements$metadata[[subItems[iSub]]] <- metaX # store new metadata
            }else{ # only one object has genotype data
              if(!is.null(object1$data$geno)){ # markers are in object 1
                mainElements[[names(mainElements)[iMain]]][[subItems[iSub]]] <- object1$data$geno
                mainElements$metadata[[subItems[iSub]]] <- object1$metadata$geno
              }else if(!is.null(object2$data$geno)){ # markers are in object 2
                mainElements[[names(mainElements)[iMain]]][[subItems[iSub]]] <- object2$data$geno
                mainElements$metadata[[subItems[iSub]]] <- object2$metadata$geno
              }
            } # end of: if( !is.null(object1$data$geno) &  !is.null(object2$data$geno) )
          } # end of: if(subItems[iSub] %in% c("pheno","pedigree","weather","qtl") )
        }else if(names(mainElements)[iMain] == "modifications"){ #  modifications  can be easily binded, is just long format tables
          mainElements[[names(mainElements)[iMain]]][[subItems[iSub]]] <-  unique( rbind( object1[[names(mainElements)[iMain]]][[subItems[iSub]]], object2[[names(mainElements)[iMain]]][[subItems[iSub]]] ) )
        }
      } # end of: for(iSub in 1:length(mainElements[[names(mainElements)[iMain]]]) )
    }else{ # user wants to do a pure row bind (predictions, metrics, modeling, status tables)
      mainElements[[names(mainElements)[iMain]]] <-  unique( rbind( object1[[names(mainElements)[iMain]]], object2[[names(mainElements)[iMain]]] ) )
    }
  }
  
  return(mainElements)
}