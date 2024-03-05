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

- User: Create a manifest with `create_task()`
- Teamplay middleware: Parse the manifest to route it to the right analysis container
- Analysis code: Parse the manifest with `parse_task()` to get a list of input files
- Analysis code: Update the manifest with `finish_task()` to add a list of output files
- Teamplay middleware: Use the updated manifest to show the user a summary of a finished task
- User: Optionally use the updated manifest to automatically do something with the results

For further reading see the help pages for those functions.

## HL7 FHIR

To make it easier to integrate into other healthcare systems, this suggested format is compliant with release 5.0 of the [HL7 FHIR](http://hl7.org/fhir/) standard. Specifically, a manifest is a [Task](https://www.hl7.org/fhir/task.html), the files are [Attachments](https://www.hl7.org/fhir/datatypes-definitions.html#Attachment), and the analysis to run is a [Device](https://www.hl7.org/fhir/device.html).

### Format examples

I suggest three kinds of manifests, for

-   The analysis containers
-   A task to be run, describing uploaded files
-   Results, extending the task file with the results created


For the containers, this would presumably be internal to the Teamplay system, and I have no opinion on who, when or where they should be generated or handwritten.
```         
{
  "resourceType" : "Device",
  "id" : "OUS-0001",
  "displayName" : "OUS multiomic survival predictor",
  "text" : {
    "status":"generated",
    "div":"<div xmlns='http://www.w3.org/1999/xhtml'>OUS-0001 : OUS multiomic survival predictor</div>"
  },
  "version" : [{
    "value" : "1.0.0"
  }],
  
  "contact" : [{
    "system" : "email",
    "value" : "author@example.com"
  }]
}
```


For tasks to be uploaded, they could be written by hand by modifying this example, but I suggest using the `create_task()` function in this R package.
```         
{
  "resourceType": "Task",
  "text": {
      "status": "generated",
      "div": "<div xmlns='http://www.w3.org/1999/xhtml'>Input task for OUS-0001 , created 2024-02-28T13:45:37+01:00<\/div>"
    },
  "status": "requested",
  "intent": "order",
  "authoredOn": "2024-02-28T13:45:37+01:00",
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
  ]
} 
```


For the result manifest, I suggest keeping the manifest uploaded with the task, changing the state from "request" to "done", and adding a last modified time and the list of files created. The `finish_task()` function in the R package automates this.
```         
{
  "resourceType": "Task",
  "text": {
      "status": "generated",
      "div": "<div xmlns='http://www.w3.org/1999/xhtml'>Input task for OUS-0001 , created 2024-02-28T13:45:37+01:00<\/div>"
    },
  "status": "completed",
  "intent": "order",
  "authoredOn": "2024-02-28T13:45:37+01:00",
  "lastModified": "2024-02-28T14:00:10+01:00",
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
