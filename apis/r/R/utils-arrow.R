is_arrow_object <- function(x) {
  inherits(x, "ArrowObject")
}

is_arrow_data_type <- function(x) {
  is_arrow_object(x) && inherits(x, "DataType")
}

is_arrow_field <- function(x) {
  is_arrow_object(x) && inherits(x, "Field")
}

is_arrow_record_batch <- function(x) {
  is_arrow_object(x) && inherits(x, "RecordBatch")
}

is_arrow_array <- function(x) {
  is_arrow_object(x) && inherits(x, "Array")
}

is_arrow_chunked_array <- function(x) {
  is_arrow_object(x) && inherits(x, "ChunkedArray")
}

is_arrow_table <- function(x) {
  is_arrow_object(x) && inherits(x, "Table")
}

is_arrow_schema <- function(x) {
  is_arrow_object(x) && inherits(x, "Schema")
}

is_arrow_dictionary <- function(x) {
  is_arrow_object(x) && inherits(x, "Field") && inherits(x$type, "DictionaryType")
}

#' Convert Arrow types to supported TileDB type
#' List of TileDB types supported in R: https://github.com/TileDB-Inc/TileDB-R/blob/8014da156b5fee5b4cc221d57b4aa7d388abc968/inst/tinytest/test_dim.R#L97-L121
#' Note: TileDB attrs may be UTF-8; TileDB dims may not.
#'
#' List of all arrow types: https://github.com/apache/arrow/blob/90aac16761b7dbf5fe931bc8837cad5116939270/r/R/type.R#L700
#' @noRd

tiledb_type_from_arrow_type <- function(x, is_dim) {
  stopifnot(is_arrow_data_type(x))
  retval <- switch(x$name,
    int8 = "INT8",
    int16 = "INT16",
    int32 = "INT32",
    int64 = "INT64",
    uint8 = "UINT8",
    uint16 = "UINT16",
    uint32 = "UINT32",
    uint64 = "UINT64",
    float32 = "FLOAT32",
    float = "FLOAT32",
    float64 = "FLOAT64",
    # based on tiledb::r_to_tiledb_type()
    double = "FLOAT64",
    boolean = "BOOL",
    bool = "BOOL",
    # large_string = "large_string",
    # binary = "binary",
    # large_binary = "large_binary",
    # fixed_size_binary = "fixed_size_binary",
    utf8 = "UTF8",
    string = "UTF8",
    large_utf8 = "UTF8",
    # based on what TileDB supports
    date32 = "DATETIME_DAY",
    # date64 = "date64",
    # time32 = "time32",
    # time64 = "time64",
    # null = "null",
    # based on what TileDB supports with a default msec res.
    timestamp = "DATETIME_MS",
    # decimal128 = "decimal128",
    # decimal256 = "decimal256",
    # struct = "struct",
    # list_of = "list",
    # list = "list",
    # large_list_of = "large_list",
    # large_list = "large_list",
    # fixed_size_list_of = "fixed_size_list",
    # fixed_size_list = "fixed_size_list",
    # map_of = "map",
    # duration = "duration",
    dictionary = tiledb_type_from_arrow_type(x$index_type, is_dim=is_dim),
    stop("Unsupported Arrow data type: ", x$name, call. = FALSE)
  )
  if (is_dim && retval == "UTF8") {
    retval <- "ASCII"
  }
  retval
}

arrow_type_from_tiledb_type <- function(x) {
  stopifnot(is.character(x))
  switch(x,
    INT8 = arrow::int8(),
    INT16 = arrow::int16(),
    INT32 = arrow::int32(),
    INT64 = arrow::int64(),
    UINT8 = arrow::uint8(),
    UINT16 = arrow::uint16(),
    UINT32 = arrow::uint32(),
    UINT64 = arrow::uint64(),
    FLOAT32 = arrow::float32(),
    FLOAT64 = arrow::float64(),
    BOOL = arrow::boolean(),
    ASCII = arrow::utf8(),
    UTF8 = arrow::utf8(),
    stop("Unsupported data type: ", x, call. = FALSE)
  )
}

#' Retrieve limits for Arrow types
#' @importFrom bit64 lim.integer64
#' @noRd
arrow_type_range <- function(x) {
  stopifnot(is_arrow_data_type(x))

  switch(x$name,
    int8 = c(-128L, 127L),
    int16 = c(-32768L, 32767L),
    int32 = c(-2147483647L, 2147483647L),
    int64 = bit64::lim.integer64(),
    uint8 = c(0L, 255L),
    uint16 = c(0L, 65535L),
    uint32 = bit64::as.integer64(c(0, 4294967295)),
    # We can't specify the full range of uint64 in R so we use the max of int64
    uint64 = c(bit64::as.integer64(0), bit64::lim.integer64()[2]),
    # float32/float
    float = c(-3.4028235e+38, 3.4028235e+38),
    # float64/double
    double =  c(.Machine$double.xmin, .Machine$double.xmax),
    # boolean/bool
    bool = NULL,
    # string/utf8
    utf8 = NULL,
    large_utf8 = NULL,
    stop("Unsupported data type:", x$name, call. = FALSE)
  )
}

#' Retrieve unsigned limits for Arrow types
#' This restricts the lower bound of signed numeric types to 0
#' @noRd
arrow_type_unsigned_range <- function(x) {
  range <- arrow_type_range(x)
  range[1] <- switch(x$name,
    int8 = 0L,
    int16 = 0L,
    int32 = 0L,
    int64 = bit64::as.integer64(0),
    float = 0,
    double = 0,
    range[1]
  )
  range
}

#' Create an Arrow field from a TileDB dimension
#' @noRd
arrow_field_from_tiledb_dim <- function(x) {
  stopifnot(inherits(x, "tiledb_dim"))
  arrow::field(
    name = tiledb::name(x),
    type = arrow_type_from_tiledb_type(tiledb::datatype(x)),
    nullable = FALSE
  )
}

## With a nod to Kevin Ushey
#' @noRd
yoink <- function(package, symbol) {
    do.call(":::", list(package, symbol))
}


#' Create an Arrow field from a TileDB attribute
#' @noRd
arrow_field_from_tiledb_attr <- function(x, arrptr=NULL) {
    stopifnot(inherits(x, "tiledb_attr"))
    if (tiledb::tiledb_attribute_has_enumeration(x) && !is.null(arrptr)) {
        .tiledb_array_is_open <- yoink("tiledb", "libtiledb_array_is_open")
        if (!.tiledb_array_is_open(arrptr)) {
            .tiledb_array_open_with_ptr <- yoink("tiledb", "libtiledb_array_open_with_ptr")
            arrptr <- .tiledb_array_open_with_ptr(arrptr, "READ")
        }
        ord <- tiledb::tiledb_attribute_is_ordered_enumeration_ptr(x, arrptr)
        idx <- arrow_type_from_tiledb_type(tiledb::datatype(x))
        arrow::field(name = tiledb::name(x),
                     type = arrow::dictionary(index_type=idx, ordered=ord),
                     nullable = tiledb::tiledb_attribute_get_nullable(x))
    } else {
        arrow::field(name = tiledb::name(x),
                     type = arrow_type_from_tiledb_type(tiledb::datatype(x)),
                     nullable = tiledb::tiledb_attribute_get_nullable(x))
    }
}

#' Create a TileDB attribute from an Arrow field
#' @return a [`tiledb::tiledb_attr-class`]
#' @noRd
tiledb_attr_from_arrow_field <- function(field, tiledb_create_options) {
  stopifnot(
    is_arrow_field(field),
    inherits(tiledb_create_options, "TileDBCreateOptions")
  )

  # Default zstd filter to use if none is specified in platform config
  default_zstd_filter <- list(
    name = "ZSTD",
    COMPRESSION_LEVEL = tiledb_create_options$dataframe_dim_zstd_level()
  )

  field_type <- tiledb_type_from_arrow_type(field$type, is_dim=FALSE)
  tiledb::tiledb_attr(
    name = field$name,
    type = field_type,
    nullable = field$nullable,
    ncells = if (field_type == "ASCII" || field_type == "UTF8") NA_integer_ else 1L,
    filter_list = tiledb::tiledb_filter_list(
      tiledb_create_options$attr_filters(
        attr_name = field$name,
        default = list(default_zstd_filter)
      )
    )
  )
}

#' Create an Arrow schema from a TileDB array schema
#' @noRd
arrow_schema_from_tiledb_schema <- function(x) {
  stopifnot(inherits(x, "tiledb_array_schema"))
  dimfields <- lapply(tiledb::dimensions(x), arrow_field_from_tiledb_dim)
  if (!is.null(x@arrptr)) {
      attfields <- lapply(tiledb::attrs(x), arrow_field_from_tiledb_attr, x@arrptr)
  } else {
      attfields <- lapply(tiledb::attrs(x), arrow_field_from_tiledb_attr)
  }
  arrow::schema(c(dimfields, attfields))
}

#' Validate external pointer to ArrowArray which is embedded in a nanoarrow S3 type
#' @noRd
check_arrow_pointers <- function(arrlst) {
    stopifnot(inherits(arrlst, "nanoarrow_array"))
}

#' Validate compatibility of Arrow data types
#'
#' For most data types, this is a simple equality check but it also provides
#' allowances for certain comparisons:
#'
#' - string and large_string
#'
#' @param from an [`arrow::DataType`]
#' @param to an [`arrow::DataType`]
#' @return a logical indicating whether the data types are compatible
#' @noRd
check_arrow_data_types <- function(from, to) {
  stopifnot(
    "'from' and 'to' must both be Arrow DataTypes"
      = is_arrow_data_type(from) && is_arrow_data_type(to)
  )

  is_string <- function(x) {
    x$ToString() %in% c("string", "large_string")
  }

  compatible <- if (is_string(from) && is_string(to)) {
    TRUE
  } else {
    from$Equals(to)
  }

  compatible
}

#' Validate compatibility of Arrow schemas
#'
#' This is essentially a vectorized version of [`check_arrow_data_types`] that
#' checks the compatibility of each field in the schemas.
#' @param from an [`arrow::Schema`]
#' @param to an [`arrow::Schema`] with the same set of fields as `from`
#' @return `TRUE` if the schemas are compatible, otherwise an error is thrown
#' @noRd
check_arrow_schema_data_types <- function(from, to) {
  stopifnot(
    "'from' and 'to' must both be Arrow Schemas"
      = is_arrow_schema(from) && is_arrow_schema(to),
    "'from' and 'to' must have the same number of fields"
      = length(from) == length(to),
    "'from' and 'to' must have the same field names"
      = identical(sort(names(from)), sort(names(to)))
  )

  fields <- names(from)
  msgs <- character(0L)
  for (field in fields) {
    from_type <- from[[field]]$type
    to_type <- to[[field]]$type
    if (!check_arrow_data_types(from_type, to_type)) {
      msg <- sprintf(
        "  - field '%s': %s != %s\n",
        field,
        from_type$ToString(),
        to_type$ToString()
      )
      msgs <- c(msgs, msg)
    }
  }

  if (length(msgs) > 0L) {
    stop(
      "Schemas are incompatible:\n",
      string_collapse(msgs, sep = "\n"),
      call. = FALSE
    )
  }
  return(TRUE)
}

#' Extract levels from dictionaries
#' @importFrom tibble as_tibble
#' @noRd
extract_levels <- function(arrtbl, exclude_cols=c("soma_joinid")) {
    stopifnot("Argument must be an Arrow Table object" = is_arrow_table(arrtbl))
    nm <- names(arrtbl)                 # we go over the table column by column
    nm <- nm[-match(exclude_cols, nm)]  # but skip soma_joinid etc as in exclude_cols
    reslst <- vector(mode = "list", length = length(nm))
    names(reslst) <- nm		# and fill a named list, entries default to NULL
    for (n in nm) {
        inftp <- arrow::infer_type(arrtbl[[n]])
        if (inherits(inftp, "DictionaryType")) {
            # levels() extracts the enumeration levels from the factor vector we have
            reslst[[n]] <- levels(arrtbl[[n]]$as_vector())
            # set 'ordered' attribute
            attr(reslst[[n]], "ordered") <- inftp$ordered
        }
    }
    reslst
}


#' Domain and extent table creation helper for data.frame writes returning a Table with
#' a column per dimension for the given (incoming) arrow schema of a Table
#' @noRd
get_domain_and_extent_dataframe <- function(tbl_schema, ind_col_names,
                                            tdco = TileDBCreateOptions$new(PlatformConfig$new())) {
    stopifnot("First argument must be an arrow schema" = inherits(tbl_schema, "Schema"),
              "Second argument must be character" = is.character(ind_col_names),
              "Second argument cannot be empty vector" = length(ind_col_names) > 0,
              "Second argument index names must be columns in first argument" =
                  all(is.finite(match(ind_col_names, names(tbl_schema)))),
              "Third argument must be options wrapper" = inherits(tdco, "TileDBCreateOptions"))
    rl <- sapply(ind_col_names, \(ind_col_name) {
        ind_col <- tbl_schema$GetFieldByName(ind_col_name)
        ind_col_type <- ind_col$type
        ind_col_type_name <- ind_col$type$name

        # TODO: tiledbsoma-r does not accept the domain argument to SOMADataFrame::create, but should
        # https://github.com/single-cell-data/TileDB-SOMA/issues/2967
        ind_ext <- tdco$dim_tile(ind_col_name)

        # Default 2048 mods to 0 for 8-bit types and 0 is an invalid extent
        if (ind_col$type$bit_width %||% 0L == 8L) {
            ind_ext <- 64L
        }

        # We need to do this because if we don't:
        #
        # Error: [TileDB::Dimension] Error: Tile extent check failed; domain max
        # expanded to multiple of tile extent exceeds max value representable by
        # domain type. Reduce domain max by 1 tile extent to allow for
        # expansion.
        ind_max_dom <- arrow_type_unsigned_range(ind_col_type) - c(0,ind_ext)

        ind_cur_dom <- ind_max_dom
        if (ind_col_type_name %in% c("string", "large_utf8", "utf8")) ind_ext <- NA

        # https://github.com/single-cell-data/TileDB-SOMA/issues/2407
        if (.new_shape_feature_flag_is_enabled()) {
            if (ind_col_type_name %in% c("string", "utf8", "large_utf8")) {
                aa <- arrow::arrow_array(c("", "", "", "", ""), ind_col_type)
            } else {
                aa <- arrow::arrow_array(c(ind_max_dom, ind_ext, ind_cur_dom), ind_col_type)
            }
        } else {
            if (ind_col_type_name %in% c("string", "utf8", "large_utf8")) {
                aa <- arrow::arrow_array(c("", "", ""), ind_col_type)
            } else {
                aa <- arrow::arrow_array(c(ind_max_dom, ind_ext), ind_col_type)
            }
        }

        aa
    })
    names(rl) <- ind_col_names
    dom_ext_tbl <- do.call(arrow::arrow_table, rl)
    dom_ext_tbl
}

#' Domain and extent table creation helper for array writes returning a Table with
#' a column per dimension for the given (incoming) arrow schema of a Table
#' @noRd
get_domain_and_extent_array <- function(shape, is_sparse) {
    stopifnot("First argument must be vector of positive values" = is.vector(shape) && all(shape > 0))
    indvec <- seq_len(length(shape)) - 1   # sequence 0, ..., length()-1
    rl <- sapply(indvec, \(ind) {
        ind_col <- sprintf("soma_dim_%d", ind)
        ind_col_type <- arrow::int64()

        # TODO:  this function needs to take a
        # TileDBCreateOptions$new(PlatformConfig option as
        # get_domain_and_extent_dataframe does.
        # https://github.com/single-cell-data/TileDB-SOMA/issues/2966
        # For now, the core extent is not taken from the platform_config.
        ind_ext <- shape[ind+1]

        ind_cur_dom <- c(0L, shape[ind+1] - 1L)

        # We need to do this because if we don't:
        #
        # Error: [TileDB::Dimension] Error: Tile extent check failed; domain max
        # expanded to multiple of tile extent exceeds max value representable by
        # domain type. Reduce domain max by 1 tile extent to allow for
        # expansion.
        ind_max_dom <- arrow_type_unsigned_range(ind_col_type) - c(0,ind_ext)

        # TODO: support current domain for dense arrays once we have that support
        # from core.
        # https://github.com/single-cell-data/TileDB-SOMA/issues/2955
        if (.new_shape_feature_flag_is_enabled() && is_sparse) {
            aa <- arrow::arrow_array(c(ind_max_dom, ind_ext, ind_cur_dom), ind_col_type)
        } else {
            aa <- arrow::arrow_array(c(ind_cur_dom, ind_ext), ind_col_type)
        }

        aa
    })
    names(rl) <- sprintf("soma_dim_%d", indvec)
    dom_ext_tbl <- do.call(arrow::arrow_table, rl)
    dom_ext_tbl
}
