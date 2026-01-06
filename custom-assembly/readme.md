# Custom Assembly Workshop Examples
- [Custom Assembly Workshop Examples](#custom-assembly-workshop-examples)
  - [Overview](#overview)
  - [Pre-requisites](#pre-requisites)
  - [Examples](#examples)
    - [Example - Using Custom Assembly with the Chainguard Console](#example---using-custom-assembly-with-the-chainguard-console)
    - [Example - Using Custom Assembly With chainctl - Dockerfile Conversion](#example---using-custom-assembly-with-chainctl---dockerfile-conversion)
  - [Using Custom Assembly with the API](#using-custom-assembly-with-the-api)

## Overview
This directory contains examples for using Custom Assembly to customize Chainguard images.  This example covers three scenarios:
1. Using the Console UI to customize images
2. Using chainctl to customize images


This guide utilizes the cs-ttt-demo.dev registry, it is not necessary to use it if you have a python CA image and the apk bundle in your registry. The CA images used in the examples are:
* custom-python-ui-demo - Used for the Console UI demo
* custom-python-chainctl-demo-dev - Used to demo creating a custom dev image using chainctl
* custom-python-chainctl-demo-runtime - Used to demo creating a custom runtime image using chainctl


## Pre-requisites
1. chainctl is installed and user has access to the chainguard org. NOTE: The user must have either the editor or ownership role in order to customize images. Chainctl install docs can be found [here](https://edu.chainguard.dev/chainguard/chainctl-usage/how-to-install-chainctl/)
2. Docker installed to run images
3. For the chainctl demo below, the mariadb image must be in your registry or the package must exist in your Private APK Repo.

## Examples
This section walks through some examples of using custom assembly.

### Example - Using Custom Assembly with the Chainguard Console
This is meant to be a straightforward example of CA using the console.

1. Login to the [Chainguard console](https://console.chainguard.dev)
2. Select the org (if you have multiple) to use, this demo uses the cs-ttt-demo.dev Chainguard org.
3. Select Organization Images tab
4. Select the `custom-python-ui-demo` image
5. (Optional) Prior to customizing the image try to run curl: 

    From your terminal run:

    ```
    docker run --pull=always  --rm --entrypoint curl cgr.dev/cs-ttt-demo.dev/custom-python-ui-demo:latest -v https://chainguard.dev
    ```

    You should see an error that curl is not available in the container.

6. Go back to the Console, click the "Customize Image" button.

    The list that appears contains all of the entitled packages that can be added to the image, i.e. these are all the packages the org is entitled to.  

7. Select package(s) to add to the image e.g. `curl`.
8. Select "Continue"
9. Choose if you would like you create a new image or customize the current image. 

    If you select `Customize the current image`, the curl package will be included in your "custom-python-ui-demo" image in every tag. Use this option when you know for certain that you would like `curl` to always be included in your image and there will be no need for any other variants. If you add specific versions of a package it may break certain tag builds.

    If you select `Create a new image`, a duplicate image repo will be created, based on the original, but with the new packaged added. Use this option when users may still need to use the original image without customization, but you are seeking to provide an image that also has additional packages.

    For this excercise, select `Customize the current image`.
10. Select "Preview changes"

    This view highlights of the changes to be made, and note the warnings that are display about CA images.

9.  Select "Create"
10. Select "Go to Builds"

    This will take the user to the builds page, you may need to hit the "Refresh" button a few times in order to see the status of the build (it can take a bit for the builds to show up on the builds page).

    You should eventually see some "Pending" builds come up 

    The builds are completed when you see a "Tag" assigned to the build ID. There will be multiple builds happening, one for each -dev and distroless variant for each supported tag.  Some images may result in a lot of builds (for the python image a customization would kick off about 10 builds).

    When the build is completed (successful or failed) you can select one of the rows and display the logs. 

    If a build fails due to a transient infrastructure issue they will be retried. If a build fails due to something else, for example a package not being available for a specific architecture (e.g. arm64 or x86_64), reach out to your CS team or open a support ticket.

    After the build has completed navigate to the "SBOM" tab of the page.

11. Select the "SBOM" tab

    Show that the packages added now show up in the SBOM. If you search for `curl` you should see it along with the dependency `libcurl-openssl4` that was also installed as part of adding curl to the image.

12. (Optional) Run the custom image to verify curl has been installed. Keep in mind that if you selected `Create a new image` that you will need to use that image name. 

    ```
    docker run --pull=always  --rm --entrypoint curl cgr.dev/cs-ttt-demo.dev/custom-python-ui-demo:latest -v https://chainguard.dev
    ```

12. Cleanup: Select "Customize Image"

    Remove the package that was added, to clean up.

### Example - Using Custom Assembly With chainctl - Dockerfile Conversion

In this example we will walk through converting a Dockerfile which is currently using `apk add` to add dependencies to using Custom Assembly built images. The demo is a simple Python app that uses the mariadb database connection driver. This python app requires additional dependencies to be installed on to the Chainguard python base image.

1. cd into the custom-assembly chainctl directory

    ```
    cd custom-assembly/chainctl
    ```

2.  Display the current Dockerfile

    ```
    % cat Dockerfile.original 
    FROM cgr.dev/chainguard/python:latest-dev AS dev

    # The python image on DockerHub includes mariadb packages as standard but we
    # need to add them explicitly.
    USER root
    RUN apk add --no-cache mariadb-connector-c-dev mariadb

    # # Install the runtime packages into a root derived from the distroless image.
    COPY --from=cgr.dev/chainguard/python:latest / /base-chroot
    RUN apk add --no-commit-hooks --no-cache --root /base-chroot  mariadb-connector-c mariadb

    USER 65532

    # Install python packages into a virtual environment so they can be easily
    # copied into the runtime stage.
    WORKDIR /app
    RUN python -m venv venv
    ENV PATH="/app/venv/bin":$PATH
    COPY requirements.txt requirements.txt
    RUN pip install --no-cache-dir -r requirements.txt

    FROM cgr.dev/chainguard/python:latest

    # Replace the filesystem with the one containing the additional packages.
    COPY --from=dev /base-chroot /

    # # Copy virtual environment into the runtime stage.
    WORKDIR /app
    COPY --from=dev /app/venv /app/venv
    ENV PATH="/app/venv/bin":$PATH

    COPY run.py run.py

    ENTRYPOINT ["python", "run.py"]
    ```
    This Dockerfile demonstrates the use of a chroot-based approach to install build-time dependencies in a dedicated builder image, compile the application, and then transfer only the necessary runtime dependencies into a minimal distroless image for runtime. The end result is a Dockerfile that appears to be somewhat complicated. Some important things to note, the dependencies needed in the builder stage are different than the dependencies needed in the runtime image. While you could use the same base for both the build and runtime we would like our runtime image to be as minimal as possible which is why we don't include the mariadb-connector-c-dev package in the runtime image. 

3. Build and run the image:

    ```
    docker build -t python-ca-demo-chroot -f Dockerfile.original .
    docker run --rm python-ca-demo-chroot
    ```

4.  Create Builder Custom YAML File

    Now we will utilize Custom Assembly to replicate this docker build. We will use two CA images in this example, one for the buildtime dependencies and another for the final runtime image.

    The first step is to create a yaml file defining the packages we want to install on the custom images.

    This file will contain the packages we want to add to the custom image:
    ```
    cat > python-ca-builder.yaml <<EOF
    contents:
      packages:
        - mariadb-connector-c-dev
        - mariadb
    EOF
    ```
    **NOTE:** If needed this yaml file can be checked into source control for tracking purposes. In addition, as more features of Custom Assembly are made available, the yaml structure will be updated to support them.

5.  Use chainctl to apply the customizations to the builder image

    Use chainctl to apply the changes to the `custom-python-chainctl-demo-dev` custom image.  Here we will utilize some command switches that are documented [here](https://edu.chainguard.dev/chainguard/chainctl/chainctl-docs/chainctl_images_repos_build_apply/) 
    
    ```
    --parent string    The name or id of the parent location to apply build config.
    --repo string      The name or id of the repo to apply build config.
    --save-as string   Create a new repo with the edited configuration instead of updating the existing one.
    -y, --yes          Automatic yes to prompts; assume "yes" as answer to all prompts and run non-interactively.
    ```

    Note: the --parent parameter may be changed if you are using a different Chainguard org. Here we use the --yes flag to auto confirm the changes. Remember that changes to an existing image will affect every tag. This may break the functionality of other tags depending on how your organization uses tags. 

    ```
    ORGANIZATION="cs-ttt-demo.dev"
    REPO="custom-python-chainctl-demo-dev"

    chainctl image repo build apply -f python-ca-builder.yaml --parent $ORGANIZATION --repo $REPO --yes
    ```

    Note: if you want to save this image as a different name, similar to the `Create a new image` option on the web, use the --save-as parameter in addtion to the --repo paremeter. The --repo parameter specifies the source repo you are creating the image from.

    ```
    ORGANIZATION="cs-ttt-demo.dev"
    REPO="custom-python-curl-chainctl-demo-dev"
    NEW_REPO="mariadb-python-chainctl-demo-dev"

    chainctl image repo build apply -f python-ca-builder.yaml --parent $ORGANIZATION --repo $REPO --save-as $NEW_REPO  --yes
    ```


6. Get status of the build

    After submitting the changes, we can use chainctl to get the status of the image build:

    ```
    chainctl image repo build list --parent $ORGANIZATION --repo $REPO
    ```
    You should see an output similar to this:

    ```
    ⠏           START TIME           |        COMPLETION TIME        | RESULT  |                  TAGS                    
    --------------------------------+-------------------------------+---------+------------------------------------------                     
    Fri, 06 Jun 2025 10:36:12 MST | Fri, 06 Jun 2025 10:36:20 MST | Success | 3.10, 3.10.18                            
    Fri, 06 Jun 2025 10:36:08 MST | Fri, 06 Jun 2025 10:36:17 MST | Success | 3.11, 3.11.13                            
    Fri, 06 Jun 2025 10:36:04 MST | Fri, 06 Jun 2025 10:36:11 MST | Success | 3, 3.13, 3.13.3, latest                  
    Fri, 06 Jun 2025 10:36:00 MST | Fri, 06 Jun 2025 10:36:15 MST | Success | 3.12, 3.12.11                            
    Fri, 06 Jun 2025 10:36:00 MST | Fri, 06 Jun 2025 10:36:28 MST | Success | 3.10-dev, 3.10.18-dev                    
    Fri, 06 Jun 2025 10:35:49 MST | Fri, 06 Jun 2025 10:36:08 MST | Success | 3.12-dev, 3.12.11-dev                    
    Fri, 06 Jun 2025 10:35:41 MST | Fri, 06 Jun 2025 10:35:49 MST | Success | 3.9, 3.9.23                              
    Fri, 06 Jun 2025 10:35:41 MST | Fri, 06 Jun 2025 10:36:04 MST | Success | 3-dev, 3.13-dev, 3.13.3-dev, latest-dev  
    Fri, 06 Jun 2025 10:35:41 MST | Fri, 06 Jun 2025 10:36:00 MST | Success | 3.11-dev, 3.11.13-dev                    
    Fri, 06 Jun 2025 10:35:41 MST | Fri, 06 Jun 2025 10:36:00 MST | Success | 3.9-dev, 3.9.23-dev                      
    Fri, 06 Jun 2025 10:29:28 MST | Fri, 06 Jun 2025 10:29:36 MST | Success | 3.10, 3.10.18                            
    Fri, 06 Jun 2025 10:29:22 MST | Fri, 06 Jun 2025 10:29:56 MST | Success | 3.10-dev, 3.10.18-dev                    
    Fri, 06 Jun 2025 10:29:21 MST | Fri, 06 Jun 2025 10:29:57 MST | Success | 3.9-dev, 3.9.23-dev                      
    Fri, 06 Jun 2025 10:29:21 MST | Fri, 06 Jun 2025 10:29:31 MST | Success | 3.11, 3.11.13                            
    Fri, 06 Jun 2025 10:29:08 MST | Fri, 06 Jun 2025 10:29:21 MST | Success | 3.12, 3.12.11                            
    Fri, 06 Jun 2025 10:29:00 MST | Fri, 06 Jun 2025 10:29:08 MST | Success | 3, 3.13, 3.13.3, latest                  
    Fri, 06 Jun 2025 10:28:52 MST | Fri, 06 Jun 2025 10:29:00 MST | Success | 3.9, 3.9.23                         
    ```

    **NOTE:** There is a delay from when you submit the You may need to wait a bit before the latest results are visible.

7. View build logs:

    You can view the build logs, directly with chainctl:

    ```
    chainctl image repo build logs --parent $ORGANIZATION --repo $REPO
    ```

    You can select the build you'd like to see the logs for.

    Additionally, if you use `-o json` in the build list command it will display more details in json format, and you can use `jq` to parse the output. For example, to get the latest build details:

    ```
    chainctl image repo build list --parent $ORGANIZATION --repo $REPO -o json | jq -r '.reports[0]'
    ```

    To just get the latest build status:

    ```
    chainctl image repo build list --parent $ORGANIZATION --repo $REPO -o json | jq -r '.reports[0] .result'
    ```

    To get the latest build log:

    ```
    chainctl image repo build list --parent $ORGANIZATION --repo $REPO -o json | jq -r '.reports[0] .log'
    ```

8. Build Runtime Image

    Since our final runtime image has different dependencies from our build image we will prepare another CA image with just the packages required for runtime.
    Start by creating the yaml file defining the list of required packages, here we will be customizing the `custom-python-chainctl-demo-runtime` image:

    ```
    REPO="custom-python-chainctl-demo-runtime"
    cat > python-ca-runtime.yaml <<EOF
    contents:
      packages:
        - mariadb-connector-c
        - mariadb
    EOF
    ```

    Apply the changes:

    ```
    chainctl image repo build apply -f python-ca-runtime.yaml --parent $ORGANIZATION --repo $REPO --yes
    ```

    View the build logs:

    ```
    chainctl image repo build logs --parent $ORGANIZATION --repo $REPO
    ```

    Check the result of the last build:

    ```
    chainctl image repo build list --parent $ORGANIZATION --repo $REPO -o json | jq -r '.reports[0] .result'
    ```

    **Note:** If the output of the above command is `null` or `pending` then the build hasn't started yet.

9. Update Dockerfile

    Now that we have our images build with Custom Assembly modify the Dockerfile to use a multistage build without the need to add any apk packages:

    ```
    FROM cgr.dev/cs-ttt-demo.dev/custom-python-chainctl-demo-dev:latest-dev AS dev

    # Install python packages into a virtual environment so they can be easily
    # copied into the runtime stage.
    WORKDIR /app
    RUN python -m venv venv
    ENV PATH="/app/venv/bin":$PATH
    COPY requirements.txt requirements.txt
    RUN pip install --no-cache-dir -r requirements.txt

    # Runtime image
    FROM cgr.dev/cs-ttt-demo.dev/custom-python-chainctl-demo-runtime:latest

    # # Copy virtual environment into the runtime stage.
    WORKDIR /app
    COPY --from=dev /app/venv /app/venv
    ENV PATH="/app/venv/bin":$PATH

    COPY run.py run.py
    ENTRYPOINT ["python", "run.py"]
    ```

    **Note:** The dockerfile is considerably simplified when using the custom assembly images.

10. Build the image

    ```
    docker build -t python-ca-demo -f Dockerfile.ca .
    ```

11. Run the image:

    ```
    docker run --rm python-ca-demo
    ```

12. Compare chroot and CA assembled images:

    ```
    docker image list | grep python-ca-demo 
    ```

    The runtime image put together with Custom Assembly is much smaller than using the chroot method, this is due to the intermediate layer of copying the /chroot directory over the original root directory in order to install the dependencies into the distroless variant. Additionally, Chainguard will continue to build the Custom Assembled image as new python versions get released, and will require much less maintenance over all.

13. Cleanup

    Run the following to set the `custom-python-chainctl-demo-dev` and `custom-python-chainctl-demo-runtime` back to their uncustomized state:

    ```
    cat > reset-packages.yaml <<EOF
    contents:
      packages:
    EOF    

    ORGANIZATION="cs-ttt-demo.dev"
    REPO="custom-python-chainctl-demo-dev"
    REPO2="custom-python-chainctl-demo-runtime"

    chainctl image repo build apply -f reset-packages.yaml --parent $ORGANIZATION --repo $REPO --yes
    chainctl image repo build apply -f reset-packages.yaml --parent $ORGANIZATION --repo $REPO2 --yes
    ```


## Using Custom Assembly with the API

If you are interested in utilizing the API to interact with Custom Assembly the tutorial on the [Chainguard edu site](https://edu.chainguard.dev/chainguard/chainguard-images/features/ca-docs/custom-assembly-api-demo/)