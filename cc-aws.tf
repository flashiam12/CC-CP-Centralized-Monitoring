locals {
  cluster_name = "picpay-aws"
}

data "confluent_organization" "default" {}

data "confluent_environment" "default" {
  display_name = var.confluent_env
}

resource "confluent_service_account" "default" {
  display_name = "picpay-hybrid-cloud"
  description  = "Service Account for picpay demo"
}


resource "confluent_role_binding" "default" {
  principal   = "User:${confluent_service_account.default.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.standard.rbac_crn
}

resource "confluent_role_binding" "default-metrics" {
  principal   = "User:${confluent_service_account.default.id}"
  role_name   = "MetricsViewer"
  crn_pattern = data.confluent_organization.default.resource_name
}

resource "confluent_kafka_cluster" "standard" {
  display_name = local.cluster_name
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = var.confluent_aws_region
  standard {}

  environment {
    id = data.confluent_environment.default.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_api_key" "default" {
  display_name = "picpay-aws-cc"
  description  = "Kafka API Key that is owned by pic pay demo service account"
  owner {
    id          = confluent_service_account.default.id
    api_version = confluent_service_account.default.api_version
    kind        = confluent_service_account.default.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.standard.id
    api_version = confluent_kafka_cluster.standard.api_version
    kind        = confluent_kafka_cluster.standard.kind

    environment {
      id = data.confluent_environment.default.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "local_file" "cc-api-key" {
  content  = "username=${confluent_api_key.default.id}\npassword=${confluent_api_key.default.secret}"
  filename = "${path.module}/secrets/cc-aws-creds.txt"
}