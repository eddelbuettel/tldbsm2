spdl::set_level('warn')

test_that("write_soma.data.frame mechanics", {
  skip_if_not_installed('SeuratObject', .MINIMUM_SEURAT_VERSION('c'))
  skip_if_not_installed('datasets')

  uri <- withr::local_tempdir("write-soma-data-frame")
  collection <- SOMACollectionCreate(uri)

  co2 <- get_data('CO2', package = 'datasets')
  expect_no_condition(sdf <- write_soma(co2, uri = 'co2', soma = collection))
  expect_s3_class(sdf, 'SOMADataFrame')
  expect_true(sdf$exists())
  expect_identical(sdf$uri, file.path(collection$uri, 'co2'))
  expect_identical(sdf$dimnames(), 'soma_joinid')
  expect_identical(sdf$attrnames(), c(names(co2), 'obs_id'))
  expect_true(rlang::is_na(sdf$shape()))
  schema <- sdf$schema()
  expect_s3_class(schema, 'Schema')
  expect_equal(schema$num_fields - 2L, ncol(co2))
  expect_identical(
    setdiff(schema$names, c('soma_joinid', 'obs_id')),
    names(co2)
  )

  collection$close()
})

test_that("write_soma dense matrix mechanics", {
  skip_if_not_installed('datasets')

  uri <- withr::local_tempdir("write-soma-dense-matrix")
  collection <- SOMACollectionCreate(uri)

  state77 <- get(x = 'state.x77', envir = getNamespace('datasets'))
  expect_no_condition(dmat <- write_soma(
    state77,
    uri = 'state77',
    soma = collection,
    sparse = FALSE
  ))
  expect_s3_class(dmat, 'SOMADenseNDArray')
  expect_true(dmat$exists())
  expect_identical(dmat$uri, file.path(collection$uri, 'state77'))
  expect_equal(dmat$ndim(), 2L)
  expect_identical(dmat$dimnames(), paste0('soma_dim_', c(0L, 1L)))
  expect_identical(dmat$attrnames(), 'soma_data')
  expect_equal(dmat$shape(), dim(state77))
  # Test transposition
  expect_no_condition(tmat <- write_soma(
    state77,
    uri = 'state77t',
    soma = collection,
    sparse = FALSE,
    transpose = TRUE
  ))
  expect_s3_class(tmat, 'SOMADenseNDArray')
  expect_true(tmat$exists())
  expect_identical(tmat$uri, file.path(collection$uri, 'state77t'))
  expect_equal(tmat$ndim(), 2L)
  expect_identical(tmat$dimnames(), paste0('soma_dim_', c(0L, 1L)))
  expect_identical(tmat$attrnames(), 'soma_data')
  expect_equal(tmat$shape(), rev(dim(state77)))
  # Error if given sparse matrix and ask for dense
  knex <- get_data('KNex', package = 'Matrix')$mm
  expect_error(write_soma(knex, uri = 'knex', soma = collection, sparse = FALSE))
  # Work on dgeMatrices
  expect_no_condition(emat <- write_soma(
    as(knex, 'unpackedMatrix'),
    uri = 'knexd',
    soma = collection,
    sparse = FALSE
  ))
  expect_s3_class(emat, 'SOMADenseNDArray')
  expect_true(emat$exists())
  expect_identical(emat$uri, file.path(collection$uri, 'knexd'))
  expect_equal(emat$ndim(), 2L)
  expect_identical(emat$dimnames(), paste0('soma_dim_', c(0L, 1L)))
  expect_identical(emat$attrnames(), 'soma_data')
  expect_equal(emat$shape(), dim(knex))

  collection$close()
})

test_that("write_soma sparse matrix mechanics", {
  uri <- withr::local_tempdir("write-soma-sparse-matrix")
  collection <- SOMACollectionCreate(uri)
  knex <- get_data('KNex', package = 'Matrix')$mm
  expect_no_condition(smat <- write_soma(knex, uri = 'knex', soma = collection))
  expect_s3_class(smat, 'SOMASparseNDArray')
  expect_true(smat$exists())
  expect_identical(smat$uri, file.path(collection$uri, 'knex'))
  expect_equal(smat$ndim(), 2L)
  expect_identical(smat$dimnames(), paste0('soma_dim_', c(0L, 1L)))
  expect_identical(smat$attrnames(), 'soma_data')
  expect_equal(smat$shape(), dim(knex))
  # Test transposition
  expect_no_condition(tmat <- write_soma(
    knex,
    uri = 'knext',
    soma = collection,
    transpose = TRUE
  ))
  expect_s3_class(tmat, 'SOMASparseNDArray')
  expect_true(tmat$exists())
  expect_identical(tmat$uri, file.path(collection$uri, 'knext'))
  expect_equal(tmat$ndim(), 2L)
  expect_identical(tmat$dimnames(), paste0('soma_dim_', c(0L, 1L)))
  expect_identical(tmat$attrnames(), 'soma_data')
  expect_equal(tmat$shape(), rev(dim(knex)))
  # Try a dense matrix
  skip_if_not_installed('datasets')
  state77 <- get(x = 'state.x77', envir = getNamespace('datasets'))
  expect_no_condition(cmat <- write_soma(state77, 'state77s', soma = collection))
  expect_s3_class(cmat, 'SOMASparseNDArray')
  expect_true(cmat$exists())
  expect_identical(cmat$uri, file.path(collection$uri, 'state77s'))
  expect_equal(cmat$ndim(), 2L)
  expect_identical(cmat$dimnames(), paste0('soma_dim_', c(0L, 1L)))
  expect_identical(cmat$attrnames(), 'soma_data')
  expect_equal(cmat$shape(), dim(state77))

  collection$close()
})
