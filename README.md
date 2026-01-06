# RCE Vuln exploit example
This repo shows a hands-on example of how an a Remote Code Execution (RCE) vulnerability in an Open Source library can be exploited in a containerized application.  The goal of this demonstration is to show the importance of defense in depth including, but not limited to, the following topics:
1. keeping your dependencies updated
2. minimizing the attack surface of your container
3. least privelge policies

## Overview
This demonstration creates and deploys pods on a standalone [kind][kind] Kubernetes cluster. The application is a basic Java-based web chat server using websockets.  The application is dependant on a very old version of the Log4J library which is vulnerable to [CVE-2021-44228][cve], a.k.a. Log4Shell. 

## Setup

### Prerequisites
* [git][git]
* [kind][kind]
* A [kind][kind] compatible container runtime (docker, podman, containerd + nerdctl)
* [kubectl][kubectl-install]
* [nc][netcat] (netcat) 
* [tmux][tmux] (need to run the automated setup script)

### Start up the demo 

#### Automated method
Run `./setup.sh`

The script will check for and start up a kind cluster, build and deploy the app and exploit pods and present a 3-section tmux session for the demo.

The tmux session sections should show
1. 

### TODO - Finish this

[git]: https://git-scm.com/
[kind]: https://kind.sigs.k8s.io/
[cve]: https://nvd.nist.gov/vuln/detail/cve-2021-44228
[kubectl-install]: https://kubernetes.io/docs/tasks/tools/#kubectl
[tmux]: https://github.com/tmux/tmux/wiki/Installing
[netcat]: https://netcat.sourceforge.net/