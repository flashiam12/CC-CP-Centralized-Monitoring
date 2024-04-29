# CC-CP-Centralized-Monitoring

##### This project is an example of monitoring both confluent cloud and confluent platform using a single grafana dashboad. Here, we are also using single CP Control center to manage both kafka clusters. 

## Architecture 

![alt text](example/architecture.png)

## Setup
```console
#! /bin/bash

export TF_VAR_confluent_api_key=<CC_CLOUD_APIKEY>
export TF_VAR_confluent_api_secret=<CC_CLOUD_SECRETKEY>
export TF_VAR_confluent_env=<CC_ENVIRONMENT_NAME> 
export TF_VAR_confluent_aws_region=<CC_AWS_REGION>
export TF_VAR_gcp_project_id=<CP_GCP_PROJECT_ID> 
export TF_VAR_gcp_region=<CP_GCP_PROJECT>
export TF_VAR_gcp_network_name=<CP_GCP_VPC> 

terraform apply 
```

## Prometheus Modification
```console
# Prometheus.yaml in k8s secrets to use CC Metrics API

scrape_configs:
  - job_name: Confluent Cloud
    scrape_interval: 1m
    scrape_timeout: 1m
    honor_timestamps: true
    static_configs:
      - targets:
        - api.telemetry.confluent.cloud
    scheme: https
    basic_auth:
      username: <Cloud API Key>
      password: <Cloud API Secret>
    metrics_path: /v2/metrics/cloud/export
    params:
      "resource.kafka.id":
        - lkc-xxxxx
```

## Teardown
```console
terraform destroy
```