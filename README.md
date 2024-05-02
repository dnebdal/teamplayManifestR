# teamplayManifestR
Generate, parse, and package manifests describing input and results from Siemens Teamplay. For a description of the format and why it exists, see [teamplayManifest-common](https://github.com/dnebdal/teamplayManifest-common). There is also a corresponding Python project, [teamplayManifest-py](https://github.com/dnebdal/teamplayManifest-py).

### Installation

Manual:

```         
git clone https://github.com/dnebdal/teamplayManifestR
R CMD INSTALL teamplayManifest
```

In R, if you have `devtools` or `remotes` installed:

```  
# Pick one
devtools::install_github("dnebdal/teamplayManifestR")
remotes::install_github("dnebdal/teamplayManifestR")
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


