# SPDX-License-Identifier: MIT
#
# Copyright (c) 2024 Daniel J. H. Nebdal
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
#   The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


#' Create a manifest describing a task to be done.
#'
#' `createManifest` creates a manifest from an algorithm ID, sample info, and a data.frame of input files
#'
#' @details
#' The algorithm ID is a text string naming the algorithm in the Teamplay system.
#' The files data.frame must have the columns Description, Filename, and MIME,
#' in any order, and other columns will be ignored.
#'
#' The sampleID and encounter are just text fields. While they accept most unicode
#' characters, they will be re-used by [packageManifest()] to build the file name.
#' Since that puts strict limitations on allowed characters, it's best to stick to ASCII.
#'
#' The allowed values in Description are up to the algorithm.
#' It's also up to the algorithm which MIME types it will accept, but they should
#' be valid - see https://www.iana.org/assignments/media-types/media-types.xhtml
#'
#' @param requestedPerformer A string identifying the analysis package to run
#' @param sampleID ID of the sample/patient to be analysed
#' @param encounter The timepoint or encounter the data is from
#' @param files A data.frame with one row per input file
#' @param pretty Pretty print the JSON output (default TRUE)
#'
#' @returns A list of class `manifest`
#'
#' @examples
#' input_files = data.frame(
#'   Description = c("mutations", "methylation"),
#'   Filename = c("mut_export.vcf", "sample1_methylation.csv"),
#'   MIME = c("text/tab-separated-values", "text/csv")
#' )
#' manifest = createManifest("OUS-0001", "Sample-001", "EOT", input_files)
#'
#' @export
createManifest <- function(requestedPerformer, sampleID, encounter, files, pretty=TRUE) {
  created = HL7_dateTime()

  manifest = list(
    resourceType = "Task",
    text = data.frame(
      status = "generated",
      div = sprintf(
        "<div xmlns='http://www.w3.org/1999/xhtml'>Input task for %s , created %s</div>",
        requestedPerformer, created
      )),
    status =     "requested",
    intent =     "order",
    sampleID =   sampleID,
    encounter =  encounter,
    authoredOn = created,
    requestedPerformer = requestedPerformer
  )

  manifest$input = files
  class(manifest) <- c("list", "manifest")
  return(manifest)
}

#' Read a manifest from a file
#'
#' `readManifest` parses a JSON manifest into a manifest object
#'
#' Parses a manifest into something more usable.
#' The manifest class is a list with some helper functions. The most interesting
#' fields are probably `input` and `output`, data frames describing
#' the input and (optionally) output files in this task.
#' `status` is either "requested" or "done", and the latter should correspond
#' to the existence of an `output` table.
#'
#' @param manifest A filename or JSON string
#'
#' @returns A list of class `manifest`.
#' The optional fields `input` and `output` are data.frames.
#'
#' @examples
#' task = readManifest(system.file("extdata", "MANIFEST_finished.json", package="teamplayManifest"))
#' str(task$output)
#'
#' @export
readManifest <- function(manifest) {
  manifest = jsonlite::fromJSON(manifest)
  result = list(
    authoredOn = manifest$authoredOn,
    requestedPerformer = manifest$requestedPerformer$reference[1,1],
    status = manifest$status,
    sampleID = manifest$focus$reference,
    encounter = manifest$encounter$reference
  )

  if("for" %in% names(manifest)) {
    result$zipfile = manifest$`for`$reference
  }

  if("lastModified" %in% names(manifest)) {
    result$lastModified = manifest$lastModified
  }

  if("input" %in% names(manifest)) {
    result$input = HL7_decode_attachments(manifest$input)
  }

  if("output" %in% names(manifest)) {
    result$output = HL7_decode_attachments(manifest$output)
  }

  class(result) <- c("list", "manifest")
  return(result)
}

#' Update a manifest, marking it as done
#'
#' `finalizeManifest` marks a manifest as done and adds a lits of output files
#'
#' Given an existing manifest describing a task to be done, e.g. from [createManifest()],
#' set the status to done, last modified time to now, and append a list of
#' output files. The file list is in the same format as for [createManifest()],
#' so it must have columns named `Description`, `Filename` and `MIME`.
#'
#' @param manifest An existing manifest. Can be any acceptable input to
#' [readManifest()], or a jsonlite style list.
#' @param output_files A data.frame describing the files created
#'
#' @returns A manifest in list form, suitable for [packageManifest()]
#'
#' @examples
#' manifest_in = system.file("extdata", "MANIFEST_request.json", package="teamplayManifest")
#' output_files = data.frame(
#'   Description = c("Survival report", "Survival table"),
#'   Filename = c("survival_report.pdf", "survival_table.csv"),
#'   MIME = c("application/pdf", "text/csv")
#' )
#' manifest = finalizeManifest(manifest_in, output_files)
#' \dontrun{packageManifest(manifest)}
#'
#' @export
finalizeManifest <- function(manifest, output_files) {
  if(! is.manifest(manifest)) {
    manifest = readManifest(manifest)
  }

  manifest$status = "completed"
  manifest$lastModified = HL7_dateTime()
  manifest$output = output_files

  return(manifest)
}

#' Package the input or output files in a manifest
#'
#' `packageManifest` packages the input/output files (as appropriate) and the manifest to a zip file
#'
#' @description
#' Depending on the `status` field of a manifest, this packages the files
#' in the `input` or `output` table, plus a JSON encoding of the manifest,
#' into a package. For now, the only supported `fileType` is zip, though there
#' is no reason this could not be extended to better compression methods
#' in later revisions.
#'
#' @param manifest A manifest object, path to a manifest file, or JSON string
#' @param fileType The kind of package to create. For now the default "zip" is the
#' only valid choice.
#'
#' @export
packageManifest = function(manifest, fileType="zip") {
  validTypes = c("zip")
  if (! fileType %in% validTypes) {
    stop("File type ", fileType, " is not one of ", validTypes)
  }

  if(!is.manifest(manifest)) {
    manifest = readManifest(manifest)
  }

  if(manifest$status == "completed") {
    output = "RES"
    filelist = manifest$output$Filename
  } else {
    output = "NEW"
    filelist = manifest$input$Filename
  }

  if(!all(file.exists(filelist))) {
    errortable = data.frame(
      Filename=filelist,
      Exists=file.exists(filelist)
    )
    printf("Some or all input files missing:\n")
    print(errortable[order(errortable$Exists, errortable$Filename),])
    return(invisible(NULL))
  }

  manifest$zipfile = sprintf("%s.%s.%s.%s.%s.%s",
                             output,
                             cleanForFilename(manifest$sampleID, "--MISSING_sampleID--"),
                             cleanForFilename(manifest$encounter, "--MISSING_encounter--"),
                             cleanForFilename(manifest$requestedPerformer, "--MISSING_requestedPerformer--"),
                             format(Sys.time(), "%s"),
                             fileType
  )

  # To include the manifest, it must exist as a file on disk
  # To not overwrite anything, put it in a temporary directory
  # and delete it afterwards
  tmpdir = tempdir()
  tmpManifest = file.path(tmpdir, "MANIFEST.json")
  writeLines(manifestToJSON(manifest, pretty=2), tmpManifest)
  filelist = c(filelist, tmpManifest)

  printf("Compressing %s to %s\n", paste(filelist, collapse=","), manifest$zipfile)
  res = zip::zip(manifest$zipfile, filelist, compression_level = 6, mode="cherry-pick")

  unlink(tmpManifest)
  unlink(tmpdir)
  return(res)
}

#' Convert a manifest object to JSON text
#'
#' `manifestToJSON` converts a manifest object to JSON text
#'
#' @description
#' Converts a manifest object to HL7 FHIR compliant JSON.
#' `pretty` defaults to FALSE, but you can set it to TRUE for more readable
#' output, or to a number to use that many spaces for indentation.
#'
#' It also accepts all the other settings for [jsonlite::toJSON()],
#' but you shouldn't have to touch them.
#'
#' @param x Manifest to convert
#' @param pretty Pretty-print JSON output
#' @param ... passed to toJSON
#'
#' @export
manifestToJSON <- function(x, pretty=FALSE, ...) {
  status = ifelse(x$status == "completed", "Output", "Input")

  manifestNew = list(
    resourceType = jsonlite::unbox("Task"),
    text = jsonlite::unbox(data.frame(
      status = "generated",
      div = sprintf(
        "<div xmlns='http://www.w3.org/1999/xhtml'>%s task for %s , created %s</div>",
        status, x$requestedPerformer, x$authoredOn
      ))),
    status =     jsonlite::unbox(x$status),
    requestedPerformer =  list(list(reference = jsonlite::unbox(data.frame(reference = x$requestedPerformer)))),
    intent =     jsonlite::unbox("order"),
    focus =      jsonlite::unbox(data.frame(reference=x$sampleID)),
    encounter =  jsonlite::unbox(data.frame(reference=x$encounter)),
    authoredOn = jsonlite::unbox(x$authoredOn)
  )

  if("zipfile" %in% names(x)) {
    manifestNew$`for` = jsonlite::unbox(data.frame(reference=x$zipfile))
  }

  if("input" %in% names(x)) {
    manifestNew$input = HL7_encode_attachments(x$input)
  }

  if("output" %in% names(x)) {
    manifestNew$output = HL7_encode_attachments(x$output)
  }

  return(jsonlite::toJSON(manifestNew, pretty=pretty, ...)
  )
}

#' Check for manifest
#'
#' `is.manifest` test if an object is of class manifest
#'
#' @param x object to test
#'
#' @export
is.manifest = function(x) {
  return("manifest" %in% class(x))
}
