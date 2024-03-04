#' Example manifest for files to be uploaded to teamplay
#'
#' This is the output from jsonlite::fromJSON() for a manifest with two
#' input files. You can read the original JSON from
#' `system.file("extdata", "MANIFEST_request.json", "teamplayManifest")`.
#'
#' @docType data
#' @name manifest_request
"manifest_request"

#' Example manifest for files to be downloaded from teamplay
#'
#' This is the output from jsonlite::fromJSON() for a manifest with two
#' input files and two output files. You can read the original JSON from
#' `system.file("extdata", "MANIFEST_finished.json", "teamplayManifest")` .
#'
#' @name manifest_finished
#' @docType data
"manifest_finished"
