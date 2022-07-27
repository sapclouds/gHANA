variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "gke_num_nodes" {
  default     = 1
  description = "number of gke nodes"
}

# GKE cluster
resource "google_container_cluster" "primary" {
  name     = "${var.project_id}-gke"
  location = var.region
  
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
}

# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${google_container_cluster.primary.name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_num_nodes

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = var.project_id
    }

    # preemptible  = true
    machine_type = "e2-standard-4"
    image_type = "UBUNTU"
    tags         = ["gke-node", "${var.project_id}-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

resource "null_resource" "hana-install" {
  provisioner "local-exec" {
      environment = {
        CLUSTER = "${var.project_id}-gke"
        REGION = "${var.region}"
        PROJECT = "${var.project_id}"
        DOCKER_USERNAME = "CHANGE_ME"
        DOCKER_PASSWORD = "CHANGE_ME"
        DOCKER_EMAIL = "CHANGE_ME"
        HANA_PASSWORD = "CHANGE_ME"
      }
      command = <<-EOT
      gcloud container clusters get-credentials $CLUSTER --region $REGION --project $PROJECT
      kubectl create secret docker-registry docker-secret --docker-server=https://index.docker.io/v1/ --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_PASSWORD --docker-email=$DOCKER_EMAIL
      touch hxe.yaml

      echo 'kind: ConfigMap
      apiVersion: v1
      metadata:
        creationTimestamp: 2018-01-18T19:14:38Z
        name: hxe-pass
      data:
        password.json: |+
          {"master_password" : "$HANA_PASSWORD"}
      ---
      kind: PersistentVolume
      apiVersion: v1
      metadata:
        name: persistent-vol-hxe
        labels:
          type: local
      spec:
        storageClassName: manual
        capacity:
          storage: 150Gi
        accessModes:
          - ReadWriteOnce
        hostPath:
          path: "/data/hxe_pv"
      ---
      kind: PersistentVolumeClaim
      apiVersion: v1
      metadata:
        name: hxe-pvc
      spec:
        storageClassName: manual
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 50Gi
      ---
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: hxe
        labels:
          name: hxe
      spec:
        selector:
          matchLabels:
            run: hxe
            app: hxe
            role: master
            tier: backend
        replicas: 1
        template:
          metadata:
            labels:
              run: hxe
              app: hxe
              role: master
              tier: backend
          spec:
            initContainers:
              - name: install
                image: busybox
                command: [ "sh", "-c", "chown 12000:79 /hana/mounts" ]
                volumeMounts:
                  - name: hxe-data
                    mountPath: /hana/mounts
            volumes:
              - name: hxe-data
                persistentVolumeClaim:
                  claimName: hxe-pvc
              - name: hxe-config
                configMap:
                  name: hxe-pass
            imagePullSecrets:
            - name: docker-secret
            containers:
            - name: hxe-container
              image: "store/saplabs/hanaexpress:2.00.030.00.20180403.2"
              ports:
                - containerPort: 39013
                  name: port1
                - containerPort: 39015
                  name: port2
                - containerPort: 39017
                  name: port3
                - containerPort: 8090
                  name: port4
                - containerPort: 39041
                  name: port5
                - containerPort: 59013
                  name: port6
              args: [ "--agree-to-sap-license", "--dont-check-system", "--passwords-url", "file:///hana/hxeconfig/password.json" ]
              volumeMounts:
                - name: hxe-data
                  mountPath: /hana/mounts
                - name: hxe-config
                  mountPath: /hana/hxeconfig
            - name: sqlpad-container
              image: "sqlpad/sqlpad"
              ports:
              - containerPort: 3000

      ---
      apiVersion: v1
      kind: Service
      metadata:
        name: hxe-connect
        labels:
          app: hxe
      spec:
        type: LoadBalancer
        ports:
        - port: 39013
          targetPort: 39013
          name: port1
        - port: 39015
          targetPort: 39015
          name: port2
        - port: 39017
          targetPort: 39017
          name: port3
        - port: 39041
          targetPort: 39041
          name: port5
        selector:
          app: hxe
      ---
      apiVersion: v1
      kind: Service
      metadata:
        name: sqlpad
        labels:
          app: hxe
      spec:
        type: LoadBalancer
        ports:
        - port: 3000
          targetPort: 3000
          protocol: TCP
          name: sqlpad
        selector:
          app: hxe' > hxe.yaml

      kubectl create -f hxe.yaml
      echo "SAP HANA will be up and running in a few minutes. Check your cluster with 'kubectl describe pods'"
      EOT
  }
}
