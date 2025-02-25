#' Add a unique key
#'
#' @description
#' `dm_add_uk()` marks the specified columns as a unique key of the specified table.
#' If `check == TRUE`, then it will first check if
#' the given combination of columns is a unique key of the table.
#'
#' @inheritParams dm_add_pk
#'
#' @details The difference between a primary key (PK) and a unique key (UK) consists in the following:
#' - When a local `dm` is copied to a database (DB) with `copy_dm_to()`, a PK will be set on the DB by default, whereas a UK is being ignored.
#' - A PK can be set as an `autoincrement` key (also implemented on certain DBMS when the `dm` is transferred to the DB)
#' - There can be only one PK for each table, whereas there can be unlimited UKs
#' - A UK will be used, if the same table has an autoincrement PK in addition, to ensure that during delta load processes
#'   on the DB (cf. [dm_rows_append()]) the foreign keys are updated accordingly.
#'   If no UK is available, the insertion is done row-wise, which also ensures a correct matching, but can be much slower.
#' - A UK can generally enhance the data model by adding additional information
#' - There can also be implicit UKs, when the columns addressed by a foreign key are neither a PK nor a UK.
#'   These implicit UKs are also listed by [`dm_get_all_uks()`]
#'
#' @family primary key functions
#'
#' @return An updated `dm` with an additional unqiue key.
#'
#' @examplesIf rlang::is_installed("nycflights13") && rlang::is_installed("DiagrammeR")
#'
#' nycflights_dm <- dm(
#'   planes = nycflights13::planes,
#'   airports = nycflights13::airports,
#'   weather = nycflights13::weather
#' )
#'
#' # Create unique keys:
#' nycflights_dm %>%
#'   dm_add_uk(planes, tailnum) %>%
#'   dm_add_uk(airports, faa, check = TRUE) %>%
#'   dm_add_uk(weather, c(origin, time_hour)) %>%
#'   dm_get_all_uks()
#'
#' # Keys can be checked during creation:
#' try(
#'   nycflights_dm %>%
#'     dm_add_uk(planes, manufacturer, check = TRUE)
#' )
#' @export
dm_add_uk <- function(dm, table, columns, ..., check = FALSE) {
  check_dots_empty()

  check_not_zoomed(dm)

  table_name <- dm_tbl_name(dm, {{ table }})
  table <- dm_get_tables_impl(dm)[[table_name]]

  check_required(columns)
  col_expr <- enexpr(columns)
  col_name <- names(eval_select_indices(col_expr, colnames(table)))

  if (check) {
    table_from_dm <- dm_get_filtered_table(dm, table_name)
    eval_tidy(expr(check_key(!!sym(table_name), !!col_expr)), list2(!!table_name := table_from_dm))
  }

  dm_add_uk_impl(dm, table_name, col_name)
}

# both "table" and "column" must be characters
# in {datamodelr}, a primary key may consist of more than one columns
# a key will be added, regardless of whether it is a unique key or not; not to be exported
dm_add_uk_impl <- function(dm, table, column) {
  def <- dm_get_def(dm)
  i <- which(def$table == table)

  if (!is_empty(def$pks[[i]]$column) && identical(def$pks[[i]]$column[[1]], column)) {
    abort_no_uk_if_pk(table, column)
  }
  if (any(map_lgl(def$uks[[i]]$column, identical, column))) {
    abort_no_uk_if_pk(table, column, type = "UK")
  }

  def$uks[[i]] <- vctrs::vec_rbind(
    def$uks[[i]],
    new_uk(list(column))
  )

  dm_from_def(def)
}

#' Get all unique keys of a [`dm`] object
#'
#' @description
#' `dm_get_all_uks()` checks the `dm` object for unique keys
#' (primary keys, explicit and implicit unique keys) and returns the tables and
#' the respective unique key columns.
#'
#' @family primary key functions
#' @param table One or more table names, unquoted,
#'   to return unique key information for.
#'   The default `NULL` returns information for all tables.
#'
#' @details There are 3 kinds of unique keys:
#'    - `PK`: Primary key, set by [`dm_add_pk()`]
#'    - `explicit UK`: Unique key, set by [`dm_add_uk()`]
#'    - `implicit UK`: Unique key, not explicitly set, but referenced by a foreign key.
#'
#' @inheritParams dm_add_uk
#'
#' @return A tibble with the following columns:
#'   \describe{
#'     \item{`table`}{table name,}
#'     \item{`uk_col`}{column name(s) of primary key, as list of character vectors,}
#'     \item{`kind`}{kind of unique key, see details.}
#'   }
#'
#' @export
#' @examplesIf rlang::is_installed("nycflights13")
#' dm_nycflights13() %>%
#'   dm_get_all_uks()
dm_get_all_uks <- function(dm, table = NULL, ...) {
  check_dots_empty()
  check_not_zoomed(dm)
  table_expr <- enexpr(table) %||% src_tbls_impl(dm, quiet = TRUE)
  table_names <- eval_select_table(table_expr, set_names(src_tbls_impl(dm, quiet = TRUE)))
  dm_get_all_uks_impl(dm, table_names)
}

dm_get_all_uks_impl <- function(dm, table = NULL) {
  def <- dm %>%
    dm_get_def()

  if (!is.null(table)) {
    idx <- match(table, def$table)
    def <- def[match(table, def$table), ]
  }

  all_pks <- dm_get_all_pks_def_impl(def, table) %>%
    select(-autoincrement) %>%
    rename(uk_col = pk_col)

  all_explicit_uks <- dm_get_all_uks_def_impl(def)

  all_explicit <- bind_rows(
    mutate(all_pks, kind = "PK"),
    mutate(all_explicit_uks, kind = "explicit UK")
  )

  all_implicit <- dm_get_all_implicit_uks_def_impl(def, table, all_explicit) %>%
    mutate(kind = "implicit UK")

  bind_rows(
    all_explicit,
    all_implicit
  )
}

dm_get_all_uks_def_impl <- function(def, table = NULL) {
  # Optimized for speed

  def_sub <- def[c("table", "uks")]
  out <-
    def_sub %>%
    unnest_df("uks", tibble(column = list())) %>%
    set_names(c("table", "uk_col")) %>%
    mutate(kind = "explicit UK")

  out$uk_col <- new_keys(out$uk_col)
  out
}

dm_get_all_implicit_uks_def_impl <- function(def, table = NULL, all_explicit) {
  dm_get_all_fks_def_impl(def) %>%
    select(table = parent_table, uk_col = parent_key_cols) %>%
    distinct() %>%
    # rm those that are PKs or explicit UKs
    anti_join(all_explicit, c("table", "uk_col"))
}


#' Remove a unique key
#'
#' @description
#' `dm_rm_uk()` removes one or more unique keys from a table and leaves the [`dm`] object otherwise unaltered.
#' An error is thrown if no unique key matches the selection criteria.
#' If the selection criteria are ambiguous, a message with unambiguous replacement code is shown.
#' Foreign keys are never removed.
#'
#' @inheritParams dm_rm_pk
#'
#' @family primary key functions
#'
#' @return An updated `dm` without the indicated unique key(s).
#'
#' @export
dm_rm_uk <- function(dm, table = NULL, columns = NULL, ...) {
  dm_rm_uk_(dm, {{ table }}, {{ columns }}, ...)
}

dm_rm_uk_ <- function(dm, table, columns, ...) {
  check_dots_empty()
  check_not_zoomed(dm)

  table_name <- dm_tbl_name_null(dm, {{ table }})
  columns <- enexpr(columns)

  dm_rm_uk_impl(dm, table_name, columns)
}

dm_rm_uk_impl <- function(dm, table_name, columns) {
  def <- dm_get_def(dm)

  if (is.null(table_name)) {
    i <- which(map_int(def$uks, vec_size) > 0)
  } else {
    i <- which(def$table == table_name)
    if (nrow(def$uks[[i]]) == 0) {
      i <- integer()
    }
  }
  if (length(i) == 0 && dm_is_strict_keys(dm)) {
    abort_uk_not_defined()
  }

  ii <- if (!quo_is_null(columns)) {
    ii_col <- map2(def$data[i], def$uks[i], ~ tryCatch(
      {
        vars <- eval_select_indices(columns, colnames(.x))
        map_lgl(.y$column, ~ identical(names(vars), .x))
      },
      error = function(e) {
        FALSE
      }
    ))

    # if `columns` is not NULL, it refers to only one UK, therefore we can choose
    # the first element of the list created by `map2()`

    # FIXME: error message should be more informative: which UKs are available
    # for the given table? What was the user input for `columns`?
    if (!any(ii_col[[1]])) {
      abort_uk_not_defined()
    }
    ii_col[[1]]
  } else {
    # if no `column` is provided by user, use all columns for matching
    TRUE
  }

  # Talk about it
  if (is.null(table_name) || quo_is_null(columns)) {
    n_uk_per_table <- map_int(i, ~ nrow(def$uks[[.x]]))
    message("Removing unique keys: %>%")
    message("  ", glue_collapse(
      glue(
        "dm_rm_uk({tick_if_needed(rep(def$table[i], n_uk_per_table))}, {list_c(map(i, ~ deparse_keys(def$uks[[.x]]$column)))})"
      ), " %>%\n  "
    ))
  }
  # Execute
  # in case `length(i) > 1`: all tables have all their UKs removed, respectively
  def$uks[i] <- if (length(i) > 1) {
    list_of(new_uk())
  } else {
    list_of(filter(def$uks[[i]], !ii))
  }

  dm_from_def(def)
}

# Error -------------------------------------------------------------------

abort_uk_not_defined <- function() {
  abort(error_txt_uk_not_defined(), class = dm_error_full("uk_not_defined"))
}

error_txt_uk_not_defined <- function() {
  glue("No unique keys to remove.")
}

abort_no_uk_if_pk <- function(table, column, type = "PK") {
  error_txt <- glue("A {type} ({commas(tick(column))}) for table `{table}` already exists, not adding UK.")
  abort(error_txt, class = dm_error_full("no_uk_if_pk"))
}
