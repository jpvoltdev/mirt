#' Imputing plausible data for missing values
#'
#' Given an estimated model from any of mirt's model fitting functions and an estimate of the
#' latent trait, impute plausible missing data values. Returns the original data in a
#' \code{data.frame} without any NA values. If a list of \code{Theta} values is supplied then a
#' list of complete datasets is returned instead.
#'
#' @aliases imputeMissing
#' @param x an estimated model x from the mirt package
#' @param Theta a matrix containing the estimates of the latent trait scores
#'   (e.g., via \code{\link{fscores}})
#' @param warn logical; print warning messages?
#' @param ... additional arguments to pass
#'
#' @author Phil Chalmers \email{rphilip.chalmers@@gmail.com}
#' @keywords impute data
#' @export imputeMissing
#' @examples
#' \dontrun{
#' dat <- expand.table(LSAT7)
#' (original <- mirt(dat, 1))
#' NAperson <- sample(1:nrow(dat), 20, replace = TRUE)
#' NAitem <- sample(1:ncol(dat), 20, replace = TRUE)
#' for(i in 1:20)
#'     dat[NAperson[i], NAitem[i]] <- NA
#' (mod <- mirt(dat, 1))
#' scores <- fscores(mod, method = 'MAP')
#'
#' #re-estimate imputed dataset (good to do this multiple times and average over)
#' fulldata <- imputeMissing(mod, scores)
#' (fullmod <- mirt(fulldata, 1))
#'
#' #with multipleGroup
#' set.seed(1)
#' group <- sample(c('group1', 'group2'), 1000, TRUE)
#' mod2 <- multipleGroup(dat, 1, group, TOL=1e-2)
#' fs <- fscores(mod2)
#' fulldata2 <- imputeMissing(mod2, fs)
#'
#' }
imputeMissing <- function(x, Theta, warn = TRUE, ...){
    if(missing(x)) missingMsg('x')
    if(missing(Theta)) missingMsg('Theta')
    if(is(x, 'MixedClass'))
        stop('MixedClass objects are not yet supported.', call.=FALSE)
    if(warn && sum(is.na(data))/length(data) > .1)
        warning('Imputing too much data can lead to very conservative results. Use with caution.',
                call.=FALSE)
    if(is(x, 'MultipleGroupClass') || is(x, 'DiscreteClass')){
        pars <- extract.mirt(x, 'pars')
        group <- extract.mirt(x, 'group')
        data <- extract.mirt(x, 'data')
        groupNames <- extract.mirt(x, 'groupNames')
        uniq_rows <- apply(data, 2L, function(x) list(sort(na.omit(unique(x)))))
        for(g in 1L:length(pars)){
            sel <- group == groupNames[g]
            Thetatmp <- Theta[sel, , drop = FALSE]
            pars[[g]]@Data$data <- data[sel, ]
            pars[[g]]@Data$mins <- extract.mirt(x, 'mins')
            data[sel, ] <- imputeMissing(pars[[g]], Thetatmp, warn=FALSE, uniq_rows=uniq_rows)
        }
        return(data)
    }
    pars <- extract.mirt(x, 'pars')
    data <- extract.mirt(x, 'data')
    nfact <- pars[[1L]]@nfact
    if(!is(Theta, 'matrix') || nrow(Theta) != nrow(data) || ncol(Theta) != nfact)
        stop('Theta must be a matrix of size N x nfact', call.=FALSE)
    if(!is.list(Theta)){
        if(any(Theta %in% c(Inf, -Inf))){
            for(i in 1L:ncol(Theta)){
                tmp <- Theta[,i]
                tmp[tmp %in% c(-Inf, Inf)] <- NA
                Theta[Theta[,i] == Inf, i] <- max(tmp, na.rm=TRUE) + .1
                Theta[Theta[,i] == -Inf, i] <- min(tmp, na.rm=TRUE) - .1
            }
        }
    }
    K <- extract.mirt(x, 'K')
    J <- length(K)
    N <- nrow(data)
    Nind <- 1L:N
    mins <- extract.mirt(x, 'mins')
    for (i in 1L:J){
        if(!any(is.na(data[,i]))) next
        P <- ProbTrace(x=pars[[i]], Theta=Theta)
        NAind <- Nind[is.na(data[,i])]
        for(j in 1L:length(NAind)){
            data[NAind[j], i] <- sample(1L:K[i]-1L+mins[i], 1L,
                                        prob = P[NAind[j], , drop = FALSE])
        }
    }
    return(data)
}
