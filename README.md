```sh
Deplyoing SAP HANA, express edition on Google Kubernetes Engine (GKE) with Terraform
```

This project is about to provide an automated way to deploy SAP HANA, express edition to Google Kubernetes Engine (GKE).

AWS services used for this solution:
  - Google Kubernetes Engine (```GKE```)
  - Terraform
  - BASH

Source of the SAP HANA, Express Edition (private repository):  [Docker Hub](https://hub.docker.com/_/sap-hana-express-edition)

# About SAP HANA, express edition
```SAP HANA, express edition``` is a streamlined version of the SAP HANA platform which enables developers to jumpstart application development in the cloud or personal computer to build and deploy modern applications that use up to 32GB memory. SAP HANA, express edition includes the in-memory data engine with advanced analytical data processing engines for business, text, spatial, and graph data - supporting multiple data models on a single copy of the data. 
The software license allows for both non-production and production use cases, enabling you to quickly prototype, demo, and deploy next-generation applications using SAP HANA, express edition without incurring any license fees. Memory capacity increases beyond 32GB are available for purchase at the SAP Store.

# Preparation

Please make sure that you setup the following before starting the shell script.

1) Ensure that you have an Google Cloud Platform Account
2) Ensure that you have set up GCP SDK CLI (aka gcloud) based on this: https://cloud.google.com/sdk/docs/quickstart
3) Ensure that you have installed Terraform CLI based on this: https://learn.hashicorp.com/tutorials/terraform/install-cli 
4) Ensure that you have access to GCP Console and can access Cloud Shell 
5) Ensure that you have valid [Docker Hub](https://hub.docker.com/) access
6) Ensure that you have [installed kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

Change the following parameters in terraform folder -> gke.tf:

```sh
resource "null_resource" "hana-install" {
  provisioner "local-exec" {
      environment = {
        DOCKER_USERNAME = "CHANGE_ME"
        DOCKER_PASSWORD = "CHANGE_ME"
        DOCKER_EMAIL = "CHANGE_ME"
        HANA_PASSWORD = "CHANGE_ME"
      }
```

Change the following parameters in terraform folder -> terraform.tfvars:

```sh
project_id = "CHANGE_ME"
region     = "us-central1"
```

### About the Terraform template 

It is an ultimate tool to deploy SAP HANA, express edition on Google Kubernetes Engine. It utilizes tools like gcloud SDK CLI, terraform and kubectl. 

### Installation

#### Deploy K8s cluster on Google Kubernetes Engine with Terraform


First clone this repository: 
```sh
git clone https://github.com/cloudsapiens/gHana.git
```

Secondly, go to ```terraform``` folder and execute the following:
```sh
terraform init
```

Afterwards in the terminal, execute the following command to use you gcloud credentials:
```sh
gcloud auth application-default login
```

Afterwards in the terminal, execute the following command to deploy the cluster:
```sh
terraform apply --auto-approve
```

The deployment takes some minutes

The following are default ports for this deployment (SID: 90):
 - ```39013``` (SAP HANA indexserver)
 - ```39017``` (SAP HANA statisticsserver)
 - ```39041``` (SQL/MDX access port for standard access to the tenant databases of a multitenant system)
 - ```39042``` (Internal port of the XS classic server in the initial tenant database of a new multitenant system or an upgraded single-container system)
 - ```39043``` (Port used by streaming clients running outside the SAP HANA system to connect to streaming web services such as Streaming Web Service (SWS) and Web Services Provider (WSP) using various web protocols)
 - ```39044``` (Port used by streaming clients running outside the SAP HANA system to connect to streaming web services such as Streaming Web Service (SWS) and Web Services Provider (WSP) using various web protocols)
 - ```39045``` (Port used by streaming clients running outside the SAP HANA system to connect to streaming web services such as Streaming Web Service (SWS) and Web Services Provider (WSP) using various web protocols)
 - ```1128``` (SAP Host Agent with SOAP/HTTP - saphostctrl)
 - ```1129``` (SAP Host Agent with SOAP/HTTP - saphostctrls)
 - ```59013``` (Instance Agent)
 - ```59014``` (Instance Agent)

### Uninstallation

The following command deletes all related resources in your GCP account
```sh
terraform destroy --auto-aprove
```


### (Optional) Create table with HdbSQL command inside the container
 - Get Pods
```sh 
kubectl get pods
```
 - Execute command and use pod's name: 
```sh 
kubectl exec -it <<pod-name>> bash
```
 - Now, you are inside the container (as user: ```hxeadm```)
 - With the command, you can connect to your DB: 
``` sh 
hdbsql -i 90 -d SYSTEMDB -u SYSTEM -p <YOURVERYSECUREPASSWORD> 
```
 - With the following simple SQL statement you can create a column-stored table with one record: 

```sh
CREATE COLUMN TABLE company_leaders (name NVARCHAR(30), position VARCHAR(30));
INSERT INTO company_leaders VALUES ('Test1', 'Lead Architect');
```
