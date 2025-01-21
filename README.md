# k0rdent Demo Repo

## What this is for

The intention of this k0rdent Demo repo is to have a place for demos and examples on how to leverage the Mirantis k0rdent Project.

It includes scripts and implementation examples for basic and advanced usage for k0rdent.

All demos in here provide their own complete ClusterTemplates and ServiceTemplates and do not use the included k0rdent templates at all. This is done on one side to not be depending on k0rdent included templates and on the other side shows how custom and BYO (bring your own) templates can be used. Learn more about [BYO Templates in the k0rdent documentation](https://k0rdent.github.io/docs/template/byo-templates/).

## Table of Contents

1. [Setup](#setup)
   1. [Prerequisites](#prerequisites)
   1. [General setup](#general-setup)
   1. [Infrastructure setup](#infra-setup)
      1. [AWS setup](#aws-setup)
      1. [Azure setup](#azure-setup)
      1. [OpenStack setup](#openstack-setup)
1. [Demo 1: Standalone Cluster Deployment](#demo-1-standalone-cluster-deployment)
1. [Demo 2: Single Standalone Cluster Upgrade](#demo-2-single-standalone-cluster-upgrade)
1. [Demo 3: Install ServiceTemplate into single cluster](#demo-3-install-servicetemplate-into-single-cluster)
1. [Demo 4: Install ServiceTemplate into multiple clusters](#demo-4-install-servicetemplate-into-multiple-clusters)
1. [Demo 5: Approve ClusterTemplate & InfraCredentials for separate Namespace](#demo-5-approve-clustertemplate--infracredentials-for-separate-namespace)
1. [Demo 6: Use approved ClusterTemplate in separate Namespace](#demo-6-use-approved-clustertemplate-in-separate-namespace)
1. [Demo 7: Test new ClusterTemplate as k0rdent Admin, then approve them in separate Namespace](#demo-7-test-new-clustertemplate-as-k0rdent-admin-then-approve-them-in-separate-namespace)
1. [Demo 8: Use newly approved ClusterTemplate in separate Namespace](#demo-8-use-newly-clustertemplate-namespace-in-separate-namespace)
1. [Demo 9: Approve ServiceTemplate in separate Namespace](#demo-9-approve-servicetemplate-in-separate-namespace)
1. [Demo 10: Use ServiceTemplate in separate Namespace](#demo-10-use-servicetemplate-in-separate-namespace)
1. [Cleaning up](#cleaning-up)

## Setup

### Prerequisites

Tools needed to run this demo are
- Docker
- Git
- make

If you're unsure about whether your system is supported and whether all tools are installed correctly, we provide a script that helps you answer this questions.
Follow these steps to download and run the script to check your setup.

1. Ensure you have a Bash-compatible shell (Linux, macOS).
1. Download the Script:
   You can download the script directly [here](https://raw.githubusercontent.com/Mirantis/k0rdent-demos/refs/heads/main/scripts/check-prerequisites.sh) or via `curl`.
   For example, to download the script using `curl`, run the following command in your terminal:

   ```shell
   curl -o check-prerequisites.sh https://raw.githubusercontent.com/Mirantis/k0rdent-demos/refs/heads/main/scripts/check-prerequisites.sh
   ```
1. Make it executable
   ```shell
   chmod +x check-prerequisites.sh
   ```
1. Run the script
   ```shell
   ./check-prerequisites.sh
   ```

The Setup part for Demos is assumed to be created once before an actual demo is given.

To get the full list of commands run `make help`.

### General Setup

> Expected completion time ~10 min

1. Create a k0rdent Management cluster with kind:
    ```shell
    make bootstrap-kind-cluster
    ```
    You could give it another name by specifying the `KIND_CLUSTER_NAME` environment variable. 
    
    For detailed explanation, please refer to the [documentation](./documentation/1-general-setup-bootstrap-kind-cluster.md).

    > N.B. You can skip this step if you wish to deploy to an existing cluster. Just make sure the relevant kubeconfig is already set, e.g. by exporting it as an environment variable.

2. Install k0rdent into kind cluster:
    ```shell
    make deploy-k0rdent
    ```
    The Demos in this repo require at least k0rdent v0.0.7 or newer. You can change the version by specifying the `KCM_VERSION` environment variable. List of releases can be found [here](https://github.com/K0rdent/kcm/releases).

3. Monitor the installation of k0rdent:
    ```shell
    make watch-k0rdent-deployment
    ```
    In this command we track the `Management` object that is created by k0rdent. Don't worry if you get message that the object is not found, it can take some time.
    Wait until the output of the command be as follows to make sure that k0rdent project is fully installed:
    ```
    Status of the k0rdent components installation: 
    capi: true
    cluster-api-provider-aws: true
    cluster-api-provider-azure: true
    cluster-api-provider-openstack: true
    cluster-api-provider-vsphere: true
    k0smotron: true
    kcm: true
    projectsveltos: true
    ```
    For detailed explanation, please refer to the [documentation](./documentation/2-general-setup-deploy-k0rdent.md).

4. Install the Demo Helm Repo into k0rdent:
    ```shell
    make apply-helmrepo
    ```
    This step deploys simple local OCI Helm registry and adds a [`HelmRepository` resource](https://fluxcd.io/flux/components/source/helmrepositories/) to the cluster that contains Helm charts for this demo.

    For detailed explanation, please refer to the [documentation](./documentation/3-general-setup-helmrepo-setup.md).

5. Push Helm charts with custom Cluster and Service Templates
    ```
    make push-helm-charts
    ```

6. **Important!** If you are going to run demos in corporate or shared cloud accounts, and it is possible that someone else is running the same demos, you may end up in a situation where cloud resources with the same name already exist and you will get errors when deploying clusters. To avoid this, you can set an environment variable with your username. It can be any value though but it's required to be unique:
    ```
    export USERNAME=<your_username>
    ```


### Infra Setup

As next you need to decide into which infrastructure you would like to install the Demo clusters. This Demo Repo has support for the following Infra Providers (more to follow in the future):

- AWS
- Azure
- OpenStack

#### AWS Setup

> Expected completion time ~2 min

This assumes that you already have configured the required [AWS IAM Roles](https://k0rdent.github.io/docs/quick-start/aws/#configure-aws-iam) and have an [AWS account with the required permissions](https://k0rdent.github.io/docs/quick-start/aws/#step-1-create-aws-iam-user). If not follow the k0rdent documentation steps for them.

1. Export AWS Keys as environment variables:
    ```shell
    export AWS_ACCESS_KEY_ID="AWS Access Key ID"
    export AWS_SECRET_ACCESS_KEY="AWS Secret Access Key"
    ````
2. If you use SSO authentication in AWS, export session token:
    ```shell
    export AWS_SESSION_TOKEN="AWS Session Token"
    ```
2. By default, it will provision all resources in the `us-west-2` AWS region. If you want to change this, export `AWS_REGION` environment variable:
    ```shell
    export AWS_REGION="us-east-1"
    ```

3. Install Credentials into k0rdent:
    ```shell
    make apply-aws-creds
    ```

4. Check that credentials are ready to use
    ```shell
    make get-creds-aws
    ```
    The output should be similar to:
    ```
    NAME                        READY   DESCRIPTION
    aws-cluster-identity-cred   true    Basic AWS credentials
    ```

#### Azure Setup

**Currently demos don't have Azure cluster deployments, so you can skip this section**

> Expected completion time ~2 min

This assumes that you already have configured the required [Azure providers](https://k0rdent.github.io/docs/quick-start/azure/#register-resource-providers) and created a [Azure Service Principal](https://k0rdent.github.io/docs/quick-start/azure/#step-2-create-a-service-principal-sp).

1. Export Azure Service Principal keys as environment variables:
    ```
    export AZURE_SP_PASSWORD=<Service Principal password>
    export AZURE_SP_APP_ID=<Service Principal App ID>
    export AZURE_SP_TENANT_ID=<Service Principal Tenant ID>
    export AZURE_SUBSCRIPTION_ID=<Azure's subscription ID>
    ```

2. Install Credentials into k0rdent:
    ```
    make apply-azure-creds
    ```

3. Check that credentials are ready to use
    ```shell
    make get-creds-azure
    ```
    The output should be similar to:
    ```
    NAME                          READY   DESCRIPTION
    azure-cluster-identity-cred   true    Azure credentials
    ```

#### OpenStack Setup

> Expected completion time ~2 min

This assumes that you already have configured an Application Credential in OpenStack, the flavor "m1.medium" exists, and an image called "ubuntu-22.04" is present.

1. Export Application Credential as environment variables:
    ```shell
    export OS_APPLICATION_CREDENTIAL_ID="OpenStack application credential key"
    export OS_APPLICATION_CREDENTIAL_SECRET="OpenStack application credential secret"
    export OS_AUTH_URL="OpenStack auth url"
    ````
2. Install Credentials into k0rdent:
    ```shell
    make apply-openstack-creds
    ```

3. Check that credentials are ready to use
    ```shell
    make get-creds-openstack
    ```
    The output should be similar to:
    ```
    NAME                              READY   DESCRIPTION
    openstack-cluster-identity-cred   true    OpenStack credentials
    ```

### Demo Cluster Setup

**Skip this step if you just want to run demos for your own**

If your plan is to demo an upgrade (Demo 2) or anything related to ServiceTemplates (Demo 3 & 4) right after Demo 1, it is recommended to create a test cluster before the actual demo starts. The reason for this is that creation of a cluster takes around 10-15 mins and could cause a long waiting time during the demo. If you already have a second cluster you can show the creation of a cluster (Demo 1) and then use the existing cluster to show the other demos.


1. Install templates and create aws-test1 cluster
    ```shell
    make apply-clustertemplate-demo-aws-standalone-cp-0.0.1
    make apply-cluster-deployment-aws-test1-0.0.1
    make watch-aws-test1
    ```
2. Wait when the cluster deployment be in Ready state:
    ```
    NAME                   READY   STATUS
    k0rdent-aws-test1      True    ClusterDeployment is ready
    ```

### Blue Namespace & Platform Engineer Credentials

> Expected completion time ~2 min

If you plan to run the [`Demo 5`](#demo-5-approve-clustertemplate--infracredentials-for-separate-namespace) or above we need a secondary namespace (we call it `blue` in this demo) and credentials for a Platform Engineer that does only have access to the blue namespace and not cluster admin.

1. Create target namespace blue and required rolebindings
    ```shell
    make create-target-namespace-rolebindings
    ```

2. Generate Kubeconfig for platform engineer
    ```shell
    make generate-platform-engineer1-kubeconfig
    ```

3. Test Kubeconfig
    ```shell
    KUBECONFIG="certs/platform-engineer1/kubeconfig.yaml" PATH=$PATH:./bin kubectl get ns blue
    ```

## Demo 1: Standalone Cluster Deployment

> Expected completion time ~10-15 min

This demo shows how a simple standalone cluster from a custom ClusterTemplate can be created in the `k0rdent` namespace. It does not require any additional users in k8s or namespaces to be installed.

In the real world this would most probably be done by a Platform Team Lead that has admin access to the Management Cluster in order to create a test cluster from a new ClusterTemplate without the expectation for this cluster to exist for a long time.


1. Install ClusterTemplate in k0rdent
    ```shell
    make apply-clustertemplate-demo-aws-standalone-cp-0.0.1
    ```
    This will install the custom [ClusterTemplate and ClusterTemplateChain](./templates/cluster/demo-aws-standalone-cp-0.0.1.yaml) `demo-aws-standalone-cp-0.0.1`. ClusterTemplate refers to the [Helm chart](./templates/cluster/demo-aws-standalone-cp-0.0.1/) `demo-aws-standalone-cp` of version `0.0.1` which was published to the local Helm repository on the Infra Setup steps.

    You can find this new ClusterTemplate in the list of template with the command:
    ```shell
    PATH=$PATH:./bin kubectl -n k0rdent get clustertemplates
    ```

    Example of the output:
    ```
    NAME                           VALID
    ...
    demo-aws-standalone-cp-0.0.1   true
    ...
    ```

    > Hint: To make an even simpler Demo, this step could be done before the actual demo starts.

    As assumed by k0rdent all ClusterTemplates will be installed first into the `k0rdent` Namespace and can there be used directly to create a new cluster deployments.

2. Install Test Clusters:
    ```shell
    make apply-cluster-deployment-aws-test1-0.0.1
    make apply-cluster-deployment-aws-test2-0.0.1
    ```
    This will create 2 objects of type `ClusterDeployment` with very simple defaults from the ClusterTemplate `demo-aws-standalone-cp-0.0.1`.
    The yaml for this can be found under [`clusterDeployments/aws/0.0.1.yaml`](./clusterDeployments/aws/0.0.1.yaml) and could be modified if needed.
    The Make command also shows the actual yaml that is created for an easier demo experience.

3. Monitor the deployment of each cluster and wait when both be in Ready state:
    For the first cluster:
    ```shell
    make watch-aws-test1
    ```

    Example of the output of fully deployed first cluster:
    ```
    NAME                READY   STATUS
    k0rdent-aws-test1   True    ClusterDeployment is ready
    ```

    For the seocnd cluster:
    ```shell
    make watch-aws-test2
    ```
    
    Example of the output of fully deployed second cluster:
    ```
    NAME                READY   STATUS
    k0rdent-aws-test2   True    ClusterDeployment is ready
    ```

4. Create Kubeconfig for Clusters:
    ```shell
    make get-kubeconfig-aws-test1
    make get-kubeconfig-aws-test2
    ```
    This will put kubeconfigs for a cluster admin under the folder `kubeconfigs` for both created clusters


5. Access Clusters through kubectl
    ```shell
    KUBECONFIG="kubeconfigs/k0rdent-aws-test1.kubeconfig" PATH=$PATH:./bin kubectl get node
    ```

    Example output (username suffix will be present only if you specified the `USERNAME` variable at the [`General Setup`](#general-setup) step):
    ```
    NAME                               STATUS   ROLES           AGE   VERSION
    k0rdent-aws-test1-<username>-cp-0             Ready    control-plane   19m   v1.31.2+k0s
    k0rdent-aws-test1-<username>-md-j87z9-fljb4   Ready    <none>          17m   v1.31.2+k0s
    k0rdent-aws-test1-<username>-md-j87z9-r85gs   Ready    <none>          17m   v1.31.2+k0s
    ```

    ```shell
    KUBECONFIG="kubeconfigs/k0rdent-aws-test2.kubeconfig" PATH=$PATH:./bin kubectl get node
    ```

    Example output (username suffix will be present only if you specified the `USERNAME` variable at the [`General Setup`](#general-setup) step):
    ```
    NAME                               STATUS   ROLES           AGE   VERSION
    k0rdent-aws-test2-<username>-cp-0             Ready    control-plane   19m   v1.31.2+k0s
    k0rdent-aws-test2-<username>-md-j87z9-fljb4   Ready    <none>          17m   v1.31.2+k0s
    k0rdent-aws-test2-<username>-md-j87z9-r85gs   Ready    <none>          17m   v1.31.2+k0s
    ```

## Demo 2: Single Standalone Cluster Upgrade

> Expected completion time ~10 min

> Note: Currently not working correctly for OpenStack.

This demo shows how to upgrade an existing cluster through the cluster template system. This expects [Demo 1](#demo-1-standalone-cluster-deployment) to be completed or the `aws-test1` cluster already created during the [Demo Setup](#demo-cluster-setup).

This demo will upgrade the k8s cluster from `v1.31.2+k0s.0` (which is part of the `demo-aws-standalone-cp-0.0.1` template) to `v1.31.3+k0s.0` (which is part of `demo-aws-standalone-cp-0.0.2`)

1. Install ClusterTemplate Upgrade
    ```shell
    make apply-clustertemplate-demo-aws-standalone-cp-0.0.2
    ```
    This will actually not only install a [ClusterTemplate but also a ClusterTemplateChain](./templates/cluster/demo-aws-standalone-cp-0.0.2.yaml). This ClusterTemplateChain will tell k0rdent that the `demo-aws-standalone-cp-0.0.2` is an upgrade from `demo-aws-standalone-cp-0.0.1`.

    You can find this new ClusterTemplate in the list of template with the command:
    ```shell
    PATH=$PATH:./bin kubectl -n k0rdent get clustertemplates
    ```

    Example of the output:
    ```
    NAME                           VALID
    ...
    demo-aws-standalone-cp-0.0.1   true
    demo-aws-standalone-cp-0.0.2   true <-- this is the new template
    ...
    ```

2. The fact that we have an upgrade available will be reported by k0rdent. You can find all available upgrades for all cluster deployments by executing this command:

    ```shell
    make get-available-upgrades-k0rdent
    ```

    Example output (username suffix will be present only if you specified the `USERNAME` variable at the [`General Setup`](#general-setup) step):
    ```
    Cluster k0rdent-aws-test1-<username> available upgrades: 
      - demo-aws-standalone-cp-0.0.2

    Cluster k0rdent-aws-test2-<username> available upgrades: 
      - demo-aws-standalone-cp-0.0.2
    ```

3. Apply Upgrade of the cluster:
    ```shell
    make apply-cluster-deployment-aws-test1-0.0.2
    ```

4. Monitor the rollout of the upgrade

    You can watch how new machines are created and old machines are deleted:
    ```shell
    PATH=$PATH:./bin kubectl -n k0rdent get machines -w
    ```

    You will see how for cluster `test1` the k0s control plane node version is upgraded to the new one, then one by one new worker nodes should be provisioned and put into `Running` state, and old nodes should be removed.

    > Hint: control plane nodes for k0s clusters are being upgraded in place (check the version field) without provisioning new machines.

    Or how in the created cluster old nodes are drained and new nodes are attached:
    ```shell
    KUBECONFIG="kubeconfigs/k0rdent-aws-test1.kubeconfig" PATH=$PATH:./bin kubectl get node -w
    ```

## Demo 3: Install ServiceTemplate into single Cluster

> Expected completion time ~5 min

This demo shows how a ServiceTemplate can be installed in a Cluster.

In order to run this demo you need [`Demo 1`](#demo-1-standalone-cluster-deployment) completed, which created the `test2` cluster.

1. Install ServiceTemplate in k0rdent:
    ```shell
    make apply-servicetemplate-demo-ingress-nginx-4.11.0
    ```

    This installs the custom [ServiceTemplate and ServiceTemplateChain](./templates/service/demo-ingress-nginx-4.11.0.yaml) `demo-ingress-nginx-4.11.0`. ServiceTemplate refers to the [Helm chart](./templates/service/demo-ingress-nginx-4.11.0/) `demo-ingress-nginx` of version `4.11.0` which was published to the local Helm repository on the Infra Setup steps.

    You can find this new ServiceTemplate in the list of template with the command:
    ```shell
    PATH=$PATH:./bin kubectl -n k0rdent get servicetemplates
    ```

    Example of the output:
    ```
    NAME                        VALID
    ...
    demo-ingress-nginx-4.11.0   true <-- this is the installed template
    ...
    ```

2. Apply ServiceTemplate to cluster:
    ```shell
    make apply-cluster-deployment-aws-test2-ingress
    ```
    This applies the [0.0.1-ingress.yaml](clusterDeployments/aws/0.0.1-ingress.yaml) yaml template. For simplicity the yamls are a full `ClusterDeployment` Object and not just a diff from the original cluster. The command output will show you a diff that explains that the only thing that actually has changed is the `spec.serviceSpec.services` key that contains now the reference to the previously created ServiceTemplate `demo-ingress-nginx-4.11.0`


3. Monitor how the ingress-nginx is installed in `test2` cluster:
    ```shell
    watch KUBECONFIG="kubeconfigs/k0rdent-aws-test2.kubeconfig" PATH=$PATH:./bin kubectl get pods -n ingress-nginx
    ```

    The final state should be similar to:
    ```
    NAME                                        READY   STATUS    RESTARTS   AGE
    ingress-nginx-controller-86bd747cf9-ds56s   1/1     Running   0          34s
    ```

    You can also check the services status of the `ClusterDeployment` of object in our management cluster:

    ```shell
    make get-yaml-clusterdeployment-aws-test2
    ```

    The output under the `status.services` should contain information about successfully deployed ingress nginx service (username suffix will be present only if you specified the `USERNAME` variable at the [`General Setup`](#general-setup) step):

    ```
    ...
    status:
      ...
      services:
      - clusterName: k0rdent-aws-test2-<username>
        clusterNamespace: k0rdent
        conditions:
        ...
        - lastTransitionTime: "2024-12-19T17:24:35Z"
          message: Release ingress-nginx/ingress-nginx
          reason: Managing
          status: "True"
          type: ingress-nginx.ingress-nginx/SveltosHelmReleaseReady
    ```

## Demo 4: Install ServiceTemplate into multiple clusters

> Expected completion time ~5 min

> Note: Currently not working correctly for OpenStack.

This Demo shows the capability of k0rdent to install a ServiceTemplate into multiple Clusters without the need to reference it in every cluster as we did in `Demo 3`.

While this demo can be shown even if you only have a single cluster, its obviously better to be demoed with two clusters. If you followed along the demo process you should have two clusters.

Be aware though that the cluster creation takes around 10-15mins, so depending on how fast you give the demo, the cluster creation might not be completed and the installation of services possible also delayed. You can totally follow this demo and the services will be installed after the clusters are ready.

1. Install Kyverno ServiceTemplate in k0rdent:
    ```shell
    make apply-servicetemplate-demo-kyverno-3.2.6
    ```
    This will install a new [ServiceTemplate](./templates/service/demo-kyverno-3.2.6.yaml) which deploys a standard installation of kyverno in a cluster.

    You can find this new ServiceTemplate in the list of template with the command:
    ```shell
    PATH=$PATH:./bin kubectl -n k0rdent get servicetemplates
    ```

    Example of the output:
    ```
    NAME                        VALID
    ...
    demo-ingress-nginx-4.11.0   true 
    demo-kyverno-3.2.6          true <-- this is the installed template
    ...
    ```

2. Apply MultiClusterService to cluster:
    ```shell
    make apply-multiclusterservice-global-kyverno
    ```

    This will install a `MultiClusterService.k0rdent.mirantis.com` cluster-wide object to the management cluster. It has a clusterSelector configuration of the label `k0rdent: demo` which selects all `Cluster.cluster.x-k8s.io` objects with this label. Please, don't confuse `ClusterDeployment.k0rdent.mirantis.com` and `Cluster.cluster.x-k8s.io` types. The first one is the type of Project k0rdent objects, we deploy them to the management cluster and then, the kcm operator creates various objects, including the CAPI `Cluster.cluster.x-k8s.io`. `MultiClusterService.k0rdent.mirantis.com` relies on `Cluster.cluster.x-k8s.io` labels. To set labels on related `Cluster.cluster.x-k8s.io` objects we have the appropriate property in the `ClusterDeployment.k0rdent.mirantis.com` - `spec.config.clusterLabels`. And if you check ClusterDeployment templates that we use in these demos for deployments, you can find that all of them has the following value for this property:
    ```
    ...
    clusterLabels:
      k0rdent: demo
    ...
    ```
    
    And if we check created `Cluster.cluster.x-k8s.io` objects, we can find that all of them have this label:
    ```shell
    PATH=$PATH:./bin kubectl -n k0rdent get clusters -L k0rdent
    ```

    The output should be similar to (username suffix will be present only if you specified the `USERNAME` variable at the [`General Setup`](#general-setup) step):
    ```
    PATH=$PATH:./bin kubectl -n k0rdent get clusters -L k0rdent
    NAME                           CLUSTERCLASS   PHASE         AGE   VERSION   K0RDENT
    k0rdent-aws-test1-<username>                  Provisioned   79m             demo
    k0rdent-aws-test2-<username>                  Provisioned   31m             demo
    ```

    And this means that the `MultiClusterService.k0rdent.mirantis.com` global-kyverno that we deployed at the start of this step should be deployed to both clusters

3. Monitor how the kyverno service is being installed in both clusters that we deployed previously:
    ```shell
    watch KUBECONFIG="kubeconfigs/k0rdent-aws-test1.kubeconfig" PATH=$PATH:./bin kubectl get pods -n kyverno
    ```

    ```shell
    watch KUBECONFIG="kubeconfigs/k0rdent-aws-test2.kubeconfig" PATH=$PATH:./bin kubectl get pods -n kyverno
    ```

    There might be a couple of seconds delay before that k0rdent and sveltos needs to start the installation of kyverno, give it at least 1 mins.

    The final state for each cluster should be similar to:
    ```
    NAME                                             READY   STATUS    RESTARTS   AGE
    kyverno-admission-controller-96c5d48b4-rqpdz     1/1     Running   0          47s
    kyverno-background-controller-65f9fd5859-qfwqc   1/1     Running   0          47s
    kyverno-cleanup-controller-848b4c579d-fc8s4      1/1     Running   0          47s
    kyverno-reports-controller-6f59fb8cd6-9j4f7      1/1     Running   0          47s
    ```    

4. You can also check the deployment status for all clusters in the `MultiClusterService` object:
    ```shell
    make get-yaml-milticlasterservice-global-kyverno
    ```

    In the output you can find information about clusters where the service is deployed (username suffix will be present only if you specified the `USERNAME` variable at the [`General Setup`](#general-setup) step):
    ```
    apiVersion: k0rdent.mirantis.com/v1alpha1
    kind: MultiClusterService
    ...
    status:
      ...
      services:
        - clusterName: k0rdent-aws-test1-<username>
          clusterNamespace: k0rdent
          conditions:
          - lastTransitionTime: "2025-01-03T14:12:33Z"
            message: ""
            reason: Provisioned
            status: "True"
            type: Helm
          - lastTransitionTime: "2025-01-03T14:12:33Z"
            message: Release kyverno/kyverno
            reason: Managing
            status: "True"
            type: kyverno.kyverno/SveltosHelmReleaseReady
        - clusterName: k0rdent-aws-test2-<username>
          clusterNamespace: k0rdent
          conditions:
          - lastTransitionTime: "2025-01-03T14:12:33Z"
            message: ""
            reason: Provisioned
            status: "True"
            type: Helm
          - lastTransitionTime: "2025-01-03T14:12:33Z"
            message: Release kyverno/kyverno
            reason: Managing
            status: "True"
            type: kyverno.kyverno/SveltosHelmReleaseReady
    ```

## Demo 5: Approve ClusterTemplate & InfraCredentials for separate Namespace

> Expected completion time ~2 min

1. Approve the clustertemplate into the blue namespace
    ```shell
    make approve-clustertemplatechain-aws-standalone-cp-0.0.1
    ```

    Check the status of the AccessManagement object:
    ```shell
    make get-yaml-accessmanagement
    ```

    In the status section you can find information about the clustertemplate that was approved to the target `blue` namespace:
    ```
    apiVersion: k0rdent.mirantis.com/v1alpha1
    kind: AccessManagement
    ...
    status:
      ...
      current:
      - clusterTemplateChains:
        - demo-aws-standalone-cp-0.0.1
        targetNamespaces:
          list:
          - blue
    ```

2. Approve the AWS credentials into the blue namspace
    ```shell
    make approve-credential-aws
    ```

    Check the status of the `kcm` AccessManagement object:
    ```shell
    make get-yaml-accessmanagement
    ```

    In the status section you can find information about the clustertemplate that was approved to the target `blue` namespace:
    ```
    apiVersion: k0rdent.mirantis.com/v1alpha1
    kind: AccessManagement
    ...
    status:
      ...
      current:
      - credentials:
        - aws-cluster-identity-cred
        targetNamespaces:
          list:
          - blue
    ```

3. Show that the platform engineer only can see approved clustertemplate and credentials and no other ones:
    ```shell
    KUBECONFIG="certs/platform-engineer1/kubeconfig.yaml" PATH=$PATH:./bin kubectl get credentials,clustertemplates -n blue
    ```

    Output:
    ```
    NAME                                                    READY   DESCRIPTION
    credential.k0rdent.mirantis.com/aws-cluster-identity-cred   true    AWS credentials

    NAME                                                            VALID
    clustertemplate.k0rdent.mirantis.com/demo-aws-standalone-cp-0.0.1   true
    ```

## Demo 6: Use approved ClusterTemplate in separate Namespace

> Expected completion time ~10-15 min

> Note: Currently not working correctly for OpenStack.

1. Create Cluster in blue namespace (this will be ran as platform engineer)
    ```shell
    make apply-cluster-deployment-aws-dev1-0.0.1
    ```
    This will create the object of type `ClusterDeployment`, same as in [`Demo 1`](#demo-1-standalone-cluster-deployment) but in the `blue` namespace and using the approved and delivered `ClusterTemplate` to that namespace.

3. Monitor the deployment of the cluster and wait when it be in Ready state:
    For the first cluster:
    ```shell
    make watch-aws-dev1
    ```

    Example of the output of fully deployed first cluster(username suffix will be present only if you specified the `USERNAME` variable at the [`General Setup`](#general-setup) step):
    ```
    NAME            READY   STATUS
    blue-aws-dev1-<username>   True    ClusterDeployment is ready
    ```


2. Get Kubeconfig for `aws-dev1`
    ```shell
    make get-kubeconfig-aws-dev1
    ```

3. Access cluster
    ```shell
    KUBECONFIG="kubeconfigs/blue-aws-dev1.kubeconfig" kubectl get node
    ```

    Example output (username suffix will be present only if you specified the `USERNAME` variable at the [`General Setup`](#general-setup) step):
    ```
    NAME                           STATUS   ROLES           AGE    VERSION
    blue-aws-dev1-<username>-cp-0             Ready    control-plane   10m    v1.31.2+k0s
    blue-aws-dev1-<username>-md-kxgdb-bgmhw   Ready    <none>          2m4s   v1.31.2+k0s
    blue-aws-dev1-<username>-md-kxgdb-jkcpc   Ready    <none>          2m5s   v1.31.2+k0s
    ```

## Demo 7: Test new ClusterTemplate as k0rdent Admin, then approve them in separate Namespace

> Expected completion time ~5-15 min, depending on what previous demos were completed

As demonstrated in [Demo 5](#demo-5-approve-clustertemplate--infracredentials-for-separate-namespace) and [Demo 6](#demo-6-use-approved-clustertemplate-in-separate-namespace), one of the important features of k0rdent project is the possibility to manage ClusterTemplate and ServiceTemplate development process, testing and access. Users responsible for developing and testing infrastructure (we call them k0rdent Admin in these demos) can easily do this in one namespace (`k0rdent`) of the management cluster without worrying that other users have access to cluster and service configurations that are not yet properly tested. As soon as some templates are ready to use, they are approved by k0rdent Admin to separate namespaces (`blue`) and can be used by users that responsible for bootstrapping and maintaing the infrastructure (we call them `Platform Engineer` in these demos).

This demo assumes that you completed: 
- [Demo 5](#demo-5-approve-clustertemplate--infracredentials-for-separate-namespace) and [Demo 6](#demo-6-use-approved-clustertemplate-in-separate-namespace) and have the fully deployed `dev1` cluster in the `blue` namespace
- [Demo 1](#demo-1-standalone-cluster-deployment) or [Demo Cluster Setup](#demo-cluster-setup) and have the fully deployed `test1` cluster in the `k0rdent` namespace

At this point we have the `demo-aws-standalone-cp-0.0.1` ClusterTemplate and provisoned clusters from this template in both `k0rdent` and `blue` namespaces. Let's say that k0rdent Admin has a request to upgrade clusters. 


1. Complete the [Demo 2](#demo-2-single-standalone-cluster-upgrade) and make sure that the cluster `test1` in the `k0rdent` namespace is fully upgraded.

    If you have done this - it's completely fine, you already familiar with the cluster upgrade process.
    
    Now we, as k0rdent Admins developed a new ClusterTemplate `demo-aws-standalone-cp-0.0.2` with the cluster upgrade, tested it by upgrading `test1` cluster in the `k0rdent` namespace, but `Platform Engineer` users still doesn't see new `ClusterTemplate` and can't use them.

2. Check as `Platform Engineer` the list of available Cluster Templates in the `blue` namespace:
    ```shell
    KUBECONFIG="certs/platform-engineer1/kubeconfig.yaml" PATH=$PATH:./bin kubectl get clustertemplates -n blue
    ```

    The output should be:
    ```
    NAME                           VALID
    demo-aws-standalone-cp-0.0.1   true
    ```

    As you can see, we don't have the `demo-aws-standalone-cp-0.0.2` cluster template in the `blue` namespace. And, due to the access to the `k0rdent` namespace is restricted for `Platform Engineer` user, it's not possible to check what not released templates exist:
    ```shell
    KUBECONFIG="certs/platform-engineer1/kubeconfig.yaml" PATH=$PATH:./bin kubectl get clustertemplates -n k0rdent
    ```

    The output should be:
    ```
    Error from server (Forbidden): clustertemplates.k0rdent.mirantis.com is forbidden: User "platform-engineer1" cannot list resource "clustertemplates" in API group "k0rdent.mirantis.com" in the namespace "k0rdent"
    ```

    And also we check that the list of available upgrades for the cluster `dev1` in the `blue` namespace is empty:
    ```shell
    make get-available-upgrades-blue
    ```

    The output should be (username suffix will be present only if you specified the `USERNAME` variable at the [`General Setup`](#general-setup) step):
    ```
    Cluster blue-aws-dev1-<username> available upgrades: 

    ```

3. But, let's imagine that `Platform Engineer` somehow learned about the existence of a new `demo-aws-standalone-cp-0.0.2` template and decided to upgrade the cluster in the `blue` namespace:
    ```shell
    make apply-cluster-deployment-aws-dev1-0.0.2
    ```

    The output should contain this line:
    ```
    Error from server (NotFound): admission webhook "validation.clusterdeployment.k0rdent.mirantis.com" denied the request: ClusterTemplate.k0rdent.mirantis.com "demo-aws-standalone-cp-0.0.2" not found
    ```

    It says that cluster template with the name `demo-aws-standalone-cp-0.0.2` is not found in the `blue` namespace.

4. Now, when the `demo-aws-standalone-cp-0.0.2` ClusterTemplate is fully tested and ready to be released, we, as k0rdent admins, approve the ClusterTemplateChain for this template to the `blue` namespace:
    ```shell
    make approve-clustertemplatechain-aws-standalone-cp-0.0.2
    ```

    Check the status of the `kcm` AccessManagement object:
    ```shell
    make get-yaml-accessmanagement
    ```

    In the status section you can find information about the `demo-aws-standalone-cp-0.0.2` ClustertemplateChain that was approved to the target `blue` namespace:
    ```
    apiVersion: k0rdent.mirantis.com/v1alpha1
    kind: AccessManagement
    ...
    status:
      ...
      current:
      - clusterTemplateChains:
        - demo-aws-standalone-cp-0.0.1
        - demo-aws-standalone-cp-0.0.2
        ...
        targetNamespaces:
          list:
          - blue
    ```

3. Show that the platform engineer now can see approved `demo-aws-standalone-cp-0.0.2` ClusterTemplate in the `blue` namespace:
    ```shell
    KUBECONFIG="certs/platform-engineer1/kubeconfig.yaml" PATH=$PATH:./bin kubectl get clustertemplates -n blue
    ```

    Output:
    ```
    NAME                           VALID
    demo-aws-standalone-cp-0.0.1   true
    demo-aws-standalone-cp-0.0.2   true
    ```

## Demo 8: Use newly approved ClusterTemplate in separate Namespace

> Expected completion time ~10 min

This demo assumes that you completed the [Demo 7](#demo-7-test-new-clustertemplate-as-k0rdent-admin-then-approve-them-in-separate-namespace) and shows how to upgrade an existing cluster as Platform Engineer using the tested and approved ClusterTemplate.

It will upgrade the k8s cluster from `v1.31.2+k0s.0` (which is part of the `demo-aws-standalone-cp-0.0.1` template) to `v1.31.3+k0s.0` (which is part of `demo-aws-standalone-cp-0.0.2`)

1. In [Demo 7](#demo-7-test-new-clustertemplate-as-k0rdent-admin-then-approve-them-in-separate-namespace) we approved released ClusterTemplate `demo-aws-standalone-cp-0.0.2` to the `blue` namespace and the fact that cluster `dev1` has upgrade available will be reported by k0rdent. You can find all available upgrades for all cluster deployments by executing this command:

    ```shell
    make get-available-upgrades-blue
    ```

    Example output (username suffix will be present only if you specified the `USERNAME` variable at the [`General Setup`](#general-setup) step):
    ```
    Cluster blue-aws-dev1-<username> available upgrades: 
      - demo-aws-standalone-cp-0.0.2
    ```

3. Apply Upgrade of the cluster:
    ```shell
    make apply-cluster-deployment-aws-dev1-0.0.2
    ```

4. Monitor the rollout of the upgrade

    You can watch how new machines are created and old machines are deleted:
    ```shell
    KUBECONFIG="certs/platform-engineer1/kubeconfig.yaml" PATH=$PATH:./bin kubectl -n blue get machines -w
    ```

    You will see how for cluster `dev1` the k0s control plane node version is upgraded to the new one, then one by one new worker nodes should be provisioned and put into `Running` state, and old nodes should be removed.

    > Hint: control plane nodes for k0s clusters are being upgraded in place (check the version field) without provisioning new machines.

    Or how in the created cluster old nodes are drained and new nodes are attached:
    ```shell
    KUBECONFIG="kubeconfigs/blue-aws-dev1.kubeconfig" PATH=$PATH:./bin kubectl get node -w
    ```

## Demo 9: Approve ServiceTemplate in separate Namespace

> Expected completion time ~1-2 min

1. Approve the `ServiceTemplate` into the blue namespace
    ```shell
    make approve-servicetemplatechain-ingress-nginx-4.11.0
    ```

    Check the status of the `kcm` AccessManagement object:
    ```shell
    make get-yaml-accessmanagement
    ```

    In the status section you can find information about the `ServiceTemplateChain` that was approved to the target `blue` namespace:
    ```
    apiVersion: k0rdent.mirantis.com/v1alpha1
    kind: AccessManagement
    ...
    status:
      ...
      current:
      - serviceTemplateChains:
        - demo-ingress-nginx-4.11.0
        targetNamespaces:
          list:
          - blue
    ```

2. Show that the platform engineer only can see approved clustertemplate and credentials and no other ones:
    ```shell
    KUBECONFIG="certs/platform-engineer1/kubeconfig.yaml" PATH=$PATH:./bin kubectl get servicetemplates -n blue
    ```

    Output:
    ```
    NAME                        VALID
    demo-ingress-nginx-4.11.0   true
    ```


## Demo 10: Use ServiceTemplate in separate Namespace

> Expected completion time ~5 min

1. Apply ServiceTemplate to the cluster in blue namespace that was created in [Demo 6](#demo-6-use-approved-clustertemplate-in-separate-namespace) (this will be ran as platform engineer):
    ```shell
    make apply-cluster-deployment-aws-dev1-ingress
    ```
    This applies either [0.0.1-ingress.yaml](clusterDeployments/aws/0.0.1-ingress.yaml) or [0.0.2-ingress.yaml](clusterDeployments/aws/0.0.2-ingress.yaml) yaml template, depending on what version of ClusterTemplate is deployed. For simplicity the yamls are a full `ClusterDeployment` Object and not just a diff from the original cluster. The command output will show you a diff that explains that the only thing that actually has changed is the `spec.serviceSpec.services` key


2. Monitor how the ingress-nginx is installed in `dev1` cluster:
    ```shell
    watch KUBECONFIG="kubeconfigs/blue-aws-dev1.kubeconfig" PATH=$PATH:./bin kubectl get pods -n ingress-nginx
    ```

    The final state should be similar to:
    ```
    NAME                                        READY   STATUS    RESTARTS   AGE
    ingress-nginx-controller-86bd747cf9-ds56s   1/1     Running   0          34s
    ```

    You can also check the services status of the `ClusterDeployment` of object in management cluster (this will be ran as platform engineer):

    ```shell
    make get-yaml-clusterdeployment-aws-dev1
    ```

    The output under the `status.services` should contain information about successfully deployed ingress nginx service:

    ```
    ...
    status:
      ...
      services:
      - clusterName: blue-aws-dev1
        clusterNamespace: blue
        conditions:
        ...
        - lastTransitionTime: "2024-12-19T17:24:35Z"
          message: Release ingress-nginx/ingress-nginx
          reason: Managing
          status: "True"
          type: ingress-nginx.ingress-nginx/SveltosHelmReleaseReady
    ```

3. If you completed [Demo 4](#demo-4-install-servicetemplate-into-multiple-cluster) and deployed `MultiClusterService` kyverno , you may also find the service was deployed to the new cluster, even the `ClusterDeployment` object is located in different namespace than clusters we deployed in Demo 4. This is because `MultiClusterService` is the cluster-scope object and new cluster in the `blue` namespace has labels that meet the requirements in `MultiClusterService` object.

    Get the state of `kyverno` service in `dev1` cluster:
    ```shell
    watch KUBECONFIG="kubeconfigs/blue-aws-dev1.kubeconfig" kubectl get pods -n kyverno
    ```
    
    It should show the state similar to:
    ```
    NAME                                             READY   STATUS    RESTARTS   AGE
    kyverno-admission-controller-96c5d48b4-rqpdz     1/1     Running   0          47s
    kyverno-background-controller-65f9fd5859-qfwqc   1/1     Running   0          47s
    kyverno-cleanup-controller-848b4c579d-fc8s4      1/1     Running   0          47s
    kyverno-reports-controller-6f59fb8cd6-9j4f7      1/1     Running   0          47s
    ```    

    You can also find that the new `ClusterDeployment` from the `blue` namespace appears in the `MultiClusterService` object status:
    ```shell
    make get-yaml-milticlasterservice-global-kyverno
    ```

    In the output you can find information about clusters where the service is deployed:
    ```
    apiVersion: k0rdent.mirantis.com/v1alpha1
    kind: MultiClusterService
    ...
    status:
      ...
      services:
        ...
        - clusterName: blue-aws-dev1
          clusterNamespace: blue
          conditions:
          - lastTransitionTime: "2025-01-08T11:31:34Z"
            message: ""
            reason: Provisioned
            status: "True"
            type: Helm
          - lastTransitionTime: "2025-01-08T11:31:34Z"
            message: Release kyverno/kyverno
            reason: Managing
            status: "True"
            type: kyverno.kyverno/SveltosHelmReleaseReady
    ```

## Cleaning up

As running the whole k0rdent setup can be quite taxing on your hardware, run the following command to clean up everything (both the public cloud resources mentioned above but also all local containers):
```shell
make cleanup
```

To reset management cluster and cleanup only `ClusterDeployment` objects you can run the command:
```shell
make cleanup-clusters
```
