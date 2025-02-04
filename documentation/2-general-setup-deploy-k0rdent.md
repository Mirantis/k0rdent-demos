# k0rdent Deploy

k0rdent is deployed using the Helm chart on top of the management kubernetes cluster. It installs required CRDs, kcm kubernetes operator and a couple of common utilities. However, when Helm chart is successfully deployed, k0rdent is not ready to be used at the moment. KCM operator starts the reconciliation process that installs [CAPI](https://cluster-api.sigs.k8s.io/), different cloud providers, default built-in cluster and service templates, etc. 

To get the information about k0rdent readiness you can run this command:

```shell
make watch-k0rdent-deployment
```

It checks the `Management` object, which is the KCM custom resource. This object contains requirements on what providers must be installed, the KCM release version, etc. KCM operator reconciles the platform state to satisfy requirements from this object and updates the status.

You can find detailed information about k0rdent installation in the [official documentation](https://docs.k0rdent.io/v0.1.0/admin-installation/).