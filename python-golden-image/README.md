# python-golden-image

Repository which demonstrates an example golden image workflow for someone using Python 3. The Dockerfile uses Chainguard's Python 3 image and adds the `curl` package because of a customer's downstream requirement.

## Dockerfile
This Dockerfile starts with the `-dev` variant of the python image, adds `curl` and then carries forward that package onto the non-dev variant, which does not have a shell or APK.

## Github Workflow
The Github Actions Workflow file demonstrates several best practices when using Chainguard containers, such as
- Using Chainctl to leverage the Github source repo for identity. This prevents the storing of long-term pull tokens in your workflow
- Cosign Verfication of the source Chainguard Image
- Injection of a CA certificate after build time using Chainguard's `incert` utility. Not required but demonstrated here. Typically users would add the CA cert in their Dockerfile.
- Cosign signing of the resultant image using keyless signing
- Cosign verification of the resultant image using the identity of the source Github Actions Workflow.
- Grype Scanning to enumerate and list any CVEs.

 ## Going Further
The CA certificate is placed in the repo variables section, and is base64 encoded because of line breaks. This is why in the `incert` step you will see the `base64 -d` step being performed.

This workflow is meant to be scheduled so that it daily or nightly consumes the upstream Chainguard image. I would suggest uncommenting out the following lines in the workflow file so that the image is re-built every night. 

```
# schedule:
    # - cron: '0 0 * * *'  # Runs every day at midnight
```
