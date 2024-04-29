# google_client_config and kubernetes provider must be explicitly specified like the following.
data "google_client_config" "default" {}

data "google_compute_network" "default" {
  name = var.gcp_network_name
}

locals {
  gke_name = "picpay-multicloud-demo"
}

resource "google_compute_subnetwork" "default" {
  name          = "${var.gcp_network_name}-picpay-gke"
  ip_cidr_range = "172.10.0.0/18"
  region        = var.gcp_region
  network       = data.google_compute_network.default.id
  secondary_ip_range {
    range_name    = "us-central1-gke-services"
    ip_cidr_range = "192.168.0.0/22"
  }
  secondary_ip_range {
    range_name    = "us-central1-gke-pods"
    ip_cidr_range = "192.168.4.0/22"
  }
}

module "gke" {
  source                     = "terraform-google-modules/kubernetes-engine/google"
  project_id                 = var.gcp_project_id
  name                       = local.gke_name
  region                     = var.gcp_region
  zones                      = ["${var.gcp_region}-a", "${var.gcp_region}-b"]
  network                    = data.google_compute_network.default.name
  subnetwork                 = google_compute_subnetwork.default.name
  ip_range_pods              = "us-central1-gke-pods"
  ip_range_services          = "us-central1-gke-services"
  http_load_balancing        = true
  network_policy             = true
  horizontal_pod_autoscaling = true
  filestore_csi_driver       = false

  node_pools = [
    {
      name                      = "default-pool-picpay"
      machine_type              = "e2-standard-4"
      node_locations            = "${var.gcp_region}-a"
      min_count                 = 2
      max_count                 = 100
      local_ssd_count           = 0
      spot                      = false
      disk_size_gb              = 100
      disk_type                 = "pd-ssd"
      image_type                = "COS_CONTAINERD"
      enable_gcfs               = false
      enable_gvnic              = false
      logging_variant           = "DEFAULT"
      auto_repair               = true
      auto_upgrade              = true
    #   service_account           = "project-service-account@<PROJECT ID>.iam.gserviceaccount.com"
      preemptible               = false
      initial_node_count        = 2
    },
  ]

  node_pools_oauth_scopes = {
    all = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

  node_pools_labels = {
    all = {}
    default-node-pool = {
      default-node-pool = true
    }
  }
  node_pools_metadata = {
    all = {}
    default-node-pool = {
      node-pool-metadata-custom-value = "default-pool-picpay"
    }
  }
  node_pools_tags = {
    all = []
    default-node-pool = [
      "default-pool-picpay"
    ]
  }
}

locals {
  confluent_namespace = "confluent"
}

resource "kubernetes_namespace" "confluent" {
  provider = kubernetes.kubernetes-raw
  metadata {
    name = local.confluent_namespace
    annotations = {
      "owner" = "cp-picpay"
      "purpose" = "cp-picpay-demos"
    }
  }
  depends_on = [ 
    module.gke
  ]
}

resource "helm_release" "confluent-operator" {
  name       = "confluent-operator"
  chart      = "${path.module}/dependencies/confluent-for-kubernetes"
  namespace  = local.confluent_namespace
  cleanup_on_fail = true
  create_namespace = false
  values = [file("${path.module}/dependencies/confluent-for-kubernetes/values.yaml")]
  depends_on = [ 
    kubernetes_namespace.confluent
  ]
}
