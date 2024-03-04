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

#' Encode a datetime string in a valid HL7 FHIR format
#' 
#' `HL7_dateTime` returns a string encoding a HL7 FHIR dateTime
#' 
#' @description
#' HL7 FHIR has a DateTime data type of varying precision. If it includes
#' a time, it also requires the local timezone in \[+-\]HH:MM format,
#' which is subtly different from the \[+-\]HHMM format from [strftime()] 
#' and [format.Date()]. It's also picky about the precision: it seems to 
#' require seconds if you have time at all. 
#' 
#' See
#' https://www.hl7.org/fhir/datatypes.html#dateTime
#' 
#' @param ts A POSIXct value to encode (default [base::Sys.time()] )
#' 
#' @returns A string with the datetime with second precision and local timezone
#' 
#' @examples 
#' print(HL7_dateTime())
#' 
#' @export
HL7_dateTime <- function(ts=NULL) {
  if(is.null(ts)) { ts = Sys.time() }
  timestring = format(ts, "%Y-%m-%dT%H:%M:%S%z")
  timestring = gsub("^(.*)([0-9][0-9])([0-9][0-9])$", "\\1\\2:\\3", timestring )
  return(timestring)
}

#' Encode a file description to a jsonlite friendly list
#' 
#' `HL7_encode_attachments` takes a data frame describing files and returns something
#' that will encode to legal HL7 FHIR JSON for an input or output block in a Task.
#' 
#' @description
#' In FH7 FHIR Tasks (and perhaps other types), you can list the required inputs
#' and produced outputs as a list of values. One legal type is Attachment, which 
#' describes a file. All its fields are optional (except that .data requires .contentType),
#' and we are using .contentType and .url. The former is a MIME type describing the 
#' format of the file, and the latter can hopefully be a file:// URL giving the file name.
#' The input list also has a "type" field that can be free text; we have
#' repurposed it to describe the data modality (e.g. "CT image" or "RNASeq").
#' 
#' The data.frame must have columns named MIME, Description, and Filename.
#' 
#' See
#' https://www.hl7.org/fhir/task.html
#' https://www.hl7.org/fhir/datatypes-definitions.html#Attachment
#'
#' @param file_df A data.frame describingf the input files
#' 
#' @returns A list that will encode to a JSON fragment
#'
#' @examples
#' files = data.frame(
#'   Description = c("Survival report", "Survival table"),
#'   Filename = c("survival_report.pdf", "survival_table.csv"),
#'   MIME = c("application/pdf", "text/csv")
#' )
#' print(HL7_encode_attachments(files))
#' 
#' @export
HL7_encode_attachments <- function(file_df) {
  return(lapply(1:nrow(file_df), function(row) {
    desc     = file_df$Description[row]
    filename = file_df$Filename[row]
    MIME     = file_df$MIME[row]
    
    return(list(
      "type" = jsonlite::unbox(data.frame("text" = desc)),
      "valueAttachment" = jsonlite::unbox(data.frame(
          "contentType" = MIME,
          "url" = paste0("file://", filename)
        ))
    ))
  }))
}

#' Decode an input or output file list to a data.frame
#' 
#' `HL7_decode_attachments` decodes a file list (from parse_task or similar) into
#' a data frame describing input or oputput files.
#' 
#' The inverse of [HL7_encode_attachments()], this function takes a list
#' of the sort returned by jsonlite and simplifies it into a data.frame describing
#' files. It's in the same format as that accepted by [create_task()] and 
#' [finish_task()].
#' 
#' @param file_list A list describing files, typically $input or $output from [parse_task()]
#' 
#' @returns A data.frame with three columns describing files
#' 
#' @examples
#' files = data.frame(
#'   Description = c("Survival report", "Survival table"),
#'   Filename = c("survival_report.pdf", "survival_table.csv"),
#'   MIME = c("application/pdf", "text/csv")
#' )
#' manifest = jsonlite::fromJSON(create_task("OUS-0001", files))
#' files == HL7_decode_attachments(manifest$input)
#' 
#' @export
HL7_decode_attachments <- function(file_list) {
  atts = cbind(file_list$valueAttachment, file_list$type)
  return(data.frame(
    Description = atts$text,
    Filename = gsub("^file://", "", atts$url),
    MIME = atts$contentType
  ))
}
