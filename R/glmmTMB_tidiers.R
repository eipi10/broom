#' Tidying methods for glmmTMB models
#' 
#' These methods tidy the coefficients of mixed effects models, particularly
#' responses of the \code{merMod} class
#' 
#' @param x An object of class \code{merMod}, such as those from \code{lmer},
#' \code{glmer}, or \code{nlmer}
#' 
#' @return All tidying methods return a \code{data.frame} without rownames.
#' The structure depends on the method chosen.
#' 
#' @name glmmTMB_tidiers
#'
#' @examples
#' 
#' if (require("glmmTMB") && require("lme4")) {
#'     # example regressions are from lme4 documentation
#'     lmm1 <- glmmTMB(Reaction ~ Days + (Days | Subject), sleepstudy)
#'     tidy(lmm1)
#'     tidy(lmm1, effects = "fixed")
#'     tidy(lmm1, effects = "fixed", conf.int=TRUE)
#'     ## tidy(lmm1, effects = "fixed", conf.int=TRUE, conf.method="profile")
#'     ## tidy(lmm1, effects = "ran_modes", conf.int=TRUE)
#'     head(augment(lmm1, sleepstudy))
#'     glance(lmm1)
#'     
#'     glmm1 <- glmmTMB(incidence/size ~ period + (1 | herd),
#'                   data = cbpp, family = binomial, weights=size)
#'     tidy(glmm1)
#'     tidy(glmm1, effects = "fixed")
#'     head(augment(glmm1, cbpp))
#'     head(augment(glmm1, cbpp, type.residuals="pearson"))
#'     glance(glmm1)
#'     
#' }
NULL


#' @rdname glmmTMB_tidiers
#'
#' @param effects A character vector including one or more of "fixed" (fixed-effect parameters), "ran_pars" (variances and covariances or standard deviations and correlations of random effect terms) or "ran_modes" (conditional modes/BLUPs/latent variable estimates)
#' @param cond which component to extract (e.g. \code{cond} for conditional effects (i.e., traditional fixed effects); \code{zi} for zero-inflation model; \code{disp} for dispersion model
#' @param conf.int whether to include a confidence interval
#' @param conf.level confidence level for CI
#' @param conf.method method for computing confidence intervals (see \code{\link[lme4]{confint.merMod}})
#' @param scales scales on which to report the variables: for random effects, the choices are \sQuote{"sdcor"} (standard deviations and correlations: the default if \code{scales} is \code{NULL}) or \sQuote{"varcov"} (variances and covariances). \code{NA} means no transformation, appropriate e.g. for fixed effects; inverse-link transformations (exponentiation
#' or logistic) are not yet implemented, but may be in the future.
#' @param ran_prefix a length-2 character vector specifying the strings to use as prefixes for self- (variance/standard deviation) and cross- (covariance/correlation) random effects terms
#' 
#' @return \code{tidy} returns one row for each estimated effect, either
#' with groups depending on the \code{effects} parameter.
#' It contains the columns
#'   \item{group}{the group within which the random effect is being estimated: \code{"fixed"} for fixed effects}
#'   \item{level}{level within group (\code{NA} except for modes)}
#'   \item{term}{term being estimated}
#'   \item{estimate}{estimated coefficient}
#'   \item{std.error}{standard error}
#'   \item{statistic}{t- or Z-statistic (\code{NA} for modes)}
#'   \item{p.value}{P-value computed from t-statistic (may be missing/NA)}
#' 
#' @importFrom plyr ldply rbind.fill
#' @import dplyr
#' @importFrom tidyr gather spread
#' @importFrom nlme VarCorr ranef
## FIXME: is it OK/sensible to import these from (priority='recommended')
## nlme rather than (priority=NA) lme4?
#' 
#' @export
tidy.glmmTMB <- function(x, effects = c("ran_pars","fixed"),
                         component="cond",
                         scales = NULL, ## c("sdcor",NA),
                         ran_prefix=NULL,
                         conf.int = FALSE,
                         conf.level = 0.95,
                         conf.method = "Wald",
                        ...) {
    if (length(component)>1 || component!="cond") {
        stop("only works for conditional component")
    }
    effect_names <- c("ran_pars", "fixed", "ran_modes")
    if (!is.null(scales)) {
        if (length(scales) != length(effects)) {
            stop("if scales are specified, values (or NA) must be provided ",
                 "for each effect")
        }
    }
    if (length(miss <- setdiff(effects,effect_names))>0)
        stop("unknown effect type ",miss)
    base_nn <- c("estimate", "std.error", "statistic", "p.value")
    ret_list <- list()
    if ("fixed" %in% effects) {
        # return tidied fixed effects rather than random
        ret <- stats::coef(summary(x))[[component]]

        # p-values may or may not be included
        nn <- base_nn[1:ncol(ret)]

        if (conf.int) {
            ## at present confint only does conditional component anyway ...
            cifix <- confint(x,method=conf.method,...)
            ret <- data.frame(ret,cifix)
            nn <- c(nn,"conf.low","conf.high")
        }
        if ("ran_pars" %in% effects || "ran_modes" %in% effects) {
            ret <- data.frame(ret,group="fixed")
            nn <- c(nn,"group")
        }
        ret_list$fixed <-
            fix_data_frame(ret, newnames = nn)
    }
    if ("ran_pars" %in% effects &&
        !all(sapply(VarCorr(x),is.null))) {
        if (is.null(scales)) {
            rscale <- "sdcor"
        } else rscale <- scales[effects=="ran_pars"]
        if (!rscale %in% c("sdcor","vcov"))
            stop(sprintf("unrecognized ran_pars scale %s",sQuote(rscale)))
        ## kluge for now ...
        vv <- VarCorr(x)[[component]]
        class(vv) <- "VarCorr.merMod"
        ret <- as.data.frame(vv)
        ret[] <- lapply(ret, function(x) if (is.factor(x))
                                                 as.character(x) else x)
        if (is.null(ran_prefix)) {
            ran_prefix <- switch(rscale,
                                 vcov=c("var","cov"),
                                 sdcor=c("sd","cor"))
        }
        pfun <- function(x) {
            v <- na.omit(unlist(x))
            if (length(v)==0) v <- "Observation"
            p <- paste(v,collapse=".")
            if (!identical(ran_prefix,NA)) {
                p <- paste(ran_prefix[length(v)],p,sep="_")
            }
            return(p)
        }
            
        rownames(ret) <- paste(apply(ret[c("var1","var2")],1,pfun),
                               ret[,"grp"],sep=".")

        ## FIXME: this is ugly, but maybe necessary?
        ## set 'term' column explicitly, disable fix_data_frame
        ##  rownames -> term conversion
        ## rownames(ret) <- seq(nrow(ret))

        if (conf.int) {
            ciran <- confint(x,parm="theta_",method=conf.method,...)
            ret <- data.frame(ret,ciran)
            nn <- c(nn,"conf.low","conf.high")
        }
        
        ## replicate lme4:::tnames, more or less
        ret_list$ran_pars <- fix_data_frame(ret[c("grp",rscale)],
                                            newnames=c("group","estimate"))
    }
    if ("ran_modes" %in% effects) {
        ## fix each group to be a tidy data frame

        nn <- c("estimate", "std.error")
        re <- ranef(x,condVar=TRUE)
        getSE <- function(x) {
            v <- attr(x,"postVar")
            setNames(as.data.frame(sqrt(t(apply(v,3,diag)))),
                     colnames(x))
        }
        fix <- function(g,re,.id) {
             newg <- fix_data_frame(g, newnames = colnames(g), newcol = "level")
             # fix_data_frame doesn't create a new column if rownames are numeric,
             # which doesn't suit our purposes
             newg$level <- rownames(g)
             newg$type <- "estimate"

             newg.se <- getSE(re)
             newg.se$level <- rownames(re)
             newg.se$type <- "std.error"

             data.frame(rbind(newg,newg.se),.id=.id,
                        check.names=FALSE)
                        ## prevent coercion of variable names
        }

        mm <- do.call(rbind,Map(fix,coef(x),re,names(re)))

        ## block false-positive warnings due to NSE
        type <- spread <- est <- NULL
        mm %>% gather(term, estimate, -.id, -level, -type) %>%
            spread(type,estimate) -> ret

        ## FIXME: doesn't include uncertainty of population-level estimate

        if (conf.int) {
            if (conf.method != "Wald")
                stop("only Wald CIs available for conditional modes")

            mult <- qnorm((1+conf.level)/2)
            ret <- transform(ret,
                             conf.low=estimate-mult*std.error,
                             conf.high=estimate+mult*std.error)
        }

        ret <- dplyr::rename(ret,grp=.id)
        ret_list$ran_modes <- ret
    }
    ## use ldply to get 'effect' added as a column
    return(plyr::ldply(ret_list,identity,.id="effect"))

}



#' @rdname lme4_tidiers
#' 
#' @param data original data this was fitted on; if not given this will
#' attempt to be reconstructed
#' @param newdata new data to be used for prediction; optional
#' 
#' @template augment_NAs
#' 
#' @return \code{augment} returns one row for each original observation,
#' with columns (each prepended by a .) added. Included are the columns
#'   \item{.fitted}{predicted values}
#'   \item{.resid}{residuals}
#'   \item{.fixed}{predicted values with no random effects}
#' 
#' @export
augment.glmmTMB <- function(x, data = stats::model.frame(x), newdata,
                            type.predict, type.residuals, se.fit=TRUE,
                            ...) {
    augment_columns(x, data, newdata, type.predict = type.predict, 
                    type.residuals = type.residuals,
                    se.fit = se.fit)

}


#' @rdname glmmTMB_tidiers
#' 
#' @param ... extra arguments (not used)
#' 
#' @return \code{glance} returns one row with the columns
#'   \item{sigma}{the square root of the estimated residual variance}
#'   \item{logLik}{the data's log-likelihood under the model}
#'   \item{AIC}{the Akaike Information Criterion}
#'   \item{BIC}{the Bayesian Information Criterion}
#'   \item{deviance}{deviance}
#'
#' @rawNamespace if(getRversion()>='3.3.0') importFrom(stats, sigma) else importFrom(lme4,sigma)
#' @export
glance.glmmTMB <- function(x, ...) {
    ret <- unrowname(data.frame(sigma = sigma(x)))
    finish_glance(ret, x)
}
