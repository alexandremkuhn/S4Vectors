### =========================================================================
### Common operations on List objects
### -------------------------------------------------------------------------
###


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Looping on List objects
###

setMethod("lapply", "List",
          function(X, FUN, ...)
          {
              FUN <- match.fun(FUN)
              ii <- seq_len(length(X))
              names(ii) <- names(X)
              lapply(ii, function(i) FUN(X[[i]], ...))
          })

.sapplyDefault <- base::sapply
environment(.sapplyDefault) <- topenv()
setMethod("sapply", "List", .sapplyDefault)

### Turn ordinary list 'ans' into an object of the same class as list-like
### object 'X'. Preserve the length and names of 'ans'. Propagate the metadata
### and metadata columns from 'X'.
.make_endoapply_ans <- function(ans, X)
{
    ans <- coerce2(ans, X)
    if (is(X, "Vector")) {
        metadata(ans) <- metadata(X)
        mcols(ans) <- mcols(X)
    }
    ans
}

endoapply <- function(X, FUN, ...)
{
    ans <- lapply(X, FUN, ...)
    .make_endoapply_ans(ans, X)
}

setGeneric("revElements", signature="x",
    function(x, i) standardGeneric("revElements")
)

### These 2 methods explain the concept of revElements() but they are not
### efficient because they loop over the elements of 'x[i]'.
### There is a fast method for CompressedList objects though.
setMethod("revElements", "list",
    function(x, i)
    {
        x[i] <- lapply(x[i], revROWS)
        x
    }
)

setMethod("revElements", "List",
    function(x, i)
    {
        x[i] <- endoapply(x[i], revROWS)
        x
    }
)

mendoapply <- function(FUN, ..., MoreArgs=NULL)
{
    arg1 <- list(...)[[1L]]
    ans <- mapply(FUN, ..., MoreArgs=MoreArgs, SIMPLIFY=FALSE)
    .make_endoapply_ans(ans, arg1)
}

### Element-wise c() for list-like objects.
### This is a fast mapply(c, ..., SIMPLIFY=FALSE) but with the following
### differences:
###   1) pc() ignores the supplied objects that are NULL.
###   2) pc() does not recycle its arguments. All the supplied objects must
###      have the same length.
###   3) If one of the supplied objects is a List object, then pc() returns a
###      List object.
###   4) pc() always returns a homogenous list or List object, that is, an
###      object where all the list elements have the same type.
pc <- function(...)
{
    args <- unname(list(...))
    args <- args[!sapply_isNULL(args)]
    if (length(args) == 0L)
        return(list())
    if (length(args) == 1L)
        return(args[[1L]])
    args_NROWS <- elementNROWS(args)
    if (!all(args_NROWS == args_NROWS[[1L]]))
        stop("all the objects to combine must have the same length")

    ans_as_List <- any(vapply(args, is, logical(1), "List", USE.NAMES=FALSE))
    SPLIT.FUN <- if (ans_as_List) IRanges::splitAsList else split
    ans_unlisted <- do.call(c, lapply(args, unlist, use.names=FALSE))
    f <- structure(unlist(lapply(args, quick_togroup), use.names=FALSE),
                   levels=as.character(seq_along(args[[1L]])),
                   class="factor")
    setNames(SPLIT.FUN(ans_unlisted, f), names(args[[1L]]))
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Functional programming methods
###

### Copy+pasted to disable forced as.list() coercion
.ReduceDefault <- function(f, x, init, right = FALSE, accumulate = FALSE) 
{
    mis <- missing(init)
    len <- length(x)
    if (len == 0L) 
        return(if (mis) NULL else init)
    f <- match.fun(f)
#    if (!is.vector(x) || is.object(x)) 
#        x <- as.list(x)
    ind <- seq_len(len)
    if (mis) {
        if (right) {
            init <- x[[len]]
            ind <- ind[-len]
        }
        else {
            init <- x[[1L]]
            ind <- ind[-1L]
        }
    }
    if (!accumulate) {
        if (right) {
            for (i in rev(ind)) init <- f(x[[i]], init)
        }
        else {
            for (i in ind) init <- f(init, x[[i]])
        }
        init
    }
    else {
        len <- length(ind) + 1L
        out <- vector("list", len)
        if (mis) {
            if (right) {
                out[[len]] <- init
                for (i in rev(ind)) {
                    init <- f(x[[i]], init)
                    out[[i]] <- init
                }
            }
            else {
                out[[1L]] <- init
                for (i in ind) {
                    init <- f(init, x[[i]])
                    out[[i]] <- init
                }
            }
        }
        else {
            if (right) {
                out[[len]] <- init
                for (i in rev(ind)) {
                    init <- f(x[[i]], init)
                    out[[i]] <- init
                }
            }
            else {
                for (i in ind) {
                    out[[i]] <- init
                    init <- f(init, x[[i]])
                }
                out[[len]] <- init
            }
        }
        if (all(lengths(out) == 1L)) 
            out <- unlist(out, recursive = FALSE)
        out
    }
}

setMethod("Reduce", "List", .ReduceDefault)

### Presumably to avoid base::lapply coercion to list.
.FilterDefault <- base::Filter
environment(.FilterDefault) <- topenv()
setMethod("Filter", "List", .FilterDefault)

### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Evaluating.
###

setMethod("within", "List",
          function(data, expr, ...)
          {
            ## cannot use active bindings here, as they break for replacement
            enclos <- top_prenv(expr)
            e <- list2env(as.list(data), parent=enclos)
            safeEval(substitute(expr), e, enclos)
            l <- mget(ls(e), e)
            l <- delete_NULLs(l)
            nD <- length(del <- setdiff(names(data), (nl <- names(l))))
            for (nm in nl)
              data[[nm]] <- l[[nm]]
            for (nm in del)
              data[[nm]] <- NULL
            data
          })

setMethod("do.call", c("ANY", "List"),
          function (what, args, quote = FALSE, envir = parent.frame()) {
            args <- as.list(args)
            callGeneric()
          })

### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Factors.
###

droplevels.List <- function(x, ...) droplevels(x, ...)
.droplevels.List <- function(x, except = NULL) 
{
  ix <- vapply(x, Has(levels), logical(1L))
  ix[except] <- FALSE
  x[ix] <- lapply(x[ix], droplevels)
  x
}

setMethod("droplevels", "List", .droplevels.List)

### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Summarizing.
###

setMethod("anyNA", "List", function(x, recursive=FALSE) {
    stopifnot(isTRUEorFALSE(recursive))
    if (recursive) {
        anyNA(as.list(x), recursive=TRUE)
    } else {
        callNextMethod()
    }
})

### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Matrix construction
###

normBindArgs <- function(..., deparse.level=1L) {
    stopifnot(isSingleNumber(deparse.level),
              deparse.level >= 0L,
              deparse.level <= 2L)
    args <- list(...)
    if (deparse.level > 0L) {
        exprs <- as.list(substitute(list(...)))[-1L]
        genName <- if (is.null(names(args))) TRUE else names(args) == ""
        if (deparse.level == 1L && any(genName))
            genName <- genName & vapply(exprs, is.name, logical(1L))
        if (any(genName)) {
            if (is.null(names(args)))
                names(args) <- rep("", length(args))
            names(args)[genName] <- as.character(exprs[genName])
        }
    }
    args
}

setMethod("rbind", "List", function(..., deparse.level=1L) {
    args <- normBindArgs(..., deparse.level=deparse.level)
    do.call(rbind, lapply(args, as.list))
})

setMethod("cbind", "List", function(..., deparse.level=1L) {
    args <- normBindArgs(..., deparse.level=deparse.level)
    do.call(cbind, lapply(args, as.list))
})
