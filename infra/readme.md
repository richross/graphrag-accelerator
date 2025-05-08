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

- **main-contrib.bicep**:
  Deploys all other resources that can be created with Contributor permissions, including:
  - AKS, CosmosDB, Storage, AI Search, App Insights, APIM, etc.
  - Uses outputs from `main-owner.bicep` as parameters (e.g., identity IDs, subnet IDs).

### 2. Handoff Process

- The deployment is performed in two stages:
  1. **Owner** runs `main-owner.bicep` and provides the outputs (resource IDs, identity IDs, etc.).
  2. **Contributor** runs `main-contrib.bicep`, supplying the outputs from the previous step as parameters.

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

## Next Steps

- Update deployment scripts to support the two-stage deployment process if needed.
- Continue to document any further changes or enhancements in this README.

---
