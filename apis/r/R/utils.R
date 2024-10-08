#' @importFrom glue glue_collapse
string_collapse <- function(x, sep = ", ") {
  glue::glue_collapse(x, sep = sep, width = getOption("width", Inf))
}

n_unique <- function(x) {
  length(unique(x))
}

vapply_char <- function(X, FUN, ..., USE.NAMES = TRUE) {
  vapply(X, FUN, FUN.VALUE = character(1L), ..., USE.NAMES = USE.NAMES)
}

vapply_lgl <- function(X, FUN, ..., USE.NAMES = TRUE) {
  vapply(X, FUN, FUN.VALUE = logical(1L), ..., USE.NAMES = USE.NAMES)
}

vapply_int <- function(X, FUN, ..., USE.NAMES = TRUE) {
  vapply(X, FUN, FUN.VALUE = integer(1L), ..., USE.NAMES = USE.NAMES)
}

# rename(iris, c(petal_length = "Petal.Length", species = "Species", hi = "YO"))
rename <- function(x, names) {
  stopifnot(
    "'x' must be named" = is_named(x),
    "'names' must be a named character vector" = is_named(names),
    "All 'names' must be in 'x'" = all(names %in% names(x))
  )

  name_index <- match(names, names(x))
  names(x)[name_index] <- names(names)
  x
}

# Return y if x is NULL, else x
`%||%` <- function(x, y) {
  if (missing(x) || is.null(x) || length(x) == 0) y else x
}

err_to_warn <- function(err, immediate. = TRUE) {
  warning(conditionMessage(err), call. = FALSE, immediate. = immediate.)
  return(invisible(err))
}

null <- function(...) {
  return(NULL)
}

random_name <- function(length = 5L, chars = letters, ...) {
  stopifnot(
    "'length' must be a single integer" = is_integerish(length, n = 1L),
    "'chars' must be character" = is.character(chars)
  )
  chars <- unique(unlist(strsplit(chars, split = '')))
  return(paste(sample(chars, size = length, ...), collapse = ''))
}

uns_hint <- function(type = c('1d', '2d')) {
  type <- match.arg(type)
  hint <- list(paste0('array_', type))
  names(hint) <- 'soma_uns_outgest_hint'
  return(hint)
}

.encode_as_char <- function(x) {
  return(switch(
    EXPR = typeof(x),
    double = sprintf('%a', x),
    x
  ))
}

.err_to_warn <- function(err) {
  warning(warningCondition(
    message = conditionMessage(err),
    class = setdiff(class(err), c('warning', 'simpleError', 'error', 'condition')),
    call = conditionCall(err)
  ))
}

.decode_from_char <- function(x) {
  stopifnot(is.character(x))
  double <- paste0(
    '^',
    c(
      '[-]?0x[0-9a-f](\\.[0-9a-f]+)?p[+-][0-9]+',
      '[-]?Inf',
      'NA',
      'NaN'
    ),
    '$',
    collapse = '|'
  )
  return(if (all(grepl(double, x))) {
    as.numeric(x)
  } else {
    x
  })
}

.maybe_muffle <- function(w, cond = getOption('verbose', default = FALSE)) {
  if (isTRUE(x = cond)) {
    warning(warningCondition(
      message = conditionMessage(w),
      class = setdiff(class(w), c('warning', 'simpleError', 'error', 'condition')),
      call = conditionCall(w)
    ))
  } else {
    tryInvokeRestart('muffleWarning')
  }
}

#' Read the SOMA Join IDs from an Array
#'
#' @param x A \code{\link{SOMASparseNDarray}} or \code{\link{SOMADataFrame}}
#'
#' @return An \code{\link[bit64]{integer64}} vector with the SOMA join IDs
#'
#' @keywords internal
#'
#' @noRd
#'
.read_soma_joinids <- function(x, ...) {
  stopifnot(inherits(x = x, what = 'TileDBArray'))
  oldmode <- x$mode()
  on.exit(
    x$reopen(oldmode, tiledb_timestamp = x$tiledb_timestamp),
    add = TRUE,
    after = FALSE
  )
  op <- options(arrow.int64_downcast = FALSE)
  on.exit(options(op), add = TRUE, after = FALSE)
  ids <- UseMethod(generic = '.read_soma_joinids', object = x)
  return(ids)
}

#' @rdname dot-read_soma_joinids
#'
#' @noRd
#'
#' @method .read_soma_joinids SOMADataFrame
#' @export
#'
.read_soma_joinids.SOMADataFrame <- function(x, ...) {
  x$reopen("READ", tiledb_timestamp = x$tiledb_timestamp)
  return(x$read(column_names = "soma_joinid")$concat()$GetColumnByName("soma_joinid")$as_vector())
}

#' @param axis Which dimension to read (zero-based)
#'
#' @rdname dot-read_soma_joinids
#'
#' @noRd
#'
#' @method .read_soma_joinids SOMASparseNDArray
#' @export
#'
.read_soma_joinids.SOMASparseNDArray <- function(x, axis = 0L, ...) {
  stopifnot(
    "'axis' must be a single positive integer" = is.integer(axis) &&
      length(axis) == 1L
  )
  if (axis < 0L || axis >= length(x$dimnames())) {
    stop("'axis' must be between 0 and ", length(x$dimnames()), call. = FALSE)
  }
  x$reopen("READ", tiledb_timestamp = x$tiledb_timestamp)
  dimname <- x$dimnames()[axis + 1L]
  sr <- sr_setup(
    uri = x$uri,
    soma_context(),
    colnames = dimname,
    timestamprange = x$.tiledb_timestamp_range
  )
  return(TableReadIter$new(sr)$concat()$GetColumnByName(dimname)$as_vector())
}

#' Pad Names of a Character Vector
#'
#' Fill in missing names of a vector using missing values of said vector
#'
#' @param x A character vector
#'
#' @return \code{x} with any missing names set to the values of \code{x}; see
#' examples for more details
#'
#' @keywords internal
#'
#' @noRd
#'
#' @examples
#' x1 <- c("a", "b", "c")
#' pad_names(x1) # returns c(a = "a", b = "b", c = "c")
#'
#' x2 <- c(a = "x", b = "y", c = "z")
#' pad_names(x2) # returns c(a = "x", b = "y", c = "z")
#'
#' x3 <- c(a = "x", "y", c = "z")
#' pad_names(x3) # returns c(a = "x", y = "y", c = "z")
#'
pad_names <- function(x) {
  stopifnot(
    is.character(x)
  )
  if (is.null(names(x))) {
    return(stats::setNames(nm = x))
  }
  unnamed <- !nzchar(names(x))
  names(x)[unnamed] <- x[unnamed]
  return(x)
}

# For use in read-only R6 active bindings
read_only_error <- function(field_name) {
  stop(
    sprintf("'%s' is a read-only field.", field_name),
    call. = FALSE
  )
}

SOMA_OBJECT_TYPE_METADATA_KEY <- "soma_object_type"
SOMA_ENCODING_VERSION_METADATA_KEY <- "soma_encoding_version"
SOMA_ENCODING_VERSION <- "1"

#' @importFrom Matrix as.matrix
#' @importFrom arrow RecordBatch
#' @import R6 methods utils
##' @importFrom Rcpp evalCpp
##' @importFrom spdl setup
##' @useDynLib tiledbsoma, .registration=TRUE
NULL
