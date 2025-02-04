# Bootstrap local management cluster

To demonstrate the capabilities of the k0rdent project, we need to create a [management kubernetes cluster](https://docs.k0rdent.io/v0.1.0/glossary/?h=glos#management-cluster) through which [cluster deployments](https://docs.k0rdent.io/v0.1.0/glossary/?h=glos#cluster-deployment) will be deployed and ["beach-headed" services](https://docs.k0rdent.io/v0.1.0/glossary/?h=glos#beach-head-services) will be installed on them.

For these purposes, we use the [kind utility](https://kind.sigs.k8s.io/), which easily allows you to create a local kubernetes cluster.
Cluster nodes are deployed inside containers, it turns out to be isolated and access for traffic "from the outside" is closed, except for the kubernetes API (to allow kubectl access). Since we will also need a Helm registry for further steps and in order to have access to it from our working machine, we will immediately, when creating the cluster, establish a connection from port 30500 of our working machine to port 30500 of kind cluster nodes. This port will later be used for a Helm registry NodePort service. You can find the kind cluster configuration at [setup/kind-cluster.yaml](../setup/kind-cluster.yaml).

By default, kind cluster has the `k0rdent-management-local` name and it can be changed with the `KIND_CLUSTER_NAME` environment variable.

## Prerequisites

The `make bootstrap-kind-cluster` command makes several checks before running the command that creates the cluster:

1. If Docker Engine is not installed on your machine, the binary will be installed for Linux-based OS and the error with the documentation link printed for Darwin OS. By default, the `27.4.1` Docker Engine version will be installed for Linux OS and it can be changed with the `DOCKER_VERSION` environment variable.
2. If `kind` binary is not detected on your machine, the one will be downloaded, installed in the `<local-repo-path>/bin` directory and be used during the whole demo. By default, will be installed kind version `0.25.0` and it can be changed with the `KIND_VERSION` environment variable. 
3. If `kubectl` binary is not detected on your machine, it will be downloaded, installed in the `<local-repo-path>/bin` directory and be used during the whole. The latest stable version of `kubectl` will be installed. 
