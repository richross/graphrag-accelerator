# GraphRAG Infrastructure Deployment

## Overview

This folder contains the Bicep templates and supporting files for deploying the GraphRAG infrastructure to Azure. The deployment has been refactored to separate activities that require **Owner** permissions from those that can be completed with **Contributor** permissions, following Azure best practices and least privilege principles.

---

## Step-by-step Solution for Splitting `main.bicep`

1. **Identify Owner vs Contributor Activities**
   - **Owner**: Can create RBAC role assignments, User-Assigned Managed Identities (UAMI), networking (VNet, NSG, Private Endpoints), and assign roles.
   - **Contributor**: Can deploy most resources but cannot assign RBAC roles or create UAMIs.

2. **Create Two Entry Point Bicep Files**
   - `main-owner.bicep`: Deploys all resources requiring Owner permissions (identities, RBAC, networking, etc.).
   - `main-contrib.bicep`: Deploys the rest (AKS, storage, CosmosDB, AI Search, etc.), assuming identities and networking are already present.

3. **Refactor `main.bicep` into Modules**
   - Move resource definitions into smaller modules if not already modularized (your file is already modular).
   - Each main file (`main-owner.bicep`, `main-contrib.bicep`) will orchestrate the relevant modules.

4. **Parameter Passing**
   - `main-contrib.bicep` should take outputs from `main-owner.bicep` as parameters (e.g., identity IDs, subnet IDs).

5. **Minimal Changes to Existing Modules**
   - No changes to module files are needed unless they assume resource creation that should be split.

---

## Deployment Plan

### 1. Split Deployment

- **main-owner.bicep**:
  Deploys all resources and assignments that require Azure Owner permissions, such as:
  - User-Assigned Managed Identities (UAMI)
  - RBAC role assignments
  - Networking (VNet, NSG, Private DNS, etc.)
  - Outputs necessary resource IDs and details to `owner-outputs.json`.

- **main-contrib.bicep**:
  Deploys all other resources that can be created with Contributor permissions, including:
  - AKS, CosmosDB, Storage, AI Search, App Insights, APIM, etc.
  - Uses outputs from `main-owner.bicep` (loaded from `owner-outputs.json`) as parameters (e.g., identity IDs, subnet IDs).

### 2. Handoff Process & Output Management

The deployment is performed in two stages, facilitated by the `deploy.sh` script and a helper Python script `manage_bicep_outputs.py`.

**`manage_bicep_outputs.py` Script:**

This Python script (`/graphrag-accelerator/infra/manage_bicep_outputs.py`) is used to manage the outputs from the owner-level deployment and make them available for the contributor-level deployment.

-   **`save` command**:
    -   Usage: `python3 manage_bicep_outputs.py save "<JSON_OUTPUT_STRING>" <output_file_path>`
    -   Takes the JSON output string from a Bicep deployment and saves it to a specified file.
    -   In the `deploy.sh` script, after the `main-owner.bicep` deployment, this command is used to save the outputs to `owner-outputs.json`.

-   **`load-env` command**:
    -   Usage: `python3 manage_bicep_outputs.py load-env <input_file_path>`
    -   Reads a JSON file (e.g., `owner-outputs.json`) containing Bicep outputs.
    -   Prints shell `export` commands for each output key-value pair. Keys are prefixed with `OWNER_OUTPUT_` and converted to uppercase (e.g., `OWNER_OUTPUT_VNETID`).
    -   In `deploy.sh`, before the `main-contrib.bicep` deployment, `eval $(python3 manage_bicep_outputs.py load-env "owner-outputs.json")` is used to load these outputs as environment variables.

**Deployment Stages:**

1.  **Owner Stage**:
    *   The user with **Owner** permissions runs `deploy.sh` with the `--owner` flag:
        ```bash
        bash deploy.sh --owner -p deploy.parameters.json
        ```
    *   This executes `main-owner.bicep`.
    *   The `deploy.sh` script captures the outputs from `main-owner.bicep` and uses `manage_bicep_outputs.py save` to store them in a file named `owner-outputs.json` in the `infra` directory.
    *   This `owner-outputs.json` file must be securely transferred to the user/system performing the Contributor stage.

2.  **Contributor Stage**:
    *   The user with **Contributor** permissions (or an automated process) runs `deploy.sh` with the `--contrib` flag, ensuring `owner-outputs.json` is present in the `infra` directory:
        ```bash
        bash deploy.sh --contrib -p deploy.parameters.json
        ```
        *(Note: `deploy.parameters.json` for the contributor stage might be the same or a different one, but critical inputs will come from `owner-outputs.json`)*
    *   The `deploy.sh` script uses `manage_bicep_outputs.py load-env` to read `owner-outputs.json` and export its contents as environment variables (e.g., `OWNER_OUTPUT_VNETID`, `OWNER_OUTPUT_AKSSUBNETID`).
    *   These environment variables are then used to pass the required parameters to the `main-contrib.bicep` deployment.
    *   The script then proceeds with deploying contributor-level resources and subsequent application setup (Helm, DNS, APIM API registration).

This two-stage process ensures that operations requiring Owner privileges are segregated and their outputs are systematically passed to the Contributor stage, adhering to the principle of least privilege.

---

## File Descriptions

### main-owner.bicep

- Contains all parameters and variables needed for owner-level resources.
- Deploys networking, managed identities, and RBAC assignments.
- Outputs all necessary resource IDs for use by `main-contrib.bicep`.

### main-contrib.bicep

- Contains all parameters and variables needed for contributor-level resources.
- Accepts resource IDs and identity IDs as parameters (from `main-owner.bicep` outputs).
- Deploys AKS, CosmosDB, Storage, AI Search, App Insights, APIM, and related resources.

---

## deploy.sh Module Responsibility Mapping

To support the split deployment model, the modules and steps in `deploy.sh` can be grouped as follows:

### Owner Responsibilities (main-owner.bicep)
These steps require **Owner** permissions in Azure:

- **User-Assigned Managed Identities (UAMI)**
  - workloadIdentity
  - aksControlPlaneIdentity
  - aksKubeletIdentity
  - aksIngressIdentity
  - cosmosDbIdentity

- **RBAC Role Assignments**
  - aksWorkloadIdentityRBAC
  - aksRBAC

- **Networking**
  - nsg (Network Security Group)
  - vnet (Virtual Network)
  - privateDnsZone (Private DNS Zone)
  - privatelinkPrivateDns (Private DNS Zones for Private Link)

### Contributor Responsibilities (main-contrib.bicep)
These steps require only **Contributor** permissions:

- **Log Analytics Workspace**
  - log

- **Azure OpenAI (AOAI)**
  - aoai

- **Azure Container Registry (ACR)**
  - acr

- **Azure Kubernetes Service (AKS)**
  - aks

- **CosmosDB**
  - cosmosdb

- **Azure AI Search**
  - aiSearch

- **Azure Storage**
  - storage

- **Application Insights**
  - appInsights

- **API Management (APIM)**
  - apim

- **APIM API Registration**
  - graphragDocsApi
  - graphragApi

- **Private Endpoints (if enabled)**
  - cosmosDbPrivateEndpoint
  - blobStoragePrivateEndpoint
  - aiSearchPrivateEndpoint
  - privateLinkScopePrivateEndpoint

- **Azure Monitor Private Link Scope**
  - azureMonitorPrivateLinkScope

- **Other Post-Deployment Steps**
  - Docker image build and push to ACR (if internal ACR is used)
  - AKS credentials retrieval and Helm chart installation
  - DNS record creation for GraphRAG
  - APIM API import and setup
  - (Optional) Grant developer access to Azure resources

**Note:**
The current `deploy.sh` script deploys everything via `main.bicep`. To use the split, update the script to call `main-owner.bicep` for Owner steps and `main-contrib.bicep` for Contributor steps, passing outputs as parameters.

---

## Next Steps

- Update deployment scripts to support the two-stage deployment process if needed.
- Continue to document any further changes or enhancements in this README.

---
