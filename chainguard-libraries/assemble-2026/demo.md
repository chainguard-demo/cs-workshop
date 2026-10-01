# Assemble London 2026 Demo

I want to create a demo of migrating to Chainguard Libraries in the same style
as other demos in this repo (with a demo.sh script).

The high level flow I want to achieve:

This should start with a working uv python project with a lockfile and a decent sampling of dependencies that are pulled from PyPI. 

This should include:
  - A version that we have a CVE remediation for in our remediated index
  - A version that is blocked as malware
  - At least one or two libraries that are not built from source by us

Then the high level flow should be, I think:

1. We demonstrate that we can install and build and run the project from PyPI
   fine.
2. We configure uv to point at Chainguard Libraries (remediated and
   non-remediated indexes), using a short lived token
   $(chainctl auth token --audience=libraries.cgr.dev) as the credentials.
3. We try and build and its seems to work.
4. We run chainctl libraries verify and we can see that there are no Chainguard
   libs (it reused the cache)
5. We clear the cache and try again. It fails because of integrity errors.
6. We run 'chainctl libraries update-hashes' to update the lockfile.
7. If we rebuild, we find we get a 404 for the blocked malware version.
8. We can view this block with chainctl.
9. We resolve the block (by upgrading the version, maybe?)
10. The build should now succeed?
11. We can run chainctl libraries verify.
12. We scan the project and we find the CVE that is remediated. 
13. If we then upgrade that version or something, we should see it pull in the remediated
    version?

I'm not sure of all the ordering here or if the behaviour is exactly as I
assume. But I basically want a demo.sh that can push us down this flow and
demonstrate all these things end-to-end.

We'll probably have to adjust if the errors that flag up are different at
different points.
