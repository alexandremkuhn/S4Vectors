### =========================================================================
### Some low-level (not exported) utility functions used by various "show"
### methods
### -------------------------------------------------------------------------
###
### Unless stated otherwise, nothing in this file is exported.
###


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### selectSome()
###

### taken directly from Biobase, then added 'ellipsisPos' argument
selectSome <- function(obj, maxToShow = 5, ellipsis = "...",
                       ellipsisPos = c("middle", "end", "start"), quote=FALSE) 
{
  if(is.character(obj) && quote)
      obj <- sQuote(obj)
  ellipsisPos <- match.arg(ellipsisPos)
  len <- length(obj)
  if (maxToShow < 3) 
    maxToShow <- 3
  if (len > maxToShow) {
    maxToShow <- maxToShow - 1
    if (ellipsisPos == "end") {
      c(head(obj, maxToShow), ellipsis)
    } else if (ellipsisPos == "start") {
      c(ellipsis, tail(obj, maxToShow))
    } else {
      bot <- ceiling(maxToShow/2)
      top <- len - (maxToShow - bot - 1)
      nms <- obj[c(1:bot, top:len)]
      c(as.character(nms[1:bot]), ellipsis, as.character(nms[-c(1:bot)]))
    }
  } else {
    obj
  }
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### labeledLine()
###

.qualifyByName <- function(x, qualifier="=") {
    nms <- names(x)
    x <- as.character(x)
    aliased <- nzchar(nms)
    x[aliased] <- paste0(nms[aliased], qualifier, x[aliased])
    x
}

.padToAlign <- function(x) {
    whitespace <- paste(rep(" ", getOption("width")), collapse="")
    padlen <- max(nchar(x)) - nchar(x)
    substring(whitespace, 1L, padlen)
}

.ellipsize <-
  function(obj, width = getOption("width"), sep = " ", ellipsis = "...",
           pos = c("middle", "end", "start"))
{
  pos <- match.arg(pos)
  if (is.null(obj))
    obj <- "NULL"
  if (is.factor(obj))
    obj <- as.character(obj)
  ## get order selectSome() would print
  if (pos == "middle") {
    if (length(obj) > 2 * width)
      obj <- c(head(obj, width), tail(obj, width))
    half <- seq_len(ceiling(length(obj) / 2L))
    ind <- as.vector(rbind(half, length(obj) - half + 1L))
  } else if (pos == "end") {
    obj <- head(obj, width)
    ind <- seq_len(length(obj))
  } else {
    obj <- tail(obj, width)
    ind <- rev(seq_len(length(obj)))
  }
  str <- encodeString(obj)
  nc <- cumsum(nchar(str[ind]) + nchar(sep)) - nchar(sep)
  last <- findInterval(width, nc)
  if (length(obj) > last) {
    ## make sure ellipsis fits
    while (last &&
           (nc[last] + nchar(sep)*2^(last>1) + nchar(ellipsis)) > width)
      last <- last - 1L
    if (last == 0) { ## have to truncate the first/last element
      if (pos == "start") {
        str <-
          paste(ellipsis,
                substring(tail(str, 1L),
                          nchar(tail(str, 1L))-(width-nchar(ellipsis))+1L,
                          nchar(ellipsis)),
                sep = "")
      } else {
        str <-
          paste(substring(str[1L], 1, width - nchar(ellipsis)), ellipsis,
                sep = "")
      }
    }
    else if (last == 1) { ## can only show the first/last
      if (pos == "start")
        str <- c(ellipsis, tail(str, 1L))
      else str <- c(str[1L], ellipsis)
    }
    else {
      str <- selectSome(str, last + 1L, ellipsis, pos)
    }
  }
  paste(str, collapse = sep)
}

labeledLine <-
    function(label, els, count = TRUE, labelSep = ":", sep = " ",
             ellipsis = "...", ellipsisPos = c("middle", "end", "start"),
             vectorized = FALSE, pad = vectorized)
{
  if (!is.null(els)) {
      label[count] <- paste(label, "(",
                            if (vectorized) lengths(els) else length(els),
                            ")", sep = "")[count]
      if (!is.null(names(els))) {
          els <- .qualifyByName(els)
      }
  }
  label <- paste(label, labelSep, " ", sep = "")
  if (pad) {
      label <- paste0(label, .padToAlign(label))
  }
  width <- getOption("width") - nchar(label)
  ellipsisPos <- match.arg(ellipsisPos)
  if (vectorized) {
      .ellipsize <- Vectorize(.ellipsize)
  }
  line <- .ellipsize(els, width, sep, ellipsis, ellipsisPos)
  paste(label, line, "\n", sep = "")
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### get_showHeadLines() and get_showTailLines()
###

### showHeadLines and showTailLines robust to NA, Inf and non-integer 
.get_showLines <- function(default, option)
{
    opt <- getOption(option, default=default)
    if (!is.infinite(opt))
        opt <- as.integer(opt)
    if (is.na(opt))
        opt <- default
    opt
}

### Exported!
get_showHeadLines <- function() .get_showLines(5L, "showHeadLines")

### Exported!
get_showTailLines <- function() .get_showLines(5L, "showTailLines")


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Pretty printing
###

### Exported!
printAtomicVectorInAGrid <- function(x, prefix="", justify="left")
{
    if (!is.character(x))
        x <- setNames(as.character(x), names(x))

    ## Nothing to print if length(x) is 0.
    if (length(x) == 0L)
        return(invisible(x))

    ## Determine the nb of cols in the grid.
    grid_width <- getOption("width") + 1L - nchar(prefix)
    cell_width <- max(3L, nchar(x), nchar(names(x)))
    ncol <- grid_width %/% (cell_width + 1L)

    ## Determine the nb of rows in the grid.    
    nrow <- length(x) %/% ncol
    remainder <- length(x) %% ncol
    if (remainder != 0L) {
        nrow <- nrow + 1L
        x <- c(x, character(ncol - remainder))
    }

    ## Print the grid.
    print_line <- function(y)
    {
        cells <- format(y, justify=justify, width=cell_width)
        cat(prefix, paste0(cells, collapse=" "), "\n", sep="")
    }
    print_grid_row <- function(i)
    {
        idx <- (i - 1L) * ncol + seq_len(ncol)
        slice <- x[idx]
        if (!is.null(names(slice)))
            print_line(names(slice))
        print_line(slice)
    }
    n1 <- get_showHeadLines()
    n2 <- get_showTailLines()
    if (nrow <= n1 + n2) {
        for (i in seq_len(nrow)) print_grid_row(i)
    } else {
        idx1 <- seq_len(n1)
        idx2 <- nrow - n2 + seq_len(n2)
        for (i in idx1) print_grid_row(i)
        print_line(rep.int("...", ncol))
        for (i in idx2) print_grid_row(i)
    }
    invisible(x)
}

### 'makeNakedMat.FUN' must be a function returning a character matrix.
makePrettyMatrixForCompactPrinting <- function(x, makeNakedMat.FUN)
{
    nhead <- get_showHeadLines()
    ntail <- get_showTailLines()
    x_NROW <- NROW(x)
    x_ROWNAMES <- ROWNAMES(x)
    wrap_in_square_brackets <- function(idx) {
        if (length(idx) == 0L)
            return(character(0))
        paste0("[", idx, "]")
    }
    if (x_NROW <= nhead + ntail + 1L) {
        ## Compute 'ans' (the matrix).
        ans <- makeNakedMat.FUN(x)
        ## Compute 'ans_rownames' (the matrix row names).
        if (is.null(x_ROWNAMES)) {
            ans_rownames <- wrap_in_square_brackets(seq_len(x_NROW))
        } else {
            ans_rownames <- x_ROWNAMES
        }
    } else {
        ## Compute 'ans' (the matrix).
        ans_top <- makeNakedMat.FUN(head(x, n=nhead))
        ans_bottom <- makeNakedMat.FUN(tail(x, n=ntail))
        ellipses <- rep.int("...", ncol(ans_top))
        ellipses[colnames(ans_top) %in% "|"] <- "."
        ans <- rbind(ans_top, matrix(ellipses, nrow=1L), ans_bottom)
        ## Compute 'ans_rownames' (the matrix row names).
        if (is.null(x_ROWNAMES)) {
            idx1 <- seq(from=1L, by=1L, length.out=nhead)
            idx2 <- seq(to=x_NROW, by=1L, length.out=ntail)
            s1 <- wrap_in_square_brackets(idx1)
            s2 <- wrap_in_square_brackets(idx2)
        } else {
            s1 <- head(x_ROWNAMES, n=nhead)
            s2 <- tail(x_ROWNAMES, n=ntail)
        }
        max_width <- max(nchar(s1, type="width"), nchar(s2, type="width"))
        if (max_width <= 1L) {
            ellipsis <- "."
        } else if (max_width == 2L) {
            ellipsis <- ".."
        } else {
            ellipsis <- "..."
        }
        ans_rownames <- c(s1, ellipsis, s2)
    }
    rownames(ans) <- format(ans_rownames, justify="right")
    ans
}

makeClassinfoRowForCompactPrinting <- function(x, col2class)
{
    ans_names <- names(col2class)
    no_bracket <- ans_names == ""
    ans_names[no_bracket] <- col2class[no_bracket]
    left_brackets <- right_brackets <- character(length(col2class))
    left_brackets[!no_bracket] <- "<"
    right_brackets[!no_bracket] <- ">"
    ans <- paste0(left_brackets, col2class, right_brackets)
    names(ans) <- ans_names
    x_mcols <- mcols(x)
    x_nmc <- if (is.null(x_mcols)) 0L else ncol(x_mcols)
    if (x_nmc > 0L) {
        tmp <- sapply(x_mcols,
                      function(xx) paste0("<", classNameForDisplay(xx), ">"))
        ans <- c(ans, `|`="|", tmp)
    }
    matrix(ans, nrow=1L, dimnames=list("", names(ans)))
}

### Works as long as length(), "[" and as.numeric() work on 'x'.
### Not exported.
toNumSnippet <- function(x, max.width)
{
    if (length(x) <= 2L)
        return(paste(format(as.numeric(x)), collapse=" "))
    if (max.width < 0L)
        max.width <- 0L
    ## Elt width and nb of elt to display if they were all 0.
    elt_width0 <- 1L
    nelt_to_display0 <- min(length(x), (max.width+1L) %/% (elt_width0+1L))
    head_ii0 <- seq_len(nelt_to_display0 %/% 2L)
    tail_ii0 <- length(x) + head_ii0 - length(head_ii0)
    ii0 <- c(head_ii0, tail_ii0)
    ## Effective elt width and nb of elt to display
    elt_width <- format.info(as.numeric(x[ii0]))[1L]
    nelt_to_display <- min(length(x), (max.width+1L) %/% (elt_width+1L))
    if (nelt_to_display == length(x))
        return(paste(format(as.numeric(x), width=elt_width), collapse=" "))
    head_ii <- seq_len((nelt_to_display+1L) %/% 2L)
    tail_ii <- length(x) + seq_len(nelt_to_display %/% 2L) - nelt_to_display %/% 2L
    ans_head <- format(as.numeric(x[head_ii]), width=elt_width)
    ans_tail <- format(as.numeric(x[tail_ii]), width=elt_width)
    ans <- paste(paste(ans_head, collapse=" "), "...", paste(ans_tail, collapse=" "))
    if (nchar(ans) <= max.width || length(ans_head) == 0L)
        return(ans)
    ans_head <- ans_head[-length(ans_head)]
    ans <- paste(paste(ans_head, collapse=" "), "...", paste(ans_tail, collapse=" "))
    if (nchar(ans) <= max.width || length(ans_tail) == 0L)
        return(ans)
    ans_tail <- ans_tail[-length(ans_tail)]
    paste(paste(ans_head, collapse=" "), "...", paste(ans_tail, collapse=" "))
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### classNameForDisplay()
###

### Exported!
setGeneric("classNameForDisplay",
    function(x) standardGeneric("classNameForDisplay"))

setMethod("classNameForDisplay", "ANY",
   function(x)
   {
       ## Selecting the 1st element guarantees that we return a single string
       ## (e.g. on an ordered factor, class(x) returns a character vector of
       ## length 2).
       class(x)[1L]
   }
)

.drop_AsIs <- function(x)
{
    #x_class <- class(x)
    #if (x_class[[1L]] == "AsIs")
    #    class(x) <- x_class[-1L]

    ## Simpler, and probably more robust, than the above.
    class(x) <- setdiff(class(x), "AsIs")
    x
}

setMethod("classNameForDisplay", "AsIs",
    function(x) classNameForDisplay(.drop_AsIs(x))
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### showAsCell()
###
### All "showAsCell" methods should return a character vector.
###

### Exported!
setGeneric("showAsCell",
    function(object) standardGeneric("showAsCell")
)

### Must work on any array-like object (i.e. on any object with 2 dimensions
### or more) e.g. ordinary array or matrix, Matrix, data.frame, DataFrame,
### data.table, etc...
.showAsCell_array <- function(object)
{
    if (length(dim(object)) > 2L)
        dim(object) <- c(nrow(object), prod(tail(dim(object), -1L)))
    object_ncol <- ncol(object)
    if (object_ncol == 0L)
        return(rep.int("", nrow(object)))
    object <- lapply(head(seq_len(object_ncol), 3L),
                     function(i) object[ , i, drop=TRUE])
    ans <- do.call(paste, c(object, list(sep=":")))
    if (object_ncol > 3L)
        ans <- paste0(ans, ":...")
    ans
}

.default_showAsCell <- function(object)
{
  ## Some objects like SplitDataFrameList are not array-like but have
  ## a "dim" method that return a matrix!
  if (length(dim(object)) >= 2L && !is.matrix(dim(object)))
    return(.showAsCell_array(object))
  if (NROW(object) == 0L)
    return(character(0L))
  if (is.list(object) || is(object, "List")) {
    vapply(object, function(x) {
      str <- paste(head(unlist(x), 3L), collapse = ",")
      if (length(x) > 3L)
        str <- paste0(str, ",...")
      str
    }, character(1L))
  } else {
    attempt <- try(as.vector(object), silent=TRUE)
    if (is(attempt, "try-error"))
      rep.int("########", length(object))
    else attempt
  }
}

setMethod("showAsCell", "ANY", .default_showAsCell)

setMethod("showAsCell", "AsIs",
    function(object) showAsCell(.drop_AsIs(object))
)

### Mmmh... these methods don't return a character vector. Is that ok?
setMethod("showAsCell", "Date", function(object) object)
setMethod("showAsCell", "POSIXt", function(object) object)

