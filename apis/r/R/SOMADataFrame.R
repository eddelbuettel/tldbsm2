#' SOMADataFrame
#'
#' @description
#' `SOMADataFrame` is a multi-column table that must contain a column
#' called `soma_joinid` of type `int64`, which contains a unique value for each
#' row and is intended to act as a join key for other objects, such as
#' [`SOMASparseNDArray`].  (lifecycle: experimental)

#' @importFrom stats setNames
#' @export

SOMADataFrame <- R6::R6Class(
  classname = "SOMADataFrame",
  inherit = SOMAArrayBase,

  public = list(

    #' @description Create (lifecycle: experimental)
    #' @param schema an [`arrow::schema`].
    #' @param index_column_names A vector of column names to use as user-defined
    #' index columns.  All named columns must exist in the schema, and at least
    #' one index column name is required.
    #' @template param-platform-config
    #' @param internal_use_only Character value to signal this is a 'permitted' call,
    #' as `create()` is considered internal and should not be called directly.
    create = function(schema, index_column_names = c("soma_joinid"), platform_config = NULL, internal_use_only = NULL) {
      if (is.null(internal_use_only) || internal_use_only != "allowed_use") {
        stop(paste("Use of the create() method is for internal use only. Consider using a",
                   "factory method as e.g. 'SOMADataFrameCreate()'."), call. = FALSE)
      }

      schema <- private$validate_schema(schema, index_column_names)

      attr_column_names <- setdiff(schema$names, index_column_names)
      stopifnot(
        "At least one non-index column must be defined in the schema" =
          length(attr_column_names) > 0
      )

      # Parse the tiledb/create/ subkeys of the platform_config into a handy,
      # typed, queryable data structure.
      tiledb_create_options <- TileDBCreateOptions$new(platform_config)

      # array dimensions
      tdb_dims <- stats::setNames(
        object = vector(mode = "list", length = length(index_column_names)),
        nm = index_column_names
      )

      for (field_name in index_column_names) {
        field <- schema$GetFieldByName(field_name)

        tile_extent <- tiledb_create_options$dim_tile(field_name)

        tile_extent <- switch(field$type$ToString(),
          "int8" = as.integer(tile_extent),
          "int16" = as.integer(tile_extent),
          "int32" = as.integer(tile_extent),
          "int64" = bit64::as.integer64(tile_extent),
          "double" = as.double(tile_extent),
          "string" = NULL,
          tile_extent
        )

        # Default 2048 mods to 0 for 8-bit types and 0 is an invalid extent
        if (field$type$bit_width %||% 0L == 8L) {
          tile_extent <- 64L
        }

        tdb_dims[[field_name]] <- tiledb::tiledb_dim(
          name = field_name,
          # Numeric index types must be positive values for indexing
          domain = arrow_type_unsigned_range(field$type),
          tile = tile_extent,
          type = tiledb_type_from_arrow_type(field$type),
          filter_list = tiledb::tiledb_filter_list(
            tiledb_create_options$dim_filters(
              field_name,
              # Default to use if there is nothing specified in tiledb-create options
              # in the platform config:
              list(
                list(name="ZSTD", COMPRESSION_LEVEL=tiledb_create_options$dataframe_dim_zstd_level())
              )
            )
          )
        )
      }

      # array attributes
      tdb_attrs <- stats::setNames(
        object = vector(mode = "list", length = length(attr_column_names)),
        nm = attr_column_names
      )

      for (field_name in attr_column_names) {
        field <- schema$GetFieldByName(field_name)
        field_type <- tiledb_type_from_arrow_type(field$type)

        tdb_attrs[[field_name]] <- tiledb::tiledb_attr(
          name = field_name,
          type = field_type,
          nullable = field$nullable,
          ncells = if (field_type == "ASCII") NA_integer_ else 1L,
          filter_list = tiledb::tiledb_filter_list(
            tiledb_create_options$attr_filters(field_name)
          )
        )
      }

      # array schema
      cell_tile_orders <- tiledb_create_options$cell_tile_orders()
      tdb_schema <- tiledb::tiledb_array_schema(
        domain = tiledb::tiledb_domain(tdb_dims),
        attrs = tdb_attrs,
        sparse = TRUE,
        cell_order = cell_tile_orders["cell_order"],
        tile_order = cell_tile_orders["tile_order"],
        capacity = tiledb_create_options$capacity(),
        allows_dups = tiledb_create_options$allows_duplicates(),
        offsets_filter_list = tiledb::tiledb_filter_list(
          tiledb_create_options$offsets_filters()
        ),
        validity_filter_list = tiledb::tiledb_filter_list(
          tiledb_create_options$validity_filters()
        )
      )

      # create array
      tiledb::tiledb_array_create(uri = self$uri, schema = tdb_schema)
      self$open("WRITE", internal_use_only = "allowed_use")
      private$write_object_type_metadata()
      self
    },

    #' @description Write (lifecycle: experimental)
    #'
    #' @param values An [`arrow::Table`] or [`arrow::RecordBatch`]
    #' containing all columns, including any index columns. The
    #' schema for `values` must match the schema for the `SOMADataFrame`.
    #'
    write = function(values) {
      private$check_open_for_write()

      # Prevent downcasting of int64 to int32 when materializing a column
      op <- options(arrow.int64_downcast = FALSE)
      on.exit(options(op), add = TRUE, after = FALSE)

      schema_names <- c(self$dimnames(), self$attrnames())
      col_names <- if (is_arrow_record_batch(values)) {
                       arrow::as_arrow_table(values)$ColumnNames()
                   } else {
                       values$ColumnNames()
                   }
      stopifnot(
        "'values' must be an Arrow Table or RecordBatch" =
          (is_arrow_table(values) || is_arrow_record_batch(values)),
        "All columns in 'values' must be defined in the schema" =
          all(col_names %in% schema_names),
        "All schema fields must be present in 'values'" =
          all(schema_names %in% col_names)
      )

      df <- as.data.frame(values)[schema_names]
      arr <- self$object
      arr[] <- df
    },

    #' @description Read (lifecycle: experimental)
    #' Read a user-defined subset of data, addressed by the dataframe indexing
    #' column, and optionally filtered.
    #' @param coords Optional named list of indices specifying the rows to read; each (named)
    #' list element corresponds to a dimension of the same name.
    #' @param column_names Optional character vector of column names to return.
    #' @param value_filter Optional string containing a logical expression that is used
    #' to filter the returned values. See [`tiledb::parse_query_condition`] for
    #' more information.
    #' @template param-result-order
    #' @param iterated Option boolean indicated whether data is read in call (when
    #' `FALSE`, the default value) or in several iterated steps.
    #' @param log_level Optional logging level with default value of `"warn"`.
    #' @return arrow::\link[arrow]{Table} or \link{TableReadIter}
    read = function(coords = NULL,
                    column_names = NULL,
                    value_filter = NULL,
                    result_order = "auto",
                    iterated = FALSE,
                    log_level = "auto") {

      private$check_open_for_read()

      result_order <- match_query_layout(result_order)
      uri <- self$uri
      arr <- self$object                 # need array (schema) to properly parse query condition

      ## if unnamed set names
      if (!is.null(coords)) {
          if (!is.list(coords))
              coords <- list(coords)
          if (is.null(names(coords)))
              names(coords) <- self$dimnames()
      }

      stopifnot(
          ## check columns
          "'column_names' must only contain valid dimension or attribute columns" =
              is.null(column_names) || all(column_names %in% c(self$dimnames(), self$attrnames()))
      )

      coords <- validate_read_coords(coords, dimnames = self$dimnames(), schema = self$schema())

      if (!is.null(value_filter)) {
          value_filter <- validate_read_value_filter(value_filter)
          parsed <- do.call(what = tiledb::parse_query_condition,
                            args = list(expr = str2lang(value_filter), ta = arr))
          value_filter <- parsed@ptr
      }

      cfg <- as.character(tiledb::config(self$tiledbsoma_ctx$context()))
      sr <- sr_setup(uri = self$uri,
                     config = cfg,
                     colnames = column_names,
                     qc = value_filter,
                     dim_points = coords,
                     timestamp_end = private$tiledb_timestamp,
                     loglevel = log_level)

      TableReadIter$new(sr)

    }

  ),

  private = list(

    # @description Validate schema (lifecycle: experimental)
    # Handle default column additions (eg, soma_joinid) and error checking on
    # required columns
    # @return An [`arrow::Schema`], which may be modified by the addition of
    # required columns.
    validate_schema = function(schema, index_column_names) {
      stopifnot(
        "'schema' must be a valid Arrow schema" =
          is_arrow_schema(schema),
        is.character(index_column_names) && length(index_column_names) > 0,
        "All 'index_column_names' must be defined in the 'schema'" =
          assert_subset(index_column_names, schema$names, type = "field"),
        "Column names must not start with reserved prefix 'soma_'" =
          all(!startsWith(setdiff(schema$names, "soma_joinid"), "soma_"))
      )

      # Add soma_joinid column if not present
      if ("soma_joinid" %in% schema$names) {
        stopifnot(
          "soma_joinid field must be of type Arrow int64" =
            schema$GetFieldByName("soma_joinid")$type == arrow::int64()
        )
      } else {
        schema <- schema$AddField(
          i = 0,
          field = arrow::field("soma_joinid", arrow::int64())
        )
      }

      schema
    }

  )
)
