#AnalyticsEngine on Remote Data Plane

To support deploying AnalyticsEngine on a remote data plane, the AnalyticsEngine operator needs to be deployed to the management namespace of the physical location associated with the remote data plane.

## Requirements

- Deploy the physical location and associate it with a [remote data plane](https://www.ibm.com/docs/en/cloud-paks/cp-data/5.0.x?topic=instances-deploying-remote-data-plane)

- Configure the [global pull secret](https://www.ibm.com/docs/en/cloud-paks/cp-data/5.0.x?topic=cluster-updating-global-image-pull-secret)

Note: If using a private registry, an [image content source policy](https://www.ibm.com/docs/en/cloud-paks/cp-data/5.0.x?topic=registry-configuring-image-content-source-policy) will need to be configured. [Image mirroring](https://www.ibm.com/docs/en/cloud-paks/cp-data/5.0.x?topic=registry-mirroring-images-directly-private-container) will also be needed if the DataStage images has not been mirrored to this private registry.

## Deploying the AnalyticsEngine operator

To deploy the operator on your physical location, login to the cluster via `oc` with cluster-admin role and run the command below. The latest operator will be deploy when version is omitted.

```
./deploy_operator.sh --namespace <management-namespace> --digest <just digest value without sha256>
```
`oc get analyticsenginedataplane -n <management-namespace>`

check and wait till analyticsenginedataplane cr to be in `Completed` state.

# Using AnalyticsEngine on a Remote Data Plane
To use a AnalyticsEngine instance on a remote data plane with a project, an instance must be created and all saprk runtimes will be running on that instance. All resources needed to run spark runtimes will be created on the AnalyticsEngine opeartor. As a result, the jobs in this project may not run on other AnalyticsEngine instances.

Create an AnalyticsEngine instance on the remote data plane:
1. On the `Instance details` page of the `New service instance` wizard for AnalyticsEngine, select `Data Plane` instead of `Namespace`
2. Select the data plane with the physical location where the AnalyticsEngine operator has been deployed
