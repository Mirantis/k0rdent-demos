# Deploy and setup Helm registry

During the demo we want to show how [BYO](https://docs.k0rdent.io/v0.1.0/template-byo/) `ClusterTemplate` and `ServiceTemplate` objects can be created and used to provision managed clusters and to install services on top of them. As k0rdent uses Flux CD, we will package configurations to Helm charts, push them to the Helm registry and use this registry in k0rdent.

As a simple OCI Helm registry will be used docker registry, deployed to the kind cluster as pod and exposed with the NodePort service outside of the cluster on the `30500` port. As a result, the Helm registry can be accessed from the local working machine via `oci://127.0.0.1:30500/helm-charts` and `oci://helm-registry:5000/helm-charts` inside the cluster.

You can find the registry configuration at [./setup/helmRepository.yaml](../setup/helmRepository.yaml).