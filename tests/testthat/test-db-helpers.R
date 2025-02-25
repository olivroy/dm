test_that("DB helpers work for MSSQL", {
  skip_if_src_not("mssql")
  con_mssql <- my_test_src()$con
  expect_identical(schema_mssql(con_mssql, "schema"), "schema")
  expect_identical(schema_mssql(con_mssql, NULL), "dbo")
  expect_identical(dbname_mssql(con_mssql, "database_2"), set_names("\"database_2\".", "database_2"))
  expect_identical(dbname_mssql(con_mssql, NULL), set_names("", ""))

  withr::defer({
    try(DBI::dbExecute(con_mssql, "DROP TABLE test_db_helpers"))
    try(DBI::dbExecute(con_mssql, "DROP TABLE test_db_helpers_2"))
    try(DBI::dbExecute(con_mssql, "DROP TABLE schema_db_helpers.test_db_helpers_2"))
    try(DBI::dbExecute(con_mssql, "DROP SCHEMA schema_db_helpers"))
    try(DBI::dbExecute(con_mssql, "DROP TABLE [db_helpers_db].[dbo].[test_db_helpers_3]"))
    try(DBI::dbExecute(con_mssql, "DROP TABLE [db_helpers_db].[schema_db_helpers_2].[test_db_helpers_4]"))
    # dropping schema is unnecessary
    try(DBI::dbExecute(con_mssql, "DROP DATABASE db_helpers_db"))
  })

  # create tables in 'dbo'
  DBI::dbWriteTable(
    con_mssql,
    DBI::Id(schema = "dbo", table = "test_db_helpers"),
    value = tibble(a = 1)
  )
  DBI::dbWriteTable(
    con_mssql,
    DBI::Id(schema = "dbo", table = "test_db_helpers_2"),
    value = tibble(a = 1)
  )
  # create table in a schema
  DBI::dbExecute(con_mssql, "CREATE SCHEMA schema_db_helpers")
  DBI::dbWriteTable(
    con_mssql,
    DBI::Id(schema = "schema_db_helpers", table = "test_db_helpers_2"),
    value = tibble(a = 1)
  )
  # create table on 'dbo' on another DB
  DBI::dbExecute(con_mssql, "CREATE DATABASE db_helpers_db")
  DBI::dbWriteTable(
    con_mssql,
    DBI::Id(db = "db_helpers_db", schema = "dbo", table = "test_db_helpers_3"),
    value = tibble(a = 1)
  )
  # create table in a schema on another DB
  original_dbname <- attributes(con_mssql)$info$dbname
  DBI::dbExecute(con_mssql, "USE db_helpers_db")
  DBI::dbExecute(con_mssql, "CREATE SCHEMA schema_db_helpers_2")
  DBI::dbExecute(con_mssql, paste0("USE ", original_dbname))
  DBI::dbWriteTable(
    con_mssql,
    DBI::Id(db = "db_helpers_db", schema = "schema_db_helpers_2", table = "test_db_helpers_4"),
    value = tibble(a = 1)
  )

  expect_identical(
    get_src_tbl_names(my_test_src())[["test_db_helpers"]],
    DBI::Id(schema = "dbo", table = "test_db_helpers")
  )
  expect_identical(
    get_src_tbl_names(my_test_src(), schema = "schema_db_helpers")[["test_db_helpers_2"]],
    DBI::Id(schema = "schema_db_helpers", table = "test_db_helpers_2")
  )
  expect_identical(
    get_src_tbl_names(my_test_src(), dbname = "db_helpers_db")[["test_db_helpers_3"]],
    DBI::Id(catalog = "db_helpers_db", schema = "dbo", table = "test_db_helpers_3")
  )
  expect_identical(
    get_src_tbl_names(my_test_src(), dbname = "db_helpers_db", schema = "schema_db_helpers_2")[["test_db_helpers_4"]],
    DBI::Id(catalog = "db_helpers_db", schema = "schema_db_helpers_2", table = "test_db_helpers_4")
  )
  expect_identical(
    get_src_tbl_names(my_test_src(), schema = c("dbo", "schema_db_helpers"))[["dbo.test_db_helpers_2"]],
    DBI::Id(schema = "dbo", table = "test_db_helpers_2")
  )
  expect_identical(
    get_src_tbl_names(my_test_src(), schema = c("dbo", "schema_db_helpers"))[["schema_db_helpers.test_db_helpers_2"]],
    DBI::Id(schema = "schema_db_helpers", table = "test_db_helpers_2")
  )
  expect_warning(
    out <- get_src_tbl_names(my_test_src(), schema = c("dbo", "schema_db_helpers"), names = "{.table}")["test_db_helpers_2"],
    'Local name test_db_helpers_2 will refer to <"dbo"."test_db_helpers_2">, rather than to <"schema_db_helpers"."test_db_helpers_2">',
    fixed = TRUE
  )
  expect_identical(
    out,
    list(test_db_helpers_2 = DBI::Id(
      schema = "dbo",
      table = "test_db_helpers_2"
    ))
  )
  expect_warning(
    out <- get_src_tbl_names(my_test_src(), schema = c("schema_db_helpers", "dbo"), names = "{.table}")["test_db_helpers_2"],
    'Local name test_db_helpers_2 will refer to <"schema_db_helpers"."test_db_helpers_2">, rather than to <"dbo"."test_db_helpers_2">',
    fixed = TRUE
  )
  expect_identical(
    out,
    list(test_db_helpers_2 = DBI::Id(
      schema = "schema_db_helpers",
      table = "test_db_helpers_2"
    ))
  )
})


test_that("DB helpers work for Postgres", {
  skip_if_src_not("postgres")
  con_postgres <- my_test_src()$con
  expect_identical(schema_postgres(con_postgres, "schema"), "schema")
  expect_identical(schema_postgres(con_postgres, NULL), "public")

  withr::defer({
    try(DBI::dbExecute(con_postgres, "DROP TABLE test_db_helpers"))
    try(DBI::dbExecute(con_postgres, "DROP TABLE test_db_helpers_2"))
    try(DBI::dbExecute(con_postgres, "DROP TABLE schema_db_helpers.test_db_helpers_2"))
    try(DBI::dbExecute(con_postgres, "DROP SCHEMA schema_db_helpers"))
  })

  # create tables in 'public'
  DBI::dbWriteTable(
    con_postgres,
    DBI::Id(schema = "public", table = "test_db_helpers"),
    value = tibble(a = 1)
  )
  DBI::dbWriteTable(
    con_postgres,
    DBI::Id(schema = "public", table = "test_db_helpers_2"),
    value = tibble(a = 1)
  )
  # create table in a schema
  DBI::dbExecute(con_postgres, "CREATE SCHEMA schema_db_helpers")
  DBI::dbWriteTable(
    con_postgres,
    DBI::Id(schema = "schema_db_helpers", table = "test_db_helpers_2"),
    value = tibble(a = 1)
  )

  expect_identical(
    get_src_tbl_names(my_test_src())["test_db_helpers"][[1]],
    DBI::Id(schema = "public", table = "test_db_helpers")
  )
  expect_identical(
    get_src_tbl_names(my_test_src(), schema = "schema_db_helpers")["test_db_helpers_2"][[1]],
    DBI::Id(schema = "schema_db_helpers", table = "test_db_helpers_2")
  )
  expect_identical(
    get_src_tbl_names(my_test_src(), schema = c("public", "schema_db_helpers"))["public.test_db_helpers_2"][[1]],
    DBI::Id(schema = "public", table = "test_db_helpers_2")
  )
  expect_identical(
    get_src_tbl_names(my_test_src(), schema = c("public", "schema_db_helpers"))["schema_db_helpers.test_db_helpers_2"][[1]],
    DBI::Id(schema = "schema_db_helpers", table = "test_db_helpers_2")
  )
  expect_warning(
    out <- get_src_tbl_names(my_test_src(), schema = c("public", "schema_db_helpers"), names = "{.table}")["test_db_helpers_2"],
    'Local name test_db_helpers_2 will refer to <"public"."test_db_helpers_2">, rather than to <"schema_db_helpers"."test_db_helpers_2">',
    fixed = TRUE
  )
  expect_identical(
    out,
    list(test_db_helpers_2 = DBI::Id(
      schema = "public",
      table = "test_db_helpers_2"
    ))
  )
  expect_warning(
    out <- get_src_tbl_names(my_test_src(), schema = c("schema_db_helpers", "public"), names = "{.table}")["test_db_helpers_2"],
    'Local name test_db_helpers_2 will refer to <"schema_db_helpers"."test_db_helpers_2">, rather than to <"public"."test_db_helpers_2">',
    fixed = TRUE
  )
  expect_identical(
    out,
    list(test_db_helpers_2 = DBI::Id(
      schema = "schema_db_helpers",
      table = "test_db_helpers_2"
    ))
  )
})

test_that("DB helpers work for other DBMS than MSSQL or Postgres", {
  # FIXME: Why does it fail for those databases?
  skip_if_src("mssql", "postgres")
  skip_if_not_installed("dbplyr")

  # for other DBMS than "MSSQL" or "Postgrs", get_src_tbl_names() translates to `src_tbls_impl()`
  con_db <- my_db_test_src()$con
  DBI::dbWriteTable(
    con_db,
    DBI::Id(table = "test_db_helpers"),
    value = tibble(a = 1)
  )
  withr::defer({
    try(DBI::dbExecute(con_db, "DROP TABLE test_db_helpers"))
  })

  skip_if_src("maria")

  # test for 2 warnings and if the output contains the new table
  expect_dm_warning(
    expect_dm_warning(
      expect_true("test_db_helpers" %in% names(get_src_tbl_names(my_db_test_src(), schema = "schema", dbname = "dbname"))),
      class = "arg_not"
    ),
    class = "arg_not"
  )

  skip_if_src("mssql", "postgres")

  # test for warning and if the output contains the new table
  expect_dm_warning(
    expect_true("test_db_helpers" %in% names(get_src_tbl_names(my_db_test_src(), dbname = "dbname"))),
    class = "arg_not"
  )
})

test_that("find name clashes", {
  # If all old names change to different new names...
  res <- find_name_clashes(
    c("one", "two", "three"),
    c("uno", "dos", "tres")
  )
  # ... we shouldn't get anything
  expect_length(res, 0)


  # If multiple old names change to the same new name...
  res <- find_name_clashes(
    c("one", "two", "three"),
    c("uno", "uno", "tres")
  )
  # We should get a list, with one element per "clashing" new name
  expect_named(res, "uno")
  expect_equal(res[["uno"]], c("one", "two"))
})
