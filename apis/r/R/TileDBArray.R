#' TileDB Array Base Class
#'
#' @description Base class for representing an individual TileDB array.
#' (lifecycle: maturing)
#'
#' @keywords internal
#' @export
TileDBArray <- R6::R6Class(
  classname = "TileDBArray",
  inherit = TileDBObject,
  public = list(

    #' @description Open the SOMA object for read or write.
    #' @param mode Mode to open in; defaults to `READ`.
    #' @param internal_use_only Character value to signal this is a 'permitted' call,
    #' as `open()` is considered internal and should not be called directly.
    #' @return The object, invisibly
    open = function(mode = c("READ", "WRITE"), internal_use_only = NULL) {
      mode <- match.arg(mode)
      if (is.null(internal_use_only) || internal_use_only != "allowed_use") {
        stop(
          "Use of the open() method is for internal use only.\n",
          "  - Consider using a factory method as e.g. 'SOMADataFrameOpen()'.",
          call. = FALSE
        )
      }

      private$.mode <- mode
      if (is.null(self$tiledb_timestamp)) {
        spdl::debug("[TileDBArray$open] Opening {} '{}' in {} mode", self$class(), self$uri, mode)
        private$.tiledb_array <- tiledb::tiledb_array_open(self$object, type = mode)
      } else {
        if (is.null(internal_use_only)) stopifnot("tiledb_timestamp not yet supported for WRITE mode" = mode == "READ")
        spdl::debug(
          "[TileDBArray$open] Opening {} '{}' in {} mode at ({})",
          self$class(),
          self$uri,
          mode,
          self$tiledb_timestamp %||% "now"
        )
        #private$.tiledb_array <- tiledb::tiledb_array_open_at(self$object, type = mode,
        #                                                      timestamp = self$tiledb_timestamp)
      }

      ## TODO -- cannot do here while needed for array case does not work for data frame case
      #private$.type <- arrow_type_from_tiledb_type(tdbtype)

      private$update_metadata_cache()
      self
    },

    #' @description Close the SOMA object.
    #' @return The object, invisibly
    close = function() {
      spdl::debug("[TileDBArray$close] Closing {} '{}'", self$class(), self$uri)
      private$.mode = "CLOSED"
      tiledb::tiledb_array_close(self$object)
      invisible(self)
    },

    #' @description Print summary of the array. (lifecycle: maturing)
    print = function() {
      super$print()
      if (self$exists()) {
        cat("  dimensions:", string_collapse(self$dimnames()), "\n")
        cat("  attributes:", string_collapse(self$attrnames()), "\n")
      }
    },

    #' @description Return a [`TileDBArray`] object (lifecycle: maturing)
    #' @param ... Optional arguments to pass to `tiledb::tiledb_array()`
    #' @return A [`tiledb::tiledb_array`] object.
    tiledb_array = function(...) {
      args <- list(...)
      args$uri <- self$uri
      args$query_type <- self$.mode
      args$query_layout <- "UNORDERED"
      args$ctx <- self$tiledbsoma_ctx$context()
      spdl::debug("[TileDBArray$tiledb_array] ctor uri {} mode {} layout {}", args$uri, args$query_type, args$query_layout)
      do.call(tiledb::tiledb_array, args)
    },

    #' @description Retrieve metadata from the TileDB array. (lifecycle: maturing)
    #' @param key The name of the metadata attribute to retrieve.
    #' @return A list of metadata values.
    get_metadata = function(key = NULL) {
      private$check_open_for_read_or_write()

      spdl::debug("[TileDBArray$get_metadata] Retrieving metadata for {} '{}'", self$class(), self$uri)
      private$fill_metadata_cache_if_null()
      if (!is.null(key)) {
        val <- private$.metadata_cache[[key]]
        if (is.list(val)) val <- unlist(val)
        val
      } else {
        private$.metadata_cache
      }
    },

    #' @description Add list of metadata to the specified TileDB array. (lifecycle: maturing)
    #' @param metadata Named list of metadata to add.
    #' @return NULL
    set_metadata = function(metadata) {
      stopifnot(
        "Metadata must be a named list" = is_named_list(metadata)
      )

      #private$check_open_for_write()

      for (nm in names(metadata)) {
          val <- metadata[[nm]]
          spdl::debug("[TileDBArray$set_metadata] setting key {} to {} ({})", nm, val, class(val))
          set_metadata(
            uri = self$uri,
            key = nm,
            valuesxp = val,
            type = class(val),
            is_array = TRUE,
            ctxxp = soma_context(),
            tsvec = self$.tiledb_timestamp_range
          )
      }

      dev_null <- mapply(
        FUN = private$add_cached_metadata,
        key = names(metadata),
        val = metadata,
        SIMPLIFY = FALSE
      )
    },

    #' @description Retrieve the array schema as an Arrow schema (lifecycle: maturing)
    #' @return A [`arrow::schema`] object
    schema = function() {
      arrow_schema_from_tiledb_schema(tiledb::schema(self$object))
    },

    #' @description Retrieve the array schema as TileDB schema (lifecycle: maturing)
    #' @return A [`tiledb::tiledb_array_schema`] object
    tiledb_schema = function() {
      tiledb::schema(self$object)
    },

    #' @description Retrieve the array dimensions (lifecycle: maturing)
    #' @return A named list of [`tiledb::tiledb_dim`] objects
    dimensions = function() {
      dims <- tiledb::dimensions(self$tiledb_schema())
      setNames(dims, nm = vapply_char(dims, tiledb::name))
    },

    #' @description Retrieve the shape, i.e. the capacity of each dimension.
    #' This will not necessarily match the bounds of occupied cells within the
    #' array.  Rather, it is the bounds outside of which no data may be written.
    #' (lifecycle: maturing)
    #' @return A named vector of dimension length (and the same type as the dimension)
    shape = function() {
      as.integer64(shape(self$uri, private$.soma_context))
    },

    #' @description Retrieve the maxshape, i.e. maximum possible that the
    # shape can be resized up to.
    #' (lifecycle: maturing)
    #' @return A named vector of dimension length (and the same type as the dimension)
    maxshape = function() {
      as.integer64(maxshape(self$uri, private$.soma_context))
    },

    #' @description Retrieve the range of indexes for a dimension that were
    #'  explicitly written.  This method is deprecated as of TileDB-SOMA 1.13, and will be
    #' removed in TileDB-SOMA 1.14.
    #' @param simplify Return a vector of [`bit64::integer64`]s containing only
    #' the upper bounds.
    #' @param index1 Return the used shape with 1-based indices (0-based indices are returned by default)
    #' @return A list containing the lower and upper bounds for the used shape.
    #' If `simplify = TRUE`, returns a vector of only the upper bounds.
    used_shape = function(simplify = FALSE, index1 = FALSE) {
      stopifnot(
        isTRUE(simplify) || isFALSE(simplify),
        isTRUE(index1) || isFALSE(index1)
      )
      .Deprecated(new="shape", msg="The 'used_shape' function will be removed in TileDB-SOMA 1.14.")
      dims <- self$dimnames()
      utilized <- vector(mode = 'list', length = length(dims))
      names(utilized) <- dims
      for (i in seq_along(along.with = utilized)) {
        key <- paste0(dims[i], '_domain')
        dom <- bit64::integer64(2L)
        names(dom) <- c('_lower', '_upper')
        for (type in names(dom)) {
          dom[type] <- self$get_metadata(paste0(key, type)) %||% bit64::NA_integer64_
          if (any(is.na(dom))) {
            dom <- bit64::NA_integer64_
          }
          utilized[[i]] <- unname(dom)
        }
        # utilized[[i]] <- self$get_metadata(key) %||% bit64::NA_integer64_
      }
      if (any(vapply_lgl(utilized, rlang::is_na))) {
        stop(
          "This array was not written with bounding box support; for an approximation, please use `$non_empty_domain()` instead",
          call. = FALSE
        )
      }
      if (index1) {
        for (i in seq_along(utilized)) {
          utilized[[i]] <- utilized[[i]] + 1L
        }
      }
      if (simplify) {
        tmp <- utilized
        utilized <- bit64::integer64(length(utilized))
        names(utilized) <- names(tmp)
        for (i in seq_along(utilized)) {
          utilized[i] <- tmp[[i]][2L]
        }
      }
      return(utilized)
    },

    #' @description Retrieve the non-empty domain for each dimension. This
    #' method calls [`tiledb::tiledb_array_get_non_empty_domain_from_name`] for
    #' each dimension in the array.
    #' @param index1 Return the non-empty domain with 1-based indices.
    #' @return A vector of [`bit64::integer64`]s with one entry for
    #' each dimension.
    non_empty_domain = function(index1 = FALSE) {
      dims <- self$dimnames()
      ned <- bit64::integer64(length = length(dims))
      ## added during C++-ification as self$object could close
      if (isFALSE(tiledb::tiledb_array_is_open(self$object))) {
          arrhandle <- tiledb::tiledb_array_open(self$object, type = "READ")
      } else {
          arrhandle <- self$object
      }
      for (i in seq_along(along.with = ned)) {
        dom <- max(tiledb::tiledb_array_get_non_empty_domain_from_name(
          arrhandle, # instead of:  self$object,
          name = dims[i]
        ))
        if (isTRUE(x = index1)) {
          dom <- dom + 1L
        }
        ned[i] <- dom
      }
      return(ned)
    },

    #' @description Retrieve number of dimensions (lifecycle: maturing)
    #' @return A scalar with the number of dimensions
    ndim = function() {
      dims <- tiledb::dimensions(self$tiledb_schema())
      length(dims)
    },

    #' @description Retrieve the array attributes (lifecycle: maturing)
    #' @return A list of [`tiledb::tiledb_attr`] objects
    attributes = function() {
      tiledb::attrs(self$tiledb_schema())
    },

    #' @description Retrieve dimension names (lifecycle: maturing)
    #' @return A character vector with the array's dimension names
    dimnames = function() {
      vapply(
        self$dimensions(),
        FUN = tiledb::name,
        FUN.VALUE = vector("character", 1L),
        USE.NAMES = FALSE
      )
    },

    #' @description Retrieve attribute names (lifecycle: maturing)
    #' @return A character vector with the array's attribute names
    attrnames = function() {
      vapply(
        self$attributes(),
        FUN = tiledb::name,
        FUN.VALUE = vector("character", 1L),
        USE.NAMES = FALSE
      )
    },

    #' @description Retrieve the names of all columns, including dimensions and
    #' attributes (lifecycle: maturing)
    #' @return A character vector with the array's column names
    colnames = function() {
      c(self$dimnames(), self$attrnames())
    },

    #' @description Retrieve names of index (dimension) columns (lifecycle: maturing)
    #' @return A character vector with the array index (dimension) names
    index_column_names = function() {
      self$dimnames()
    },

    #' @description Get number of fragments in the array (lifecycle: maturing)
    fragment_count = function() {
      tiledb::tiledb_fragment_info_get_num(
        tiledb::tiledb_fragment_info(self$uri)
      )
    }
  ),

  active = list(
    #' @field object Access the underlying TileB object directly (either a
    #' [`tiledb::tiledb_array`] or [`tiledb::tiledb_group`]).
    object = function(value) {
      if (!missing(value)) {
        stop(sprintf("'%s' is a read-only field.", "object"), call. = FALSE)
      }
      # If the array was created after the object was instantiated, we need to
      # initialize private$.tiledb_array
      if (is.null(private$.tiledb_array)) {
        private$initialize_object()
      }
      private$.tiledb_array
    }
  ),

  private = list(

    # Internal pointer to the TileDB array.
    #
    # Important implementation note:
    # * In TileDB-R there is an unopened handle obtained by tiledb::tiledb_array, which takes
    #   a URI as its argument.
    # * One may then open and close this using tiledb::tiledb_array_open (for read or write)
    #   and tiledb::tiledb_array_close, which take a tiledb_array handle as their first argument.
    #
    # However, for groups:
    # * tiledb::tiledb_group and tiledb::group_open both return an object opened for read or write.
    # * Therefore for groups we cannot imitate the behavior for arrays.
    #
    # For this reason there is a limit to how much handle-abstraction we can do in the TileDBObject
    # parent class. In particular, we cannot have a single .tiledb_object shared by both TileDBArray
    # and TileDBGroup.
    .tiledb_array = NULL,

    # Initially NULL, once the array is created or opened, this is populated
    # with a list that's empty or contains the array metadata. Since the SOMA
    # spec requires that we allow readback of array metadata even when the array
    # is open for write, but the TileDB layer underneath us does not, we must
    # have this cache.
    .metadata_cache = NULL,

    # Once the array has been created this initializes the TileDB array object
    # and stores the reference in private$.tiledb_array.
    initialize_object = function() {
      private$.tiledb_array <- tiledb::tiledb_array(
        uri = self$uri,
        ctx = self$tiledbsoma_ctx$context(),
        query_layout = "UNORDERED"
      )
    },

    # ----------------------------------------------------------------
    # Metadata-caching

    fill_metadata_cache_if_null = function() {
      if (is.null(private$.metadata_cache)) {
        private$update_metadata_cache()
      }
    },

    update_metadata_cache = function() {
      spdl::debug("[TileDBArray$update_metadata_cache] updating metadata cache for {} '{}' in {}", self$class(), self$uri, private$.mode)

      # See notes above -- at the TileDB implementation level, we cannot read array metadata
      # while the array is open for read, but at the SOMA application level we must support
      # this. Therefore if the array is opened for write and there is no cache populated then
      # we must open a temporary handle for read, to fill the cache.
      #array_handle <- private$.tiledb_array
      #if (private$.mode == "WRITE") {
      #  spdl::debug("[TileDBArray::update_metadata_cache] getting object")
      #  array_object <- tiledb::tiledb_array(self$uri, ctx = private$.tiledb_ctx)
      #  array_handle <- tiledb::tiledb_array_open(array_object, type = "READ")
      #}

      #if (isFALSE(tiledb::tiledb_array_is_open(array_handle))) {
      #  spdl::debug("[TileDBArray::update_metadata_cache] reopening object")
      #  array_handle <- tiledb::tiledb_array_open(array_handle, type = "READ")
      #}

      private$.metadata_cache <- get_all_metadata(self$uri, TRUE, soma_context())
      #print(str(private$.metadata_cache))
      #if (private$.mode == "WRITE") {
      #  tiledb::tiledb_array_close(array_handle)
      #}

      invisible(NULL)
    },

    add_cached_metadata = function(key, value) {
      if (is.null(private$.metadata_cache)) {
        private$.metadata_cache <- list()
      }
      private$.metadata_cache[[key]] <- value
    }

  )
)
