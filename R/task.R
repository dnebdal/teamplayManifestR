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
#' `create_task` takes an algorithm ID and a data.frame of input files and generates a JSON manifest.
#' 
#' @details
#' The algorithm ID is a text string naming the algorithm in the Teamplay system.
#' The inputFiles data.frame must have the columns Description, Filename, and MIME, 
#' in any order, and other columns will be ignored.
#' 
#' The allowed values in Description are up to the algorithm.
#' It's also up to the algorithm which MIME types it will accept, but they should
#' be valid - see https://www.iana.org/assignments/media-types/media-types.xhtml
#' 
#' @param requestedPerformer A string identifying the analysis package to run
#' @param inputFiles A data.frame with one row per input file
#' @param pretty Pretty print the JSON output (default TRUE)
#' 
#' @returns A string containing JSON, suitable for writeLines()
#' 
#' @examples
#' input_files = data.frame(
#'   Description = c("mutations", "methylation"),
#'   Filename = c("mut_export.vcf", "sample1_methylation.csv"),
#'   MIME = c("text/tab-separated-values", "text/csv")
#' )
#' manifest = create_task("OUS-0001", input_files)
#' \dontrun{writeLines(manifest, file("MANIFEST.json"))}
#' 
#' @export
create_task <- function(requestedPerformer, inputFiles, pretty=TRUE) {
  created = HL7_dateTime()
  
  # The unbox() calls stop toJSON() from creating length-1 arrays
  manifest = list(
    resourceType = jsonlite::unbox("Task"),
    text = jsonlite::unbox(data.frame(
      status = "generated",
      div = sprintf(
      "<div xmlns='http://www.w3.org/1999/xhtml'>Input task for %s , created %s</div>",
      requestedPerformer, created
    ))),
    status = jsonlite::unbox("requested"),
    intent = jsonlite::unbox("order"),
    authoredOn = jsonlite::unbox(created)
  )
  
  manifest$input = HL7_encode_attachments(inputFiles)
  return(jsonlite::toJSON(manifest, pretty=pretty))
}

#' Update a manifest, marking it as done
#' 
#' `finish_task` updates an existing manifest with a list of output files
#' 
#' Given an existing manifest describing a task to be done, e.g. from [create_task()],
#' set the status to done, last modified time to now, and append a list of
#' output files. The file list is in the same format as for [create_task()].
#' 
#' @param manifest An existing manifest. Can be any acceptable input to
#' [jsonlite::fromJSON()], or a jsonlite style list.
#' @param output_files A data.frame describing the files created
#' @param pretty Pretty-print the JSON (forwarded to toJSON)
#' 
#' @returns A string containing JSON, suitable for writeLines()
#' 
#' @examples 
#' manifest_in = system.file("extdata", "MANIFEST_request.json", package="teamplayManifest")
#' output_files = data.frame(
#'   Description = c("Survival report", "Survival table"),
#'   Filename = c("survival_report.pdf", "survival_table.csv"),
#'   MIME = c("application/pdf", "text/csv")
#' )
#' manifest = finish_task(manifest_in, output_files)
#' \dontrun{writeLines(manifest, file("MANIFEST.json"))}
#' 
#' @export
finish_task <- function(manifest, output_files, pretty = TRUE) {
  if(! is.list(manifest)) {
    manifest = jsonlite::fromJSON(manifest)
  }
  
  manifest$status = jsonlite::unbox("done")
  manifest$lastModified = jsonlite::unbox(HL7_dateTime())
  manifest$output = HL7_encode_attachments(output_files)
  
  return(jsonlite::toJSON(manifest, pretty=pretty))
}

#' Parse a manifest file into something more usable
#' 
#' `parse_task` parses a JSON manifest into an R list
#' 
#' Parses a manifest into something more usable. The most interesting
#' fields are probably `input` and `output`, data frames describing
#' the input and (optionally) output files in this task. 
#' `status` is either "requested" or "done", and the latter should correspond
#' to the existence of an `output` table.
#' 
#' @param manifest A filename or JSON string
#' 
#' @returns A list. The optional fields `input` and `output` are data.frames.
#'
#' @examples
#' task = parse_task(system.file("extdata", "MANIFEST_finished.json", package="teamplayManifest"))
#' str(task$output)
#' 
#' @export
parse_task <- function(manifest) {
  manifest = jsonlite::fromJSON(manifest)
  result = list(
    authoredOn = manifest$authoredOn,
    requestedPerformer = manifest$requestedPerformer$reference[1,1],
    status = manifest$status
  )
  
  if("lastModified" %in% names(manifest)) {
    result$lastModified = manifest$lastModified
  }
  
  if("input" %in% names(manifest)) {
    result$input = HL7_decode_attachments(manifest$input)
  }
  
  if("output" %in% names(manifest)) {
    result$output = HL7_decode_attachments(manifest$output)
  }
  
  return(result)
}
