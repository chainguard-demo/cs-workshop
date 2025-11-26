# Trainer Development Workshop

## Overview

This repository contains the materials for the Chainguard Trainer Development
Workshop. The workshop is designed to help you understand the Chainguard
platform and how to teach others about it.

The workshop is broken down into them following sections.

1. Chainguard Overview
   * Explaining Chainguard Images to your teams
2. [Containers 102](../containers-102/README.md)
   * Deep dive into container images
   * Hands on exercises to learn the tactics needed for hardened,
     distroless-type images
3. [Chainguard Migration Basics](developer-track/README.md)
   * Review the differences from using a Chainguard Image and other
     Linux distributions
   * Language Migration and Examples
   * Walkthrough examples of various languages (Java, Python, etc) and
     understand how to leverage multi-stage builds to produce minimalist secure
     images
4. [Debugging Tactics](../debugging-distroless)
   * Learn various debugging strategies for Distroless images
5. Image Tags
   * Understand tags and Chainguard images
6. [CLI Tools and Demos](developer-track/README.md) 
   * Understand the different CLI tools and how to gain knowledge from your
     Chainguard images (compare, tags, scan, SBOMs and more)

## Prerequisites

It is expected that attendees have a working knowledge of containers, images,
and the common tools used to build and run them such as the command line
`docker run`, `docker build`, etc. A basic understanding of simple Dockerfiles
and the concepts around pushing and pulling to registries is also required.

In order to participate in the hands-on sections of the class, please make sure
you have access to the following tools (or the ability to install them) and
note the network connectivity requirements.

### Required

These are the minimum requirements for participating in the hands on exercises.

* A Docker-compatible runtime (i.e. [Docker Desktop](https://www.docker.com/products/docker-desktop/) or [docker cli](https://docs.docker.com/engine/install/))
* [git](https://git-scm.com/)
* an IDE /  code editor (i.e. [VS Code](https://code.visualstudio.com/), [Jetbrains IDE](https://www.jetbrains.com/), [vim](https://www.vim.org/), etc)

### Recommended

For the Kubernetes exercises, you must have:

* [kubectl](https://kubernetes.io/docs/tasks/tools/) (for local kubernetes experiments - comes with Docker Desktop)
* [Kind](https://kind.sigs.k8s.io/), [MiniKube](https://minikube.sigs.k8s.io/) or Docker Desktop Kubernetes (or any Kubernetes cluster sandbox you have access too to deploy and debug in)

These CLI tools may also come up:

* [chainctl](https://edu.chainguard.dev/chainguard/chainctl/)
* [crane](https://github.com/google/go-containerregistry/blob/main/cmd/crane/doc/crane.md)
* [cdebug](https://github.com/iximiuz/cdebug) 
* [dive](https://github.com/wagoodman/dive)
* [jq](https://jqlang.github.io/jq/) 

### Network Access Requirements

Our full platform access requirements are documented on [this
page](https://edu.chainguard.dev/chainguard/administration/network-requirements/).

If you have a private mirror of your Chainguard registry images and/or apk
package repositories, those may be used with minor modifications that we will
address in the workshops.

In addition, internet access to the following will be needed:

* [github.com](http://github.com/)
* [DockerHub](https://hub.docker.com/) (or internal proxy to it)
  * This is optional, we can work around it if DockerHub images are not available.
