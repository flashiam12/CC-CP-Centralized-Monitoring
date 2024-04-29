locals {
  monitoring_namespace = "monitoring"
}

resource "kubernetes_namespace" "monitoring" {
  provider = kubernetes.kubernetes-raw
  metadata {
    name = local.monitoring_namespace
    annotations = {
      "owner" = "cp-picpay"
      "purpose" = "cp-picpay-demos"
    }
  }
  depends_on = [ 
    module.gke
  ]
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  chart      = "${path.module}/dependencies/prometheus"
  namespace  = local.monitoring_namespace
  cleanup_on_fail = true
  create_namespace = false
  values = [file("${path.module}/dependencies/prometheus/values.yaml")]
  depends_on = [ 
    kubernetes_namespace.confluent
  ]
}

resource "helm_release" "grafana" {
  name       = "grafana"
  chart      = "${path.module}/dependencies/grafana"
  namespace  = local.monitoring_namespace
  cleanup_on_fail = true
  create_namespace = false
  values = [file("${path.module}/dependencies/grafana/values.yaml")]
  depends_on = [ 
    kubernetes_namespace.confluent
  ]
  set {
    name = "adminUser"
    value = "admin"
  }
  set {
    name = "adminPassword"
    value = "confluent"
  }
}