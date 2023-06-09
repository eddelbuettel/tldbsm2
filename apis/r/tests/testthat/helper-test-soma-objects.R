# Returns the object created, populated, and closed (unless otherwise requested)
create_and_populate_soma_dataframe <- function(
  uri,
  nrows = 10L,
  seed = 1,
  index_column_names = "foo",
  mode = NULL
) {
  set.seed(seed)

  arrow_schema <- create_arrow_schema()
  tbl <- create_arrow_table(nrows = nrows)

  sdf <- SOMADataFrameCreate(uri, arrow_schema, index_column_names = index_column_names)
  sdf$write(tbl)

  if (is.null(mode)) {
    sdf$close()
  } else if (mode == "READ") {
    sdf$close()
    sdf <- SOMADataFrameOpen(uri, mode = mode)
  }
  sdf
}

# Returns the object created, populated, and closed (unless otherwise requested)
create_and_populate_obs <- function(uri, nrows = 10L, seed = 1, mode = NULL) {
  create_and_populate_soma_dataframe(
    uri = uri,
    nrows = nrows,
    seed = seed,
    index_column_names = "soma_joinid"
  )
}

# Returns the object created, populated, and closed (unless otherwise requested)
create_and_populate_var <- function(uri, nrows = 10L, seed = 1, mode = NULL) {

  tbl <- arrow::arrow_table(
    soma_joinid = bit64::seq.integer64(from = 0L, to = nrows - 1L),
    quux = as.character(seq.int(nrows) + 1000L),
    xyzzy = runif(nrows),
    schema = arrow::schema(
      arrow::field("soma_joinid", arrow::int64(), nullable = FALSE),
      arrow::field("quux", arrow::large_utf8(), nullable = FALSE),
      arrow::field("xyzzy", arrow::float64(), nullable = FALSE)
    )
  )

  sdf <- SOMADataFrameCreate(uri, tbl$schema, index_column_names = "soma_joinid")
  sdf$write(tbl)

  if (is.null(mode)) {
    sdf$close()
  } else if (mode == "READ") {
    sdf$close()
    sdf <- SOMADataFrameOpen(uri, mode = mode)
  }
  sdf
}

# Creates a SOMAExperiment with a single measurement, "RNA"
# Returns the object created, populated, and closed (unless otherwise requested)
#' @param ... Arguments passed to create_sparse_matrix_with_int_dims
create_and_populate_sparse_nd_array <- function(uri, mode = NULL, ...) {
  smat <- create_sparse_matrix_with_int_dims(...)

  ndarray <- SOMASparseNDArrayCreate(uri, arrow::int32(), shape = dim(smat))
  ndarray$write(smat)

  if (is.null(mode)) {
    ndarray$close()
  } else if (mode == "READ") {
    ndarray$close()
    ndarray <- SOMASparseNDArrayOpen(uri, mode = mode)
  }
  ndarray
}

# Creates a SOMAExperiment with a single measurement, "RNA"; populates it;
# returns it closed (unless otherwise requested).
#
# Example with X_layer_names = c("counts", "logcounts"):
#  soma-experiment-query-all1c20a1d341584 GROUP
#  |-- obs ARRAY
#  |-- ms GROUP
#  |------ RNA GROUP
#  |---------- var ARRAY
#  |---------- X GROUP
#  |-------------- counts ARRAY
#  |-------------- logcounts ARRAY
create_and_populate_experiment <- function(
  uri,
  n_obs,
  n_var,
  X_layer_names,
  config = NULL,
  mode = NULL
) {

  experiment <- SOMAExperimentCreate(uri, platform_config = config)

  experiment$obs <- create_and_populate_obs(
    uri = file.path(uri, "obs"),
    nrows = n_obs
  )

  experiment$ms <- SOMACollectionCreate(file.path(uri, "ms"))

  ms_rna <- SOMAMeasurementCreate(file.path(uri, "ms", "RNA"))
  ms_rna$var <- create_and_populate_var(
    uri = file.path(ms_rna$uri, "var"),
    nrows = n_var
  )
  ms_rna$X <- SOMACollectionCreate(file.path(ms_rna$uri, "X"))

  for (layer_name in X_layer_names) {
    snda <- create_and_populate_sparse_nd_array(
      uri = file.path(ms_rna$X$uri, layer_name),
      nrows = n_obs,
      ncols = n_var
    )
    ms_rna$X$set(snda, name = layer_name)
  }
  ms_rna$X$close()

  ms_rna$close()

  experiment$ms$set(ms_rna, name = "RNA")
  experiment$ms$close()

  if (is.null(mode)) {
    experiment$close()
  } else if (mode == "READ") {
    experiment$close()
    experiment <- SOMAExperimentOpen(uri, mode = mode)
  }
  experiment
}
