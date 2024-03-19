# teamplayManifest

The [teamplay digital health platform](https://www.siemens-healthineers.com/no/digital-health-solutions/teamplay-digital-health-platform) from Siemens Healthineers can be used to run containers written elsewhere for the purpose of running some sort of analysis on your own data. As designed, it expects images following the DICOM standard, containing all required metadata embedded in the image. This does not work when extending the platform to work with other data formats, like the text files typical of other -omics. It also seemed reasonable to use the same format to describe the files created by the analysis and returned to the user.

For those files, I suggest adding a manifest file that describes what the uploaded files contains, and which analysis should be run on them. This repository is both a description of that suggested manifest format, and an R package for reading and writing them.


## The R package

The R package contains utility functions to generate a new manifest, to mark one as finished and add output files, and to parse a manifest into something easier to work with.

### Installation

Manual:

```         
git clone https://github.com/dnebdal/teamplayManifest
R CMD INSTALL teamplayManifest
```

In R, if you have `devtools` installed:

```         
devtools::install_github("dnebdal/teamplayManifest")
```

### Workflow
The intended flow is something like this:

- User: Create a manifest with `createManifest()`
- User: Package the input files and manifest as a zip file with `packageManifest()`
- Teamplay middleware: Parse the manifest to route it to the right analysis container
- Analysis code: Parse the manifest with `readManifest()` to get a list of input files
- Analysis code: Update the manifest with `finalizeManifest()` to add a list of output files
- Analysis code: Package the output as a zip file with `packageManifest()`
- Teamplay middleware: Use the updated manifest to show the user a summary of a finished task?
- User: Optionally use the updated manifest to automatically do something with the results

For further reading see the help pages for those functions.

## HL7 FHIR

To make it easier to integrate into other healthcare systems, this suggested format is compliant with release 5.0 of the [HL7 FHIR](http://hl7.org/fhir/) standard. Specifically, a manifest is a [Task](https://www.hl7.org/fhir/task.html), the files are [Attachments](https://www.hl7.org/fhir/datatypes-definitions.html#Attachment), and the analysis to run is a [Device](https://www.hl7.org/fhir/device.html).

### Format examples

The manifest will be read at a few different stages:
- By Teamplay, to route the data to the right analysis container
- By the analysis container to get a description of the input files
- By who or whatever consumes the output package from the analysis container

Some fields are common between these. This is a suggested manifest that should 
be sufficient for Teamplay, describing an analysis to be done for a patient 
pseudonymized as `OUS_Patient1`, at timepoint `Start of treatment`, using 
the analysis container `OUS-0001`, and packed into zip file `OUS_Patient1.Start_of_treatment.OUS-0001.1710166715.zip`. As a disambiguation, 
I suggest adding the timestamp the file was created as the last field in the zip 
file name.

```         
{
  "resourceType": "Task",
  "text": {
      "status": "generated",
      "div": "<div xmlns='http://www.w3.org/1999/xhtml'>
      Input task for OUS-0001, 
      created 2024-02-28T13:45:37+01:00
      <\/div>"
    },
  "status": "requested",
  "intent": "order",
  "authoredOn": "2024-02-28T13:45:37+01:00",
  "focus":{"reference":"OUS_Patient1"},
  "for":{"reference":"OUS_Patient1.Start_of_treatment.OUS-0001.1710166715.zip"},
  "encounter":{"reference":"Start of treatment"},
  "requestedPerformer" : [{
      "reference":{"reference":"OUS-0001"}
    }]
}
```

To provide information about the files included, add an `input` block to the
manifest. This one describes two files:
```
  "input": [
    {
      "type": {
          "text": "VCF"
        },
      "valueAttachment": {
          "contentType": "text/tab-separated-values",
          "url": "file://mutations.vcf"
        }
    },
    {
      "type": {
          "text": "Methylation"
        },
      "valueAttachment": {
          "contentType": "text/csv",
          "url": "file://methylation.csv"
        }
    }
  ]
```

To describe the output files, add an output block in the same format, and change
the `for` field to the name of the output zip file.
I suggest keeping the input block to indicate what the input files were, 
updating the `status` field to `completed`, and adding a `lastModified` field
indicating when the analysis finished. This is a complete example of how the output
could look after completing the analysis from the above example:


```
{
 "resourceType": "Task",
  "text": {
      "status": "generated",
      "div": "<div xmlns='http://www.w3.org/1999/xhtml'>
      Results for task for OUS-0001, 
      created 2024-02-28T14:00:00+01:00
      <\/div>"
    },
  "status": "completed",
  "intent": "order",
  "authoredOn": "2024-02-28T13:45:37+01:00",
  "lastModified": "2024-02-28T14:00:10+01:00",
  "focus":{"reference":"OUS_Patient1"},
  "for":{"reference":"OUTPUT.OUS_Patient1.Start_of_treatment.OUS-0001.1710167000.zip"},
  "encounter":{"reference":"Start of treatment"},
  "requestedPerformer" : [{
      "reference":{"reference":"OUS-0001"}
    }],
     "input": [
    {
      "type": {
          "text": "VCF"
        },
      "valueAttachment": {
          "contentType": "text/tab-separated-values",
          "url": "file://mutations.vcf"
        }
    },
    {
      "type": {
          "text": "Methylation"
        },
      "valueAttachment": {
          "contentType": "text/csv",
          "url": "file://methylation.csv"
        }
    }
  ],
  "output": [
    {
      "type": {
          "text": "Survival report"
        },
      "valueAttachment": {
          "contentType": "application/pdf",
          "url": "file://survival_report.pdf"
        }
    },
    {
      "type": {
          "text": "Survival table"
        },
      "valueAttachment": {
          "contentType": "text/csv",
          "url": "file://survival_table.csv"
        }
    }
  ]
}
```


# Python
I intend to write a Python package with similar functionality, but so far it does not exist.
