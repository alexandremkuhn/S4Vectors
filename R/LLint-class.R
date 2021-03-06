### =========================================================================
### LLint objects
### -------------------------------------------------------------------------
###
### The LLint class is a container for storing a vector of "large integers"
### (i.e. long long int in C). It supports NAs.
###


### We don't support names for now. We will when we need them.
setClass("LLint", representation(bytes="raw"))

setClassUnion("integer_OR_LLint", c("integer", "LLint"))

is.LLint <- function(x) is(x, "LLint")

BYTES_PER_LLINT <- .Machine$sizeof.longlong

setMethod("length", "LLint",
    function(x) length(x@bytes) %/% BYTES_PER_LLINT
)

### Called from the .onLoad() hook in zzz.R
make_NA_LLint_ <- function()
{
    ans_bytes <- .Call2("make_RAW_from_NA_LLINT", PACKAGE="S4Vectors")
    new2("LLint", bytes=ans_bytes, check=FALSE)
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Coercion
###

.from_logical_to_LLint <- function(from)
{
    .Call2("new_LLint_from_LOGICAL", from, PACKAGE="S4Vectors")
}
setAs("logical", "LLint", .from_logical_to_LLint)

.from_integer_to_LLint <- function(from)
{
    .Call2("new_LLint_from_INTEGER", from, PACKAGE="S4Vectors")
}
setAs("integer", "LLint", .from_integer_to_LLint)

.from_numeric_to_LLint <- function(from)
{
    .Call2("new_LLint_from_NUMERIC", from, PACKAGE="S4Vectors")
}
setAs("numeric", "LLint", .from_numeric_to_LLint)

.from_character_to_LLint <- function(from)
{
    .Call2("new_LLint_from_CHARACTER", from, PACKAGE="S4Vectors")
}
setAs("character", "LLint", .from_character_to_LLint)

as.LLint <- function(x) as(x, "LLint")

### S3/S4 combo for as.logical.LLint
.from_LLint_to_logical <- function(x)
{
    .Call2("new_LOGICAL_from_LLint", x, PACKAGE="S4Vectors")
}
as.logical.LLint <- function(x, ...) .from_LLint_to_logical(x, ...)
setMethod("as.logical", "LLint", as.logical.LLint)

### S3/S4 combo for as.integer.LLint
.from_LLint_to_integer <- function(x)
{
    .Call2("new_INTEGER_from_LLint", x, PACKAGE="S4Vectors")
}
as.integer.LLint <- function(x, ...) .from_LLint_to_integer(x, ...)
setMethod("as.integer", "LLint", as.integer.LLint)

### S3/S4 combo for as.numeric.LLint
.from_LLint_to_numeric <- function(x)
{
    .Call2("new_NUMERIC_from_LLint", x, PACKAGE="S4Vectors")
}
as.numeric.LLint <- function(x, ...) .from_LLint_to_numeric(x, ...)
setMethod("as.numeric", "LLint", as.numeric.LLint)

### S3/S4 combo for as.character.LLint
.from_LLint_to_character <- function(x)
{
    .Call2("new_CHARACTER_from_LLint", x, PACKAGE="S4Vectors")
}
as.character.LLint <- function(x, ...) .from_LLint_to_character(x, ...)
setMethod("as.character", "LLint", as.character.LLint)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Constructor
###

.MAX_VECTOR_LENGTH <- 2^52  # see R_XLEN_T_MAX in Rinternals.h

### Return a single double value.
.normarg_vector_length <- function(length=0L, max_length=.MAX_VECTOR_LENGTH)
{
    if (is.LLint(length)) {
        if (length(length) != 1L || is.na(length) || length < as.LLint(0L))
            stop("invalid 'length' argument")
        if (length > as.LLint(max_length))
            stop("'length' is too big")
        return(as.double(length))
    }
    if (!isSingleNumber(length) || length < 0L)
        stop("invalid 'length' argument")
    if (is.integer(length)) {
        length <- as.double(length)
    } else {
        length <- trunc(length)
    }
    if (length > max_length)
        stop("'length' is too big")
    length
}

LLint <- function(length=0L)
{
    max_length <- .MAX_VECTOR_LENGTH / BYTES_PER_LLINT
    length <- .normarg_vector_length(length, max_length=max_length)
    ans_bytes <- raw(length * BYTES_PER_LLINT)
    new2("LLint", bytes=ans_bytes, check=FALSE)
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Displaying
###

.show_LLint <- function(x)
{
    x_len <- length(x)
    if (x_len == 0L) {
        cat(class(x), "(0)\n", sep="")
        return()
    }
    cat(class(x), " of length ", x_len, ":\n", sep="")
    print(as.character(x), quote=FALSE, na.print="NA")
    return()
}

setMethod("show", "LLint", function(object) .show_LLint(object))

setMethod("showAsCell", "LLint", function(object) as.character(object))


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Concatenation
###

### Low-level generic intended to facilitate implementation of "c" methods
### for vector-like objects. See R/Vector-class.R for more information.
### It can also be used to unlist an ordinary list of vector-like objects.
setGeneric("concatenateObjects", signature="x",
    function(x, objects=list(), use.names=TRUE, ignore.mcols=FALSE, check=TRUE)
        standardGeneric("concatenateObjects")
)

### Not exported.
### Low-level utility used by many "concatenateObjects" methods.
### Prepare 'objects' by deleting NULLs from it, dropping its names, and
### making sure that each of its list element belongs to the same class
### as 'x' (or to one of its subclasses) by coercing it if necessary.
prepare_objects_to_concatenate <- function(x, objects=list())
{
    if (!is.list(objects))
        stop("'objects' must be a list")
    x_class <- class(x)
    lapply(unname(delete_NULLs(objects)),
        function(object)
            if (!is(object, x_class))
                as(object, x_class, strict=FALSE)
            else
                object
    )
}

### Arguments 'use.names' and 'ignore.mcols' are ignored.
.concatenate_LLint_objects <-
    function(x, objects=list(), use.names=TRUE, ignore.mcols=FALSE, check=TRUE)
{
    if (!is.list(objects))
        stop("'objects' must be a list")
    all_objects <- c(list(x), unname(objects))

    ## If one of the objects to combine is a character vector, then all the
    ## objects are coerced to character and combined.
    if (any(vapply(all_objects, is.character, logical(1), USE.NAMES=FALSE))) {
        ans <- unlist(lapply(all_objects, as.character), use.names=FALSE)
        return(ans)
    }

    ## If one of the objects to combine is a double vector, then all the
    ## objects are coerced to double and combined.
    if (any(vapply(all_objects, is.double, logical(1), USE.NAMES=FALSE))) {
        ans <- unlist(lapply(all_objects, as.double), use.names=FALSE)
        return(ans)
    }

    ## Concatenate "bytes" slots.
    bytes_list <- lapply(all_objects,
        function(object) {
            if (is.null(object))
                return(NULL)
            if (is.logical(object) || is.integer(object))
                object <- as.LLint(object)
            if (is.LLint(object))
                return(object@bytes)
            stop(wmsg("cannot combine LLint objects ",
                      "with objects of class ", class(object)))
        }
    )
    ans_bytes <- unlist(bytes_list, use.names=FALSE)

    new2("LLint", bytes=ans_bytes, check=check)
}

setMethod("concatenateObjects", "LLint", .concatenate_LLint_objects)

### Thin wrapper around concatenateObjects().
setMethod("c", "LLint",
    function (x, ..., recursive=FALSE)
    {
        if (!identical(recursive, FALSE))
            stop("\"c\" method for LLint objects ",
                 "does not support the 'recursive' argument")
        concatenateObjects(x, list(...))
    }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### is.na(), anyNA()
###

setMethod("is.na", "LLint", function(x) is.na(as.logical(x)))


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Operations from "Ops" group
###

setMethod("Ops", c("LLint", "LLint"),
    function(e1, e2)
    {
        .Call("LLint_Ops", .Generic, e1, e2, PACKAGE="S4Vectors")
    }
)

### If one operand is LLint and the other one is integer, then the latter
### is coerced to LLint.
### If one operand is LLint and the other one is double, then the former
### is coerced to double.
setMethod("Ops", c("LLint", "numeric"),
    function(e1, e2)
    {
        if (is.integer(e2)) {
            e2 <- as.LLint(e2)
        } else {
            ## Suppress "non reversible coercion to double" warning.
            e1 <- suppressWarnings(as.double(e1))
        }
        callGeneric()
    }
)

setMethod("Ops", c("numeric", "LLint"),
    function(e1, e2)
    {
        if (is.integer(e1)) {
            e1 <- as.LLint(e1)
        } else {
            ## Suppress "non reversible coercion to double" warning.
            e2 <- suppressWarnings(as.double(e2))
        }
        callGeneric()
    }
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Operations from "Summary" group
###

setMethod("Summary", "LLint",
    function(x, ..., na.rm=FALSE)
    {
        if (length(list(...)) != 0L)
            stop(wmsg("\"", .Generic, "\" method for LLint objects ",
                      "takes only one object"))
        if (!isTRUEorFALSE(na.rm))
            stop("'na.rm' must be TRUE or FALSE")
        .Call("LLint_Summary", .Generic, x, na.rm=na.rm, PACKAGE="S4Vectors")
    }
)

