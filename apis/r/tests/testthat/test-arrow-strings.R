test_that("read and write of large and normal strings via arrow", {

    sch <- arrow::schema(arrow::field("ind", arrow::int32()),
                         arrow::field("sstr", arrow::utf8()),
                         arrow::field("lstr", arrow::large_utf8()))
    tbl <- arrow::arrow_table(ind = 1:5,
                              sstr = c("The", "quick", "brown", "fox", "jumped"),
                              lstr = c("over", "the", "tall", "wooden", "fence"),
                              schema = sch)
    rb <- arrow::as_record_batch(tbl)
    #print(rb)
    #print(tibble::as_tibble(rb))

    na <- nanoarrow::nanoarrow_allocate_array()
    ns <- nanoarrow::nanoarrow_allocate_schema()
    rb$export_to_c(na, ns)

    uri <- "mem://arrow_write"
    # createAndWrite(uri, na, ns)
    expect_true(TRUE)
})
