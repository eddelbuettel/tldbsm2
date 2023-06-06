#!/usr/bin/env Rscript

## version pinning info (NB: temporary from test repo)
tiledb_soma_version <- "0.0.0.10"
tiledb_soma_sha1 <- "5016f9e"

#url_linux <-     "https://github.com/eddelbuettel/tldbsm2/suites/13092681305/artifacts/710591490"
#url_macos_arm <- "https://github.com/eddelbuettel/tldbsm2/suites/13092681305/artifacts/710591492"
#url_macos_x86 <- "https://github.com/eddelbuettel/tldbsm2/suites/13092681305/artifacts/710591495"

if ( ! dir.exists("inst/") ) {
    stop("No 'inst/' directory. Exiting.", call. = FALSE)
}

makeUrl <- function(arch, ver=tiledb_soma_version, sha1=tiledb_soma_sha1) {
    ## ultimately we expect this to be   https://github.com/single-cell-data/TileDB-SOMA/archive/refs/tags/1.2.5.tar.gz
    #sprintf("https://github.com/single-cell-data/TileDB-SOMA/releases/download/%s/libtiledbsoma-%s-%s-%s.tar.gz", ver, arch, ver, sha1)
    sprintf("https://github.com/eddelbuettel/tldbsm2/releases/download/%s/libtiledbsoma-%s-%s-%s.tar.gz", ver, arch, ver, sha1)
}

isX86 <- Sys.info()["machine"] == "x86_64"
isMac <- Sys.info()["sysname"] == "Darwin"
isLinux <- Sys.info()["sysname"] == "Linux"

if (isMac && isX86) {
    url <- makeUrl("macos-x86_64")
} else if (isMac && !isX86) {
    url <- makeUrl("macos-arm64")
} else if (isLinux) {
    url <- makeUrl("linux-x86_64")
} else {
    stop("Unsupported platform for downloading artifacts. Please have TileDB Core installed locally.")
}

tarball <- "libtiledbsoma.tar.gz"
if (!file.exists(tarball)) download.file(url, tarball, quiet=TRUE)
if (!dir.exists("inst/tiledbsoma")) untar(tarball, exdir="inst/tiledbsoma")
