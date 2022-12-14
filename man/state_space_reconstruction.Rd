% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{state_space_reconstruction}
\alias{state_space_reconstruction}
\title{State Space Reconstruction (SSR)}
\usage{
state_space_reconstruction(data, response, lags)
}
\arguments{
\item{data}{\code{\link[=matrix]{matrix()}} with variables as named columns}

\item{response}{\code{\link[=character]{character()}} column name of the response variable}

\item{lags}{\code{\link[=list]{list()}} of a named vector of lags for each explanatory variable}
}
\value{
\code{\link[=state_space_reconstruction]{state_space_reconstruction()}} \code{\link[=matrix]{matrix()}} with unlagged response
and lagged explanatory variables centred on their means and scaled by
their respective standard deviations.
}
\description{
Rows are centred and scaled points in the state-space
reconstruction.
}
\examples{
d <- data.frame(x = 1:10, y = 11:20)
state_space_reconstruction(d, response = "x", lags = list(y = c(0, 1, 2, 3)))

}
\author{
Luke A. Rogers
}
