cat("Read and set up MNIST data:\n")
system.time(source("mnist_read.R"))
source("../code/flexiblas_setup.r")
setback("OPENBLAS")
  
#' svdmod
#' 
#' Computes SVD for each image label in training data
#' Returns SVDs truncated to either k components or percent variability
#' 
svdmod = function(data, labels, k = NULL, pct = NULL, plots = FALSE) {
  ## trains svd model for each label

  if(is.null(k) & is.null(pct)) 
    stop("svdmod: At least one of k and pct must be provided")
  
  ulabels = unique(labels)
  models = setNames(vector("list", length(ulabels)), ulabels)
  
  ## train on each label data
  for(label in ulabels) {
    labdat = unname(as.matrix(data[labels == label, ]))
    udv = La.svd(labdat)
    
    if(!is.null(k)) { # k components
      ik = 1:k
    } else { # pct variability
      cvar = cumsum(udv$d^2)
      ik = 1:(which(100*cvar/cvar[length(cvar)] >= pct))[1]
    }
    mod = list(d = udv$d[ik], u = udv$u[, ik], vt = udv$vt[ik, ], 
               k = length(ik), pct = 100*sum(udv$d[ik]^2)/sum(udv$d^2))
    models[[label]] = mod
  }
  if(plots) lapply(models, function(x) plot(1:length(x$d), cumsum(x$d^2)))
  models
}

#' predict_svdmod
#' 
#' Computes classification of new images in test data
#' 
predict_svdmod = function(test, models) {
  np = nrow(test)
  pred = rep(NA, np)
  mnames = names(models)
  mloss = matrix(NA, nrow = np, ncol = length(mnames))
  colnames(mloss) = mnames
  
  y = as.matrix(test)   ## removed loop and set y as matrix
  for(m in mnames) {
    vt = models[[m]]$vt
    yhat = y %*% t(vt) %*% vt  ## transpose of t(vt) %*% vt %*% y
    mloss[, m] = rowSums((y - yhat)^2)/ncol(y) ## rowSums instead of sum
  }
  pred = apply(mloss, 1, function(x) mnames[which.min(x)]) ## apply over rows
  pred
}

#' image_ggplot
#' 
#' Produces a facet plot of first few basis vectors as images
#' 
image_ggplot = function(images, ivals, title) {
  library(ggplot2)
  image = rep(ivals, 28*28)
  lab = rep("component", 28*28)
  image = factor(paste(lab, image, sep = ": "))
  col = rep(rep(1:28, 28), each = length(ivals))
  row = rep(rep(1:28, each = 28), each = length(ivals))
  im = data.frame(image = image, row = row, col = col, 
                  val = as.numeric(images[ivals, ]))
  print(
    ggplot(im, aes(row, col, fill = val)) + geom_tile() + facet_wrap(~ image) +
      ggtitle(title)
  )
}

#' model_report
#' 
#' reports a summary for each label model of basis vectors
#' optionally plots basis images
#' 
model_report = function(models, kplot = 0) {
  for(m in names(models)) {
    cat("Model", m, ": size ", models[[m]]$k, " var captured ", 
        models[[m]]$pct, " %\n", sep = "") 
    if(kplot) image_ggplot(models[[m]]$vt, 1:kplot, paste("Digit", m))
  }
}

suppressMessages(library(pbdIO))
suppressMessages(library(pbdMPI))
library(parallel)
library(ggplot2)





## Begin CV (This CV is with mclapply. Exercise 8 needs MPI parallelization.)
## set up cv parameters


nfolds = 5
pars = seq(80.0, 95, 0.2) ## par values to fit


my.rank <- comm.rank()



folds = sample( rep_len(1:nfolds, nrow(train)), nrow(train) ) ## random folds
cv = expand.grid(par = pars, fold = 1:nfolds)  ## all combinations
my_index = comm.chunk(nrow(cv), form = "vector")

ranks = comm.size()
#msg = paste0("Hello World! My name is Empi", my.rank,
#            ". We are ", ranks, " identical siblings.")
#cat(msg, "\n")




#------------------------------------------------------------------------
#jara zkousi programovat cv

#n = nrow(train)
#n_test = nrow(test)
#my_trees = comm.chunk(512)
#my_test_rows = comm.chunk(nrow(test), form = "vector")

#my_rf = randomForest(train, y = train_lab, ntree = my_trees, norm.votes = FALSE)
#all_rf = allgather(my_rf)
#all_rf = do.call(combine, all_rf)

#my_pred = as.vector(predict(all_rf, test[my_test_rows, ]))

#correct = reduce(sum(my_pred == test_lab[my_test_rows]))
#comm.cat("Proportion Correct:", correct/n_test, "\n")

#finalize()










#-------------------------------------------------------------------------


## function for parameter combination i
fold_err = function(i, cv, folds, train) {
  par = cv[i, "par"]
  fold = (folds == cv[i, "fold"])
  models = svdmod(train[!fold, ], train_lab[!fold], pct = par)
  predicts = predict_svdmod(train[fold, ], models)
  sum(predicts != train_lab[fold])
}

## apply fold_err() over parameter combinations
comm.print(my_index)




comm.print("preslo to pred lapply",my.rank,all.rank = TRUE)
my_cv_err = lapply(my_index,fold_err, cv = cv, folds = folds, train = train)
comm.print("preslo to za lapply",my.rank,all.rank = TRUE)


cv_err = allgather(my_cv_err) 
cv_err_par = tapply(unlist(cv_err), cv[, "par"], sum)



#cv_err_par = tapply(unlist(cv_err), cv[, "par"], sum)


#cv_err_par_colect <- unlist(allgather(cv_err_par))
## plot cv curve with loess smoothing (ggplot default)
comm.print(cv_err_par)

pdf("Crossvalidation.pdf")
ggplot(data.frame(pct = pars, error = cv_err_par/nrow(train)), 
       aes(pct, error)) + geom_point() + geom_smooth() +
  labs(title = "Loess smooth with 95% CI of crossvalidation")
dev.off()




## End CV

## recompute with optimal pct
if(comm.rank() == 0) { models = svdmod(train, train_lab, pct = 85)
pdf("BasisImages.pdf")
model_report(models, kplot = 9)
dev.off()
predicts = predict_svdmod(test, models)
correct <- sum(predicts == test_lab)
cat("Proportion Correct:", correct/nrow(test), "\n")}

finalize()