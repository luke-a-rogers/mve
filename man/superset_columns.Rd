% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{superset_columns}
\alias{superset_columns}
\title{Lag Superset Columns}
\usage{
superset_columns(data, lags, superset = NULL)
}
\arguments{
\item{data}{\code{\link[=matrix]{matrix()}} or \code{\link[=data.frame]{data.frame()}} with named \code{\link[=numeric]{numeric()}} columns}

\item{lags}{\code{\link[=list]{list()}} of a named vector of lags for each explanatory
variable.}

\item{superset}{\code{\link[=list]{list()}} superset of lags corresponding to the parent state
space reconstruction}
}
\value{
\code{\link[tibble:tibble]{tibble::tibble()}}
}
\description{
Lag Superset Columns
}
