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
#' d <- data.frame(x = 1:30, y = 31:60)
#' ssr <- state_space_reconstruction(
#'   d,
#'   response = "x",
#'   lags = list(y = c(0, 1, 2, 3))
#' )
#' state_space_distances(ssr, 20:25)
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

  # Exclude focal points that do not project to points to forecast -------------

  # Identify focal points to exclude
  exclude <- setdiff(seq_len(nrow(ssr)), index - 1L)
  # Exclude focal points
  distances[exclude, ] <- NA_real_

  # Return the distance matrix -------------------------------------------------

  return(distances)
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
#' @examples
#' d <- data.frame(x = 1:30, y = 31:60)
#' ssr <- state_space_reconstruction(
#'   d,
#'   response = "x",
#'   lags = list(y = c(0, 1, 2, 3))
#' )
#' distances <- state_space_distances(ssr, 20:25)
#' observed <- d$x
#'
#' # Should be the same unless response excluded from ssr
#'
#' state_space_forecasts(ssr, distances)
#'
#' state_space_forecasts(ssr, distances, TRUE, observed)
#'
state_space_forecasts <- function (ssr,
                                   distances,
                                   within_row = FALSE,
                                   observed = NULL) {

  # Check arguments ------------------------------------------------------------




  # Create a neighbour index matrix --------------------------------------------

  # - Row index is the focal point index
  # - Column index is the nearest neighbour ranking
  # - The number of columns is the embedding dimension + 1

  # Define the number of neighbours
  num_nbrs <- ncol(ssr) + 1
  # Define the nearness sequence
  seq_nbrs <- seq_len(num_nbrs)
  # Define the nearest neighbour index matrix
  nbr_inds <- t(apply(distances, 1, order))[, seq_nbrs, drop = FALSE]
  # Replace indexes with too few neighbours by NA
  nbr_inds[which(rowSums(!is.na(distances)) < num_nbrs), ] <- NA

  # Create a neighbour response value matrix -----------------------------------

  # - Row index is the focal point index
  # - Column index is the nearest neighbour ranking
  # - The value is the transformed response value at the correponding
  #   neighbour index

  # Apparently not used.

  # if (within_row) {
  #   # Compute transformed observed
  #   mean_observed <- mean(observed, na.rm = TRUE)
  #   sd_observed <- stats::sd(observed, na.rm = TRUE)
  #   ssr_observed <- (observed - mean_observed) / sd_observed
  #   # Neighbour response values from transformed observed vector
  #   nbr_vals <- t(apply(nbr_inds, 1, function (x, y) y[x], y = ssr_observed))
  # } else {
  #   # Neighbour response values from response column of SSR
  #   nbr_vals <- t(apply(nbr_inds, 1, function (x, y) y[x, 1], y = ssr))
  # }

  # Create neighbour distance and weights matrices -----------------------------

  nbr_dist <- t(apply(distances, 1, sort, na.last = TRUE))[, seq_nbrs, drop = F]
  nbr_wts <- t(apply(nbr_dist, 1, function (x) exp(-x / x[1])))

  # Project neighbour indexes and weights --------------------------------------

  # - Projected indexes: lag and increment each non-NA neighbour index by 1
  # - Projected weights: lag the matrix of neighbour weights

  proj_inds <- create_lags(nbr_inds, 1L) + 1L
  proj_wts <- create_lags(nbr_wts, 1L)

  # Project neighbour response values ------------------------------------------

  # - Row index is the index of the projection of the focal point
  # - Column index is the nearest neighbour ranking
  # - The value is the transformed response value at the correponding
  #   projected neighbour index

  if (within_row) {
    # Compute transformed observed
    mean_observed <- mean(observed, na.rm = TRUE)
    sd_observed <- stats::sd(observed, na.rm = TRUE)
    ssr_observed <- (observed - mean_observed) / sd_observed
    # Neighbour response values from transformed observed vector
    proj_vals <- t(apply(proj_inds, 1, function (x, y) y[x], y = ssr_observed))
  } else {
    # Neighbour response values from response column of SSR
    proj_vals <- t(apply(proj_inds, 1, function (x, y) y[x, 1], y = ssr))
  }

  # Compute SSR forecasts ------------------------------------------------------

  ssr_forecasts <- as.vector(rowSums(proj_vals * proj_wts) / rowSums(proj_wts))

  # Return SSR forecasts -------------------------------------------------------

  return(ssr_forecasts)
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
