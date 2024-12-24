# AnalyticsEngine
IBM Analytics Engine powered by Apache Spark provides managed service for consuming Apache Spark with additional features such as auto-scaling, resource quota, and queuing. You can run Spark application interactively by using Jupyter Notebooks and Scripts, both Python and R. The applications can also be run by using jobs from Notebook, Deployment space, or by using the Spark service instance. The IBM Analytics Engine powered by Apache Spark creates on-demand Spark clusters and runs workloads using offerings like Spark applications, Spark kernels, and Spark labs.

The IBM Analytics Engine powered by Apache Spark service is not available by default. An administrator must install this service on the IBM Cloud Pak for Data platform. To determine whether the service is installed, open the Services catalog and check whether the service is enabled.

Each time you submit a job, a dedicated Spark cluster is created for the job. You can specify the size of the Spark driver, the size of the executor, and the number of executors for the job. This enables you to achieve predictable and consistent performance.

When a job completes, the cluster is automatically cleaned up so that the resources are available for other jobs. The service also includes interfaces that enable you to analyze the performance of your Spark applications and debug problems.

In IBM Cloud Pak for Data, you can run Spark workloads in two ways:

In a notebook that runs in a Spark environment in a project in Watson Studio
Outside Watson Studio, in an IBM Analytics Engine powered by Apache Spark instance using Spark job APIs
