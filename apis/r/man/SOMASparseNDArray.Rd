% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/SOMASparseNDArray.R
\name{SOMASparseNDArray}
\alias{SOMASparseNDArray}
\title{SOMASparseNDArray}
\description{
\code{SOMASparseNDArray} is a sparse, N-dimensional array with offset
(zero-based) integer indexing on each dimension. The \code{SOMASparseNDArray} has
a user-defined schema, which includes:
\itemize{
\item type - a \code{primitive} type, expressed as an Arrow type (e.g., \code{int64}, \code{float32}, etc)
\item shape - the shape of the array, i.e., number and length of each dimension
}

All dimensions must have a positive, non-zero length.

\strong{Note} - on TileDB this is an sparse array with \code{N} int64 dimensions of
domain [0, maxInt64), and a single attribute.
\subsection{Duplicate writes}{

As duplicate index values are not allowed, index values already present in
the object are overwritten and new index values are added. (lifecycle: maturing)
}
}
\section{Super classes}{
\code{\link[tiledbsoma:TileDBObject]{tiledbsoma::TileDBObject}} -> \code{\link[tiledbsoma:TileDBArray]{tiledbsoma::TileDBArray}} -> \code{\link[tiledbsoma:SOMAArrayBase]{tiledbsoma::SOMAArrayBase}} -> \code{\link[tiledbsoma:SOMANDArrayBase]{tiledbsoma::SOMANDArrayBase}} -> \code{SOMASparseNDArray}
}
\section{Methods}{
\subsection{Public methods}{
\itemize{
\item \href{#method-SOMASparseNDArray-read}{\code{SOMASparseNDArray$read()}}
\item \href{#method-SOMASparseNDArray-write}{\code{SOMASparseNDArray$write()}}
\item \href{#method-SOMASparseNDArray-nnz}{\code{SOMASparseNDArray$nnz()}}
\item \href{#method-SOMASparseNDArray-resize}{\code{SOMASparseNDArray$resize()}}
\item \href{#method-SOMASparseNDArray-tiledbsoma_upgrade_shape}{\code{SOMASparseNDArray$tiledbsoma_upgrade_shape()}}
\item \href{#method-SOMASparseNDArray-clone}{\code{SOMASparseNDArray$clone()}}
}
}
\if{html}{\out{
<details><summary>Inherited methods</summary>
<ul>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBObject" data-id="class"><a href='../../tiledbsoma/html/TileDBObject.html#method-TileDBObject-class'><code>tiledbsoma::TileDBObject$class()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBObject" data-id="exists"><a href='../../tiledbsoma/html/TileDBObject.html#method-TileDBObject-exists'><code>tiledbsoma::TileDBObject$exists()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBObject" data-id="initialize"><a href='../../tiledbsoma/html/TileDBObject.html#method-TileDBObject-initialize'><code>tiledbsoma::TileDBObject$initialize()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBObject" data-id="is_open"><a href='../../tiledbsoma/html/TileDBObject.html#method-TileDBObject-is_open'><code>tiledbsoma::TileDBObject$is_open()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBObject" data-id="mode"><a href='../../tiledbsoma/html/TileDBObject.html#method-TileDBObject-mode'><code>tiledbsoma::TileDBObject$mode()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBObject" data-id="reopen"><a href='../../tiledbsoma/html/TileDBObject.html#method-TileDBObject-reopen'><code>tiledbsoma::TileDBObject$reopen()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="attributes"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-attributes'><code>tiledbsoma::TileDBArray$attributes()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="attrnames"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-attrnames'><code>tiledbsoma::TileDBArray$attrnames()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="close"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-close'><code>tiledbsoma::TileDBArray$close()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="colnames"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-colnames'><code>tiledbsoma::TileDBArray$colnames()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="dimensions"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-dimensions'><code>tiledbsoma::TileDBArray$dimensions()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="dimnames"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-dimnames'><code>tiledbsoma::TileDBArray$dimnames()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="fragment_count"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-fragment_count'><code>tiledbsoma::TileDBArray$fragment_count()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="get_metadata"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-get_metadata'><code>tiledbsoma::TileDBArray$get_metadata()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="index_column_names"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-index_column_names'><code>tiledbsoma::TileDBArray$index_column_names()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="maxshape"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-maxshape'><code>tiledbsoma::TileDBArray$maxshape()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="ndim"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-ndim'><code>tiledbsoma::TileDBArray$ndim()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="non_empty_domain"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-non_empty_domain'><code>tiledbsoma::TileDBArray$non_empty_domain()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="open"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-open'><code>tiledbsoma::TileDBArray$open()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="print"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-print'><code>tiledbsoma::TileDBArray$print()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="schema"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-schema'><code>tiledbsoma::TileDBArray$schema()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="set_metadata"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-set_metadata'><code>tiledbsoma::TileDBArray$set_metadata()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="shape"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-shape'><code>tiledbsoma::TileDBArray$shape()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="tiledb_array"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-tiledb_array'><code>tiledbsoma::TileDBArray$tiledb_array()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="tiledb_schema"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-tiledb_schema'><code>tiledbsoma::TileDBArray$tiledb_schema()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="TileDBArray" data-id="used_shape"><a href='../../tiledbsoma/html/TileDBArray.html#method-TileDBArray-used_shape'><code>tiledbsoma::TileDBArray$used_shape()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="SOMANDArrayBase" data-id="create"><a href='../../tiledbsoma/html/SOMANDArrayBase.html#method-SOMANDArrayBase-create'><code>tiledbsoma::SOMANDArrayBase$create()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="SOMANDArrayBase" data-id="set_data_type"><a href='../../tiledbsoma/html/SOMANDArrayBase.html#method-SOMANDArrayBase-set_data_type'><code>tiledbsoma::SOMANDArrayBase$set_data_type()</code></a></span></li>
<li><span class="pkg-link" data-pkg="tiledbsoma" data-topic="SOMANDArrayBase" data-id="tiledbsoma_has_upgraded_shape"><a href='../../tiledbsoma/html/SOMANDArrayBase.html#method-SOMANDArrayBase-tiledbsoma_has_upgraded_shape'><code>tiledbsoma::SOMANDArrayBase$tiledbsoma_has_upgraded_shape()</code></a></span></li>
</ul>
</details>
}}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-SOMASparseNDArray-read"></a>}}
\if{latex}{\out{\hypertarget{method-SOMASparseNDArray-read}{}}}
\subsection{Method \code{read()}}{
Reads a user-defined slice of the \code{SOMASparseNDArray}
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{SOMASparseNDArray$read(
  coords = NULL,
  result_order = "auto",
  log_level = "auto"
)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{coords}}{Optional \code{list} of integer vectors, one for each dimension, with a
length equal to the number of values to read. If \code{NULL}, all values are
read. List elements can be named when specifying a subset of dimensions.}

\item{\code{result_order}}{Optional order of read results. This can be one of either
\verb{"ROW_MAJOR, }"COL_MAJOR"\verb{, or }"auto"` (default).}

\item{\code{log_level}}{Optional logging level with default value of \code{"warn"}.}

\item{\code{iterated}}{Option boolean indicated whether data is read in call (when
\code{FALSE}, the default value) or in several iterated steps.}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
\link{SOMASparseNDArrayRead}
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-SOMASparseNDArray-write"></a>}}
\if{latex}{\out{\hypertarget{method-SOMASparseNDArray-write}{}}}
\subsection{Method \code{write()}}{
Write matrix-like data to the array. (lifecycle: maturing)
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{SOMASparseNDArray$write(values, bbox = NULL)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{values}}{Any \code{matrix}-like object coercible to a
\code{\link[Matrix:TsparseMatrix-class]{TsparseMatrix}}. Character dimension
names are ignored because \code{SOMANDArray}'s use integer indexing.}

\item{\code{bbox}}{A vector of integers describing the upper bounds of each
dimension of \code{values}. Generally should be \code{NULL}.}
}
\if{html}{\out{</div>}}
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-SOMASparseNDArray-nnz"></a>}}
\if{latex}{\out{\hypertarget{method-SOMASparseNDArray-nnz}{}}}
\subsection{Method \code{nnz()}}{
Retrieve number of non-zero elements (lifecycle: maturing)
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{SOMASparseNDArray$nnz()}\if{html}{\out{</div>}}
}

\subsection{Returns}{
A scalar with the number of non-zero elements
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-SOMASparseNDArray-resize"></a>}}
\if{latex}{\out{\hypertarget{method-SOMASparseNDArray-resize}{}}}
\subsection{Method \code{resize()}}{
Increases the shape of the array as specfied. Raises an error
if the new shape is less than the current shape in any dimension. Raises
an error if the new shape exceeds maxshape in any dimension. Raises an
error if the array doesn't already have a shape: in that case please call
tiledbsoma_upgrade_shape.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{SOMASparseNDArray$resize(new_shape)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{new_shape}}{A vector of integerish, of the same length as the array's \code{ndim}.}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
No return value
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-SOMASparseNDArray-tiledbsoma_upgrade_shape"></a>}}
\if{latex}{\out{\hypertarget{method-SOMASparseNDArray-tiledbsoma_upgrade_shape}{}}}
\subsection{Method \code{tiledbsoma_upgrade_shape()}}{
Allows the array to have a resizeable shape as described in the
TileDB-SOMA 1.15 release notes.  Raises an error if the shape exceeds maxshape in any
dimension. Raises an error if the array already has a shape.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{SOMASparseNDArray$tiledbsoma_upgrade_shape(shape)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{shape}}{A vector of integerish, of the same length as the array's \code{ndim}.}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
No return value
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-SOMASparseNDArray-clone"></a>}}
\if{latex}{\out{\hypertarget{method-SOMASparseNDArray-clone}{}}}
\subsection{Method \code{clone()}}{
The objects of this class are cloneable with this method.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{SOMASparseNDArray$clone(deep = FALSE)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{deep}}{Whether to make a deep clone.}
}
\if{html}{\out{</div>}}
}
}
}
