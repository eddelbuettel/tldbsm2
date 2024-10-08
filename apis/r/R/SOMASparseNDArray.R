#' SOMASparseNDArray
#'
#' @description
#' `SOMASparseNDArray` is a sparse, N-dimensional array with offset
#' (zero-based) integer indexing on each dimension. The `SOMASparseNDArray` has
#' a user-defined schema, which includes:
#'
#' - type - a `primitive` type, expressed as an Arrow type (e.g., `int64`, `float32`, etc)
#' - shape - the shape of the array, i.e., number and length of each dimension
#'
#' All dimensions must have a positive, non-zero length.
#'
#' **Note** - on TileDB this is an sparse array with `N` int64 dimensions of
#' domain [0, maxInt64), and a single attribute.
#'
#' ## Duplicate writes
#'
#' As duplicate index values are not allowed, index values already present in
#' the object are overwritten and new index values are added. (lifecycle: maturing)
#'
#' @export
SOMASparseNDArray <- R6::R6Class(
  classname = "SOMASparseNDArray",
  inherit = SOMANDArrayBase,

  public = list(

    #' @description Reads a user-defined slice of the \code{SOMASparseNDArray}
    #' @param coords Optional `list` of integer vectors, one for each dimension, with a
    #' length equal to the number of values to read. If `NULL`, all values are
    #' read. List elements can be named when specifying a subset of dimensions.
    #' @template param-result-order
    #' @param iterated Option boolean indicated whether data is read in call (when
    #' `FALSE`, the default value) or in several iterated steps.
    #' @param log_level Optional logging level with default value of `"warn"`.
    #' @return \link{SOMASparseNDArrayRead}
    read = function(
      coords = NULL,
      result_order = "auto",
      log_level = "auto"
    ) {
      private$check_open_for_read()
      result_order <- map_query_layout(match_query_layout(result_order))

      if (!is.null(coords)) {
        coords <- private$.convert_coords(coords)
      }

      ## not needed anymore  cfg <- as.character(tiledb::config(self$tiledbsoma_ctx$context()))
      sr <- sr_setup(uri = self$uri,
                     private$.soma_context,
                     dim_points = coords,
                     result_order = result_order,
                     timestamprange = self$.tiledb_timestamp_range,
                     loglevel = log_level)
      SOMASparseNDArrayRead$new(sr, self, coords)
    },

    #' @description Write matrix-like data to the array. (lifecycle: maturing)
    #'
    #' @param values Any `matrix`-like object coercible to a
    #' [`TsparseMatrix`][`Matrix::TsparseMatrix-class`]. Character dimension
    #' names are ignored because `SOMANDArray`'s use integer indexing.
    #' @param bbox A vector of integers describing the upper bounds of each
    #' dimension of `values`. Generally should be `NULL`.
    #'
    write = function(values, bbox = NULL) {
      stopifnot(
        "'values' must be a matrix" = is_matrix(values),
        "'bbox' must contain two entries" = is.null(bbox) || length(bbox) == length(dim(values)),
        "'bbox' must be a vector of two integers or a list with each entry containg two integers" = is.null(bbox) ||
          (is_integerish(bbox) || bit64::is.integer64(bbox)) ||
          (is.list(bbox) && all(vapply_lgl(bbox, function(x, n) length(x) == 2L)))
      )
      # coerce to a TsparseMatrix, which uses 0-based COO indexing
      values <- as(values, Class = "TsparseMatrix")
      coo <- data.frame(
        i = bit64::as.integer64(values@i),
        j = bit64::as.integer64(values@j),
        x = values@x
      )
      dnames <- self$dimnames()
      colnames(coo) <- c(dnames, self$attrnames())
      ranges <- sapply(
        X = dnames,
        FUN = function(x) {
          return(range(coo[[x]]))
        },
        simplify = FALSE,
        USE.NAMES = TRUE
      )
      bbox <- bbox %||% setNames(
        lapply(
          X = dim(x = values) - 1L,
          FUN = function(x) {
            bit64::as.integer64(c(0L, x))
          }
        ),
        nm = dnames
      )
      if (is.null(names(bbox))) {
        names(bbox) <- dnames
      }
      if (!is_named(bbox, allow_empty = FALSE)) {
        # Determine which indexes of `bbox` are unnamed (incl empty strings "")
        # Python equivalent:
        # bbox = pandas.Series([[0, 99], [0, 299]], index=["soma_dim_0", ""])
        # [i for i, key in enumerate(bbox.keys()) if not len(key)]
        idx <- which(!nzchar(names(bbox)))
        names(bbox)[idx] <- dnames[idx]
      }
      if (!identical(sort(names(bbox)), sort(dnames))) {
        stop("The names of 'bbox' must be the names of the array")
      }
      if (is_integerish(bbox) || bit64::is.integer64(bbox)) {
        bbox <- sapply(
          X = names(bbox),
          FUN = function(x) {
            return(sort(c(min(ranges[[x]]), bbox[[x]])))
          },
          simplify = FALSE
        )
      }
      for (x in dnames) {
        xrange <- bbox[[x]]
        if (any(is.na(xrange))) {
          stop(
            "Ranges in the bounding box must be finite (offending: ",
            sQuote(x),
            ")",
            call. = FALSE
          )
        }
        if (!(is_integerish(xrange) || bit64::is.integer64(xrange))) {
          stop(
            "Ranges in the bounding box must be integers (offending: ",
            sQuote(x),
            ")",
            call. = FALSE
          )
        }
        xrange <- sort(bit64::as.integer64(xrange))
        if (length(xrange) != 2L) {
          stop(
            "Ranges in the bounding box must consist of two integerish values",
            call. = FALSE
          )
        }
        if (xrange[1L] < 0 || xrange[1L] > min(ranges[[x]])) {
          stop(
            "Ranges in the bounding box must be greater than zero and less than the lowest value being added (offending: ",
            sQuote(x),
            ")",
            call. = FALSE
          )
        }
        if (xrange[2L] < max(ranges[[x]])) {
          stop(
            "Ranges in the bounding box must be greater than the largest value being added (offending: ",
            sQuote(x),
            ")",
            call. = FALSE
          )
        }
        bbox[[x]] <- xrange
      }
      names(bbox) <- paste0(names(bbox), '_domain')
      bbox_flat <- vector(mode = 'list', length = length(x = bbox) * 2L)
      index <- 1L
      for (i in seq_along(bbox)) {
        bbox_flat[[index]] <- bbox[[i]][1L]
        bbox_flat[[index + 1L]] <- bbox[[i]][2L]
        names(bbox_flat)[index:(index + 1L)] <- paste0(names(bbox)[i], c('_lower', '_upper'))
        index <- index + 2L
      }
      self$set_metadata(bbox_flat)
      spdl::debug(
        "[SOMASparseNDArray$write] Calling .write_coo_df ({})",
        self$tiledb_timestamp %||% "now"
      )

      private$.write_coo_dataframe(coo)

      invisible(self)
    },

    #' @description Retrieve number of non-zero elements (lifecycle: maturing)
    #' @return A scalar with the number of non-zero elements
    nnz = function() {
      nnz(self$uri, private$.soma_context)
    },

    #' @description Increases the shape of the array as specfied. Raises an error
    #' if the new shape is less than the current shape in any dimension. Raises
    #' an error if the new shape exceeds maxshape in any dimension. Raises an
    #' error if the array doesn't already have a shape: in that case please call
    #' tiledbsoma_upgrade_shape.
    #' @param new_shape A vector of integerish, of the same length as the array's `ndim`.
    #' @return No return value
    resize = function(new_shape) {
      # TODO: move this to SOMANDArrayBase.R once core offers current-domain support for dense arrays.
      # https://github.com/single-cell-data/TileDB-SOMA/issues/2955

      stopifnot("'new_shape' must be a vector of integerish values, of the same length as maxshape" = rlang::is_integerish(new_shape, n = self$ndim()) ||
        (bit64::is.integer64(new_shape) && length(new_shape) == self$ndim())
      )
      # Checking slotwise new shape >= old shape, and <= max_shape, is already done in libtiledbsoma
      resize(self$uri, new_shape, private$.soma_context)
    },

    #' @description Allows the array to have a resizeable shape as described in the
    #' TileDB-SOMA 1.15 release notes.  Raises an error if the shape exceeds maxshape in any
    #' dimension. Raises an error if the array already has a shape.
    #' @param shape A vector of integerish, of the same length as the array's `ndim`.
    #' @return No return value
    tiledbsoma_upgrade_shape = function(shape) {
      # TODO: move this to SOMANDArrayBase.R once core offers current-domain support for dense arrays.
      # https://github.com/single-cell-data/TileDB-SOMA/issues/2955

      stopifnot("'shape' must be a vector of integerish values, of the same length as maxshape" = rlang::is_integerish(shape, n = self$ndim()) ||
        (bit64::is.integer64(shape) && length(shape) == self$ndim())
      )
      # Checking slotwise new shape >= old shape, and <= max_shape, is already done in libtiledbsoma
      tiledbsoma_upgrade_shape(self$uri, shape, private$.soma_context)
    }

  ),

  private = list(
    .is_sparse = TRUE,

    # Given a user-specified shape along a particular dimension, returns a named
    # list containing name, capacity, and extent elements. If no shape is
    # provided the .Machine$integer.max - 1 is used.
    .dim_capacity_and_extent = function(name, shape = NULL, create_options) {
      out <- list(name = name, capacity = NULL, extent = NULL)

      if (is.null(shape)) {
        out$capacity <- .Machine$integer.max - 1
        out$extent <- min(out$capacity, create_options$dim_tile(name))
      } else {
        stopifnot(
          "'shape' must be a positive scalar integer" =
            rlang::is_scalar_integerish(shape) && shape > 0
        )
        out$capacity <- shape
        out$extent <- min(shape, create_options$dim_tile(name))
      }

      out
    },

    # @description Ingest COO-formatted dataframe into the TileDB array.
    # (lifecycle: maturing)
    # @param values A [`data.frame`].
    .write_coo_dataframe = function(values) {
      private$check_open_for_write()

      stopifnot(is.data.frame(values))
      # private$log_array_ingestion()
      #arr <- self$object
      #if (!is.null(self$tiledb_timestamp)) {
      #    # arr@timestamp <- self$tiledb_timestamp
      #   arr@timestamp_end <- self$tiledb_timestamp
      #}
      nms <- colnames(values)

      ## the 'soma_data' data type may not have been cached, and if so we need to fetch it
      if (is.null(private$.type)) {
          ## TODO: replace with a libtiledbsoma accessor as discussed
          tpstr <- tiledb::datatype(tiledb::attrs(tiledb::schema(self$uri))[["soma_data"]])
          arstr <- arrow_type_from_tiledb_type(tpstr)
          private$.type <- arstr
      }

      arrsch <- arrow::schema(arrow::field(nms[1], arrow::int64()),
                              arrow::field(nms[2], arrow::int64()),
                              arrow::field(nms[3], private$.type))

      tbl <- arrow::arrow_table(values, schema = arrsch)
      spdl::debug(
        "[SOMASparseNDArray$write] array created, writing to {} at ({})",
        self$uri,
        self$tiledb_timestamp %||% "now"
      )
      naap <- nanoarrow::nanoarrow_allocate_array()
      nasp <- nanoarrow::nanoarrow_allocate_schema()
      arrow::as_record_batch(tbl)$export_to_c(naap, nasp)
      writeArrayFromArrow(
        uri = self$uri,
        naap = naap,
        nasp = nasp,
        ctxxp = private$.soma_context,
        arraytype = "SOMASparseNDArray",
        config = NULL,
        tsvec = self$.tiledb_timestamp_range
      )
    },

    # Internal marking of one or zero based matrices for iterated reads
    zero_based = NA

  )
)
