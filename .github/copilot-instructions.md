<!-- Test generation comments -->

<!-- Code Review comments -->

<!-- Cmmit message generation comments -->
This repository deploys a GraphRAG infrastructure to Azure.
This deployment includes a collection of Azure services.
This application is deployed using the latest security measures. Any suggestions must keep security guidelines as top of mind and not break any existing security parameters.

The docs folder contains additional information about the project including how this repository is used to deploy the infrastructure.
The backend folder provides the code for the API container. This API is how applications will interact with the environment.
The frontend folder provides a container that can run locally or be deployed in azure. It is the user interface to perform the graphrag functions.
The infra structure is the current focus of the enhancements to this project.
    Specifically, we need to separate the deployment activities into those that require Owner permissions in Azure from those that can be completed with just Contributor permissions.
    This will be the bulk of conversation related to this repository.
    Only User-Assigned Managed Identities (UAMI) can be used for this deployment. Some portions of the bicep files create UAMI while there are services created with System-Assigned Managed Identities (SAMI).
    As part of this process, there may need to be handoffs between the Owner and Contributor roles to complete the task.