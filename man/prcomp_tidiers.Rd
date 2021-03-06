% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/prcomp_tidiers.R
\name{prcomp_tidiers}
\alias{augment.prcomp}
\alias{prcomp_tidiers}
\alias{tidy.prcomp}
\title{Tidying methods for principal components analysis via \code{\link{prcomp}}}
\usage{
\method{tidy}{prcomp}(x, matrix = "u", ...)

\method{augment}{prcomp}(x, data = NULL, newdata, ...)
}
\arguments{
\item{x}{an object of class \code{"prcomp"} resulting from a call to
\code{\link[stats]{prcomp}}}

\item{matrix}{character; Indicates which sets of eigenvectors are returned
in tidy form. "v", "rotation", or "variables" will return information about
each variable, while "u", "x", or "samples" (default) returns the loadings
for each original row. "d" or "pcs" returns information about each
principal component.}

\item{...}{Extra arguments, not used}

\item{data}{the original data on which principal components analysis
was performed. This cannot be recovered from \code{x}. If \code{newdata}
is supplied, \code{data} is ignored. If both \code{data} and \code{newdata}
are missing, only the fitted locations on the principal components are
returned.}

\item{newdata}{data frame; new observations for which locations on principal
components are sought.}
}
\value{
All tidying methods return a data.frame without rownames, whose
structure depends on the method chosen.

If \code{matrix} is "u", "samples", or "x", the \code{tidy} method
returns
\describe{
   \item{\code{row}}{The sample labels (rownames) of the data set on
  which PCA was performed}
  \item{\code{PC}}{An integer vector indicating the principal component}
  \item{\code{value}}{The value of the eigenvector (axis score) on the
  indicated principal component}
}

If \code{matrix} is "v", "variables", or "rotation", the \code{tidy} method
returns
\describe{
   \item{\code{row}}{The variable labels (colnames) of the data set on
  which PCA was performed}
  \item{\code{PC}}{An integer vector indicating the principal component}
  \item{\code{value}}{The value of the eigenvector (axis score) on the
  indicated principal component}
}

If \code{matrix} is "d" or "pcs", the \code{tidy} method returns
\describe{
  \item{\code{PC}}{An integer vector indicating the principal component}
  \item{\code{std.dev}}{Standard deviation explained by this PC}
  \item{\code{percent}}{Percentage of variation explained}
  \item{\code{cumulative}}{Cumulative percentage of variation explained}
}

The \code{augment.prcomp} method returns a data frame containing
fitted locations on the principal components for the observed data plus
either the original data or the new data if supplied via \code{data} or
\code{newdata} respectively.
}
\description{
These tidiers operate on the results of a principal components analysis
computed using \code{prcomp}. The \code{tidy} method returns a data frame
with either the eigenvectors representing each row or each column.
}
\examples{

pc <- prcomp(USArrests, scale = TRUE)

# information about rotation
head(tidy(pc))

# information about samples (states)
head(tidy(pc, "samples"))

# information about PCs
tidy(pc, "pcs")

# state map
library(dplyr)
library(ggplot2)

pc \%>\%
  tidy(matrix = "samples") \%>\%
  mutate(region = tolower(row)) \%>\%
  inner_join(map_data("state"), by = "region") \%>\%
  ggplot(aes(long, lat, group = group, fill = value)) +
  geom_polygon() +
  facet_wrap(~ PC) +
  theme_void() +
  ggtitle("Principal components of arrest data")

au <- augment(pc, data = USArrests)
head(au)

ggplot(au, aes(.fittedPC1, .fittedPC2)) +
  geom_point() +
  geom_text(aes(label = .rownames), vjust = 1, hjust = 1)

}
\seealso{
\code{\link{prcomp}}, \link{svd_tidiers}
}
\author{
Gavin L. Simpson
}
