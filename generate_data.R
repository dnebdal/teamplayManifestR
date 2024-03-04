require(jsonlite)

manifest_request  = fromJSON("inst/extdata/MANIFEST_request.json")
manifest_finished = fromJSON("inst/extdata/MANIFEST_finished.json")

usethis::use_data(manifest_request)
usethis::use_data(manifest_finished)

