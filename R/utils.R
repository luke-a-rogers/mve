#' Count State Space Reconstruction Points Relative To Forecast
#'
#' @param distances [matrix()] of allowed neighbour distances
#'
#' @return [integer()][vector()]
#' @export
#'
#' @examples
#' d <- data.frame(x = 1:10, y = 11:20)
#' ssr <- state_space_reconstruction(
#'   d,
#'   response = "x",
#'   lags = list(y = c(0, 1, 2, 3))
#' )
#' distances <- state_space_distances(ssr, 5:10)
#' count_ssr_points(distances)
#'
count_ssr_points <- function (distances) {
  # Count rows
  n_rows <- nrow(distances)
  # Count focal total neighbours
  n_nbrs <- as.vector(apply(distances, 1, function (x) sum(!is.na(x))))
  # Return points counts
  c(0, n_nbrs)[seq_len(n_rows)]
}

#' Create Subset Lags
#'
#' @param lags [list()] whose elements are one named vector of integer lags for
#'   each explanatory variable
#'
#' @return [list()] whose elements are one lags [list()] for each subset state
#'   space reconstruction
#'
#' @export
#'
#' @examples
#' create_subset_lags(list(a = c(0, 1, 2), b = c(0, 1)))
#'
create_subset_lags <- function (lags) {
  # Check arguments

  # Create subset lags
  len <- length(unlist(lags))
  num <- 2^len - 1
  out <- list()
  for (i in seq_len(num)) {
    inds <- as.logical(binary(i, digits = len))
    subs <- unlist(utils::as.relistable(lags))
    subs[!rev(inds)] <- NA_real_
    subs <- utils::relist(subs)
    subs <- lapply(subs, function(x) x[!is.na(x)])
    for (j in rev(seq_along(subs))) {
      if (length(subs[[j]]) == 0) {
        subs[[j]] <- NULL
      }
    }
    out[[i]] <- subs
  }
  # Return a list of subset lags lists
  return(out)
}


#' State Space Reconstruction (SSR)
#'
#' @description Rows are centred and scaled points in the state-space
#'   reconstruction.
#'
#' @param data [matrix()] with variables as named columns
#' @param response [character()] column name of the response variable
#' @param lags [list()] of a named vector of lags for each explanatory variable
#'
#' @author Luke A. Rogers
#'
#' @return [state_space_reconstruction()] [matrix()] with unlagged response
#'   and lagged explanatory variables centred on their means and scaled by
#'   their respective standard deviations.
#'
#' @export
#'
#' @examples
#' d <- data.frame(x = 1:10, y = 11:20)
#' state_space_reconstruction(d, response = "x", lags = list(y = c(0, 1, 2, 3)))
#'
state_space_reconstruction <- function (data, response, lags) {

  # Check arguments ------------------------------------------------------------


  # Define values --------------------------------------------------------------

  col_names <- c(response, names(lags))
  lag_sizes <- unlist(lags, use.names = FALSE)
  lag_names <- rep(names(lags), lengths(lags))

  # Create Z -------------------------------------------------------------------

  Z <- as.matrix(data[, col_names, drop = FALSE])
  Z_means <- apply(Z, 2, mean, na.rm = TRUE)
  Z_sds <- apply(Z, 2, stats::sd, na.rm = TRUE)

  # Create Y -------------------------------------------------------------------

  Y <- t((t(Z) - Z_means) / Z_sds)

  # Create X -------------------------------------------------------------------

  X <- cbind(
    Y[, response, drop = FALSE],
    create_lags(
      Y[, lag_names, drop = FALSE],
      lag_sizes
    )
  )
  colnames(X) <- c(response, paste0(lag_names, "_", lag_sizes))

  # Return ssr -----------------------------------------------------------------

  return(structure(X, class = "state_space_reconstruction"))
}

#' State Space Distance Matrix
#'
#' @details Row index corresponds to focal point time. Column index
#'   corresponds to neighbour point time. The value represents the distance
#'   from the focal point to the neighbour point. Disallowed focal point
#'   and neighbour combinations have value NA.
#'
#' @param ssr [matrix()] a state space reconstruction in which the rows
#'   are points in the state space
#' @param index [integer()][vector()] time indexes of the values to forecast
#'
#' @author Luke A. Rogers
#'
#' @return [matrix()] of allowed neighbour distances
#' @export
#'
#' @examples
#' d <- data.frame(x = 1:10, y = 11:20)
#' ssr <- state_space_reconstruction(
#'   d,
#'   response = "x",
#'   lags = list(y = c(0, 1, 2, 3))
#' )
#' state_space_distances(ssr, 5:10)
#'
#'
state_space_distances <- function (ssr, index) {

  # Check arguments ------------------------------------------------------------


  # Compute distances ----------------------------------------------------------

  # Avoid partial component distances
  ssr_na <- ssr
  ssr_na[is.na(rowSums(ssr)), ] <- NA_real_

  # Compute the distance matrix
  distances <- as.matrix(stats::dist(ssr_na))

  # Exclude focal point and future neighbours ----------------------------------

  distances[upper.tri(distances, diag = TRUE)] <- NA_real_

  # Exclude points with a missing value ----------------------------------------
  # - Neighbours of focal points that themselves contain missing values
  # - Neighbours that contain missing values
  # - Neighbours that project to points that contain missing values
  na_rows <- which(is.na(rowSums(ssr)))
  na_proj <- subset(na_rows - 1L, na_rows - 1L > 0)
  distances[na_rows, ] <- NA_real_
  distances[, na_rows] <- NA_real_
  distances[, na_proj] <- NA_real_

  # Exclude focal points in the training set -----------------------------------

  distances[seq_len(min(index) - 2L), ] <- NA_real_

  # Return the distance matrix -------------------------------------------------

  return(distances)
}

#' Lag Superset Columns
#'
#' @param data [matrix()] or [data.frame()] with named [numeric()] columns
#' @param lags [list()] of a named vector of lags for each explanatory
#'   variable.
#' @param superset [list()] superset of lags corresponding to the parent state
#'   space reconstruction
#'
#' @return [tibble::tibble()]
#' @export
#'
superset_columns <- function (data,
                              lags,
                              superset = NULL) {
  # Define superset columns
  if (is.null(superset)) superset <- lags
  lag_sizes <- unlist(lags, use.names = FALSE)
  lag_names <- rep(names(lags), lengths(lags))
  lag_cols <- paste0(lag_names, "_", lag_sizes)
  sup_sizes <- unlist(superset, use.names = FALSE)
  sup_names <- rep(names(superset), lengths(superset))
  lag_mat <- matrix(0, nrow = nrow(data), ncol = length(sup_sizes))
  colnames(lag_mat) <- paste0(sup_names, "_", sup_sizes)
  lag_mat[, lag_cols] <- 1
  # Return
  return(tibble::as_tibble(lag_mat))
}

#' Untransform State Space Forecast Values
#'
#' @param x [numeric()][vector()] observed values
#' @param y [numeric()][vector()] state space forecast values
#'
#' @return [numeric()][vector()]
#' @export
#'
untransform_forecasts <- function (x, y) {
  # Check arguments
  checkmate::assert_numeric(x, finite = TRUE, min.len = 1)
  checkmate::assert_numeric(y, finite = TRUE, min.len = 1)
  checkmate::assert_vector(x, strict = TRUE)
  checkmate::assert_vector(y, strict = TRUE)
  checkmate::assert_true(length(x) == length(y))
  # Return untransformed forecast
  return(mean(x, na.rm = TRUE) + y * stats::sd(x, na.rm = TRUE))
}


# Current above here -----------------------------------------------------------



#' Represent An Integer As A Binary Vector
#'
#' @param x [integer()] >= 0
#' @param digits [integer()] length of the output vector
#'
#' @return [integer()] [vector()] binary representation of x
#' @export
#'
#' @examples
#' binary(10, digits = 8)
#'
#' for (i in 0:32) print(binary(i, digits = 6))
#'
binary <- function (x, digits = NULL) {
  # Check arguments

  # Compute binary vector
  v <- c()
  while (x > 0) {
    r <- x %% 2
    x <- x %/% 2
    v <- c(r, v)
  }
  if (!is.null(digits)) {
    if (digits < length(v)) {
      stop("condition digits >= length(v) must hold")
    } else {
      v <- c(rep(0, digits - length(v)), v)
    }
  }
  return(v)
}

#' Create Lags Of A Vector Or Matrix
#'
#' @param x [vector()] or column [matrix()] to lag
#' @param n [integer()] lag sizes
#'
#' @return [vector()] or column [matrix()] of lagged values
#'
#' @author Luke A. Rogers
#'
#' @export
#'
#' @examples
#' create_lags(1:10, 3)
#' create_lags(matrix(rep(1:10, 2), nrow = 10), 3)
#' create_lags(matrix(rep(1:10, 2), nrow = 10), c(3, 5))
#'
#' create_lags(matrix(rep(1:10, 2), nrow = 10), c(0, 1))
#' create_lags(matrix(rep(1:10, 2), nrow = 10), c(0, 0))
#' create_lags(matrix(rep(1:10, 2), nrow = 10), c(0, -1))
#'
create_lags <- function (x, n = 1L) {

  # 0.0 Check arguments --------------------------------------------------------

  stopifnot(
    is.matrix(x) || is.numeric(x),
    is.numeric(n))

  # 1.0 Define m and n ---------------------------------------------------------

  # Coerce to matrix
  m <- as.matrix(x)

  # Define lags
  if (length(n) == 1) {
    n <- rep(n, ncol(m))
  }

  # 2.0 Create lags of m -------------------------------------------------------

  # Create positive or negative lags and buffer by NAs
  for (i in seq_along(n)) {
    if (n[i] >= 0) {
      m[, i] <- c(rep(NA_real_, floor(n[i])), m[, i])[seq_along(m[, i])]
    } else {
      m[, i] <- c(m[, i], rep(NA_real_, floor(-n[i])))[seq_along(m[, i]) - n[i]]
    }
  }

  # 3.0 Coerce m to vector or matrix -------------------------------------------

  if (is.vector(x)) {
    m <- as.vector(m)
  } else if (is.matrix(x)) {
    m <- as.matrix(m)
  }

  # 4.0 Return m ---------------------------------------------------------------

  return(m)
}


#' State Space Forecasts
#'
#' @param ssr [matrix()] a state space reconstruction in which the rows
#'   are points in the state space
#' @param distances [matrix()] of allowed neighbour distances
#' @param within_row [logical()] forecast response using explanatory values
#'   from within the same row in \code{data}. This is appropriate if the
#'   response is indexed by a generating event but occurs at a later time. For
#'   example sockeye recruitment is indexed by brood year but typically occurs
#'   over the subsequent 3-5 years, so \code{within_row = TRUE} is appropriate.
#'   Note that this excludes the response from the state space reconstruction,
#'   and consequently identifies nearest neighbours by explanatory variables
#'   and their lags, but not by the resulting recruitment.
#' @param observed [numeric()][vector()]
#'
#' @return [numeric()] [vector()] of forecast values
#' @export
#'
state_space_forecasts <- function (ssr,
                                   distances,
                                   within_row = FALSE,
                                   observed = NULL) {

}


# #' Empirical Dynamic Modeling Forecasts
# #'
# #' @param X [matrix()] a state space reconstruction in which the rows
# #'   are points in the state space
# #' @param distance [matrix()] of allowed neighbour distances
# #' @param beyond [logical()]
# #'
# #' @author Luke A. Rogers
# #'
# #' @return [numeric()] [vector()] of forecast values
# #' @export
# #'
# state_space_forecasts <- function (X, distance, beyond = FALSE) {
#
#   # Check arguments ------------------------------------------------------------
#
#
#   # Create neighbour index matrix ----------------------------------------------
#
#   num_nbrs <- ncol(X) + 1
#   seq_nbrs <- seq_len(num_nbrs)
#   nbr_inds <- t(apply(distance, 1, order))[, seq_nbrs, drop = FALSE]
#   nbr_inds[which(rowSums(!is.na(distance)) < num_nbrs), ] <- NA
#   nbr_inds <- rbind(nbr_inds, array(NA, dim = c(1, num_nbrs)))
#
#   # Create neighbour matrices --------------------------------------------------
#
#   nbr_vals <- t(apply(nbr_inds, 1, function (x, y) y[x, 1], y = X))
#   nbr_dist <- t(apply(distance, 1, sort, na.last = TRUE))[, seq_nbrs]
#   nbr_wts <- t(apply(nbr_dist, 1, function (x) exp(-x / x[1])))
#   nbr_wts <- rbind(nbr_wts, array(NA, dim = c(1, num_nbrs)))
#
#   # Project neighbour matrices -------------------------------------------------
#
#   proj_inds <- create_lags(nbr_inds, 1L) + 1L
#   proj_vals <- t(apply(proj_inds, 1, function (x, y) y[x, 1], y = X))
#   proj_wts <- create_lags(nbr_wts, 1L)
#
#   # Compute X_forecast ---------------------------------------------------------
#
#   X_forecast <- as.vector(rowSums(proj_vals * proj_wts) / rowSums(proj_wts))
#
#   # Forecast beyond ssr? -------------------------------------------------------
#
#   if (!beyond) {
#     X_forecast <- X_forecast[seq_len(nrow(X))]
#   }
#
#   # Return X_forecast ----------------------------------------------------------
#
#   return(X_forecast)
# }


#' Weight Single-View Embedding Outputs By Past Performance
#'
#' @param outputs [list()]
#' @param n_best [integer()]
#'
#' @return [list()]
#' @export
#'
weight_sve_outputs_by_past <- function (outputs, n_best) {

}

#
# #' Weight Single-View Embeddings
# #'
# #' @param forecasts [list()]
# #' @param metric [character()]
# #' @param weight [character()]
# #' @param n_weight [numeric()]
# #'
# # @importFrom rlang .data
# # @importFrom rlang :=
# #'
# #' @return [list()]
# #' @export
# #'
# weight_by_past <- function (forecasts,
#                             metric,
#                             weight,
#                             n_weight) {
#   # Define ranks
#   ranks <- forecasts %>%
#     dplyr::bind_rows(.id = "ssr") %>%
#     dplyr::mutate(ssr = as.numeric(.data$ssr)) %>%
#     dplyr::arrange(.data$time, .data[[metric]]) %>%
#     dplyr::group_by(.data$time) %>%
#     dplyr::mutate(rank = dplyr::row_number()) %>%
#     dplyr::ungroup() %>%
#     dplyr::arrange(.data$ssr, .data$time) %>%
#     dplyr::group_by(.data$ssr) %>%
#     dplyr::mutate(lag_rank = dplyr::lag(.data$rank, n = 1L)) %>%
#     dplyr::ungroup()
#   # Define forecast
#   forecast <- ranks %>%
#     dplyr::filter(.data$lag_rank <= n_weight) %>%
#     dplyr::arrange(.data$time, .data$lag_rank) %>%
#     dplyr::group_by(.data$time) %>%
#     dplyr::mutate(forecast = mean(.data$forecast, na.rm = TRUE)) %>%
#     dplyr::ungroup() %>%
#     dplyr::distinct(.data$time, .keep_all = TRUE) %>%
#     dplyr::select(.data$set, .data$time, .data$observed,.data$forecast)
#   # Define summary
#   summary <- ranks %>%
#     dplyr::filter(.data$lag_rank <= n_weight) %>%
#     dplyr::arrange(.data$time, .data$lag_rank) %>%
#     dplyr::filter(.data$set == 1)
#   # Define hindsight
#   hindsight_ssr <- ranks %>%
#     dplyr::filter(.data$time == max(.data$time, na.omit = TRUE)) %>%
#     dplyr::filter(.data$rank == 1) %>%
#     dplyr::pull(.data$ssr)
#   hindsight <- ranks %>%
#     dplyr::filter(.data$ssr == hindsight_ssr) %>%
#     dplyr::filter(.data$set == 1)
#   # Define observed-forecast matrix
#   m <- matrix(c(forecast$observed, forecast$forecast), ncol = 2L)
#   # Define results
#   results <- forecast %>%
#     dplyr::mutate(
#       mre = runner::runner(m, f = eedm::matric, fun = eedm::mre),
#       !!metric := runner::runner(m, f = eedm::matric, fun = get(metric))
#     ) %>%
#     dplyr::filter(.data$set == 1) %>%
#     dplyr::select(.data$time:.data[[metric]])
#   # Return
#   return(
#     list(
#       ranks = ranks,
#       summary = summary,
#       hindsight = hindsight,
#       results = results
#     )
#   )
# }
#