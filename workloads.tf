data "google_dns_managed_zone" "default" {
  name = "gcp"
}

resource "google_dns_record_set" "bootstrap" {
  name = "picpay-bootstrap.${data.google_dns_managed_zone.default.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.default.name

  rrdatas = ["172.10.0.12"]
}

resource "google_dns_record_set" "broker" {
  name = "picpay-kafka.${data.google_dns_managed_zone.default.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.default.name

  rrdatas = ["172.10.0.14"]
}

data "kubectl_file_documents" "kafka" {
    content = templatefile("${path.module}/workloads/kafka.template.yaml", {
        namespace = local.confluent_namespace,
        bootstrap_prefix = "picpay-bootstrap",
        broker_prefix = "picpay-kafka",
        domain = "${data.google_dns_managed_zone.default.dns_name}"
    })
}

resource "kubectl_manifest" "kafka" {
  for_each  = data.kubectl_file_documents.kafka.manifests
  yaml_body = each.value
  depends_on = [
    helm_release.confluent-operator
  ]
}

resource "kubernetes_secret" "cc-creds" {
  provider = kubernetes.kubernetes-raw
  metadata {
    name = "cc-aws-kafka-creds"
    namespace = local.confluent_namespace
  }
  data = {
    "plain.txt" = file("${path.module}/secrets/cc-aws-creds.txt")
  }
  type = "generic"
  depends_on = [ local_file.cc-api-key ]
}

resource "kubernetes_secret" "credential" {
  provider = kubernetes.kubernetes-raw
  metadata {
    name = "credential"
    namespace = local.confluent_namespace
  }
  data = {
    "basic.txt" = file("${path.module}/secrets/cp-creds-basic-user.txt"),
    "plain.txt" = file("${path.module}/secrets/cp-creds-kafka-users.txt"),
    "plain-users.json" = file("${path.module}/secrets/cp-creds-kafka-sasl.json"),
  }
  type = "generic"
}

resource "kubernetes_secret" "password-encoder" {
  provider = kubernetes.kubernetes-raw
  metadata {
    name = "password-encoder-secret"
    namespace = local.confluent_namespace
  }
  data = {
    "password-encoder.txt" = file("${path.module}/secrets/cp-pass-encoder.txt")
  }
  type = "generic"
}

data "kubectl_file_documents" "c3" {
    content = templatefile("${path.module}/workloads/c3.template.yaml", {
        namespace = local.confluent_namespace,
        cc_aws_kafka_name = confluent_kafka_cluster.standard.display_name,
        cc_aws_kafka_bootstrap = confluent_kafka_cluster.standard.bootstrap_endpoint,
        ccloud_apisecret = kubernetes_secret.cc-creds.metadata[0].name
    })
}

resource "kubectl_manifest" "c3" {
  for_each  = data.kubectl_file_documents.c3.manifests
  yaml_body = each.value
  depends_on = [
    helm_release.confluent-operator, 
    confluent_kafka_cluster.standard,
    kubernetes_secret.cc-creds
  ]
}
