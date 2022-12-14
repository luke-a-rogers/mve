% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{state_space_distances}
\alias{state_space_distances}
\title{State Space Distance Matrix}
\usage{
state_space_distances(ssr, index)
}
\arguments{
\item{ssr}{\code{\link[=matrix]{matrix()}} a state space reconstruction in which the rows
are points in the state space}

\item{index}{\link[=vector]{integer()} time indexes of the values to forecast}
}
\value{
\code{\link[=matrix]{matrix()}} of allowed neighbour distances
}
\description{
State Space Distance Matrix
}
\details{
Row index corresponds to focal point time. Column index
corresponds to neighbour point time. The value represents the distance
from the focal point to the neighbour point. Disallowed focal point
and neighbour combinations have value NA.
}
\examples{
d <- data.frame(x = 1:30, y = 31:60)
ssr <- state_space_reconstruction(
  d,
  response = "x",
  lags = list(y = c(0, 1, 2, 3))
)
state_space_distances(ssr, 20:25)


}
\author{
Luke A. Rogers
}
