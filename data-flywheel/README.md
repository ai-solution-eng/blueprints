# NVIDIA Data Flywheel Helm Chart
This Helm chart deploys the [NVDIDIA Data Flywheel Blueprint](https://github.com/NVIDIA-AI-Blueprints/data-flywheel) and its associated services on HPE Private Cloud AI (PCAI) environments. 

| Owner                       | Name                              | Email                                     |
| ----------------------------|-----------------------------------|-------------------------------------------|
| Use Case Owner              | Daniel Cao                     | daniel.cao@hpe.com                      |
| PCAI Deployment Owner       | Daniel Cao                     | daniel.cao@hpe.com                      |

### Current status: 

- The chart spins up automatically and all the pods are running. 
- We tested starting a job from the notebook and could successfully create a job, monitor the job and deploy a custom inference endpoint.

## Demo Video: (Pending)

## Prerequisites

1. Access to a PCAI cluster
2. NVIDIA API & NGC API keys
3. A deployed embedding model and/or LLM judge model if you prefer not to deploy those models locally
4. Hardware requirements: 2xL40S or better

## Modifications to the original data-flywheel's values.yaml (version 0.3.1)

1. Add the following part to configure virtualService. Note that the namespace configured here and on the UI has to be consistent - "data-flywheel"

```yaml
ezua:
  virtualService:
    endpoint: "data-flywheel.${DOMAIN_NAME}"
    istioGateway: "istio-system/ezaf-gateway"
  # if your cluster has self-signed certs, and you're using an MLIS endpoint, you'll need to enable this
  # to add the certs to the agent deployment so it can trust it
  #and then uncomment out the extrapod volume and args section below
  selfSignedCert: false
```

2. Set up namespace

```yaml
# Default values for data-flywheel.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

namespace: "data-flywheel"
```

3. Disable production profile 

```yaml
# Deployment profile settings
# - For production profile, kibana and Data Flywheel flower server are disabled
#   For non-production profiles, kibana and Data Flywheel flower server are enabled
# - For mlflow profile (default), COMPOSE_PROFILES is "mlflow"
# - For non-mlflow profile, COMPOSE_PROFILES is "" (leave blank)
profile:
  production:
    enabled: false
  mlflow:
    COMPOSE_PROFILES: "mlflow"
```

4. Add generic service for NeMo Microservices virtualService routing
```yaml
  genericService:
    enabled: true
    fullnameOverride: "df-generic-service"
    service:
      type: ClusterIP
      # This service doesn't need a port - it's just a DNS entry for Istio
      # But Kubernetes requires at least one port, so we define a dummy one
      port: 8000
      # -- Annotations for Istio mesh integration
      labels: {}
```

5. Replace the default DNS hostnames using following Kubernetes services

```yaml
  config:
    nmp_config:
      nemo_base_url: "http://df-generic-service.data-flywheel.svc.cluster.local:8000"
      nim_base_url: "http://nemo-nim-proxy.data-flywheel.svc.cluster.local:8000"
      datastore_base_url: "http://nemo-data-store.data-flywheel.svc.cluster.local:3000"
```

6. Select the logging config level

```yaml
    # Logging configuration
    logging_config:
      level: "DEBUG"  # Options: DEBUG, INFO, WARNING, ERROR, CRITICAL
```

7. Set up a remote LLM judge model. 

```yaml
    llm_judge_config:
      deployment_type: "remote"
      url: "https://integrate.api.nvidia.com/v1/chat/completions" # Replace integrate.api.nvidia.com with your model endpoint
      model_name: meta/llama-3.3-70b-instruct 
      # To spin up a dedicated NIM in your cluster, comment the above uncomment and fill these:
      # deployment_type: "local"
      # model_name: "meta/llama-3.3-70b-instruct"
      # context_length: 32768
      # gpus: 4
      # pvc_size: 25Gi
      # tag: "1.8.5"
```

Otherwise uncomment the local deployment option if you want to use a local NIM model in your cluster.

```yaml
    llm_judge_config:
      # deployment_type: "remote"
      # url: "https://integrate.api.nvidia.com/v1/chat/completions" # Replace integrate.api.nvidia.com with your model endpoint
      # model_name: meta/llama-3.3-70b-instruct 
      # To spin up a dedicated NIM in your cluster, comment the above uncomment and fill these:
      deployment_type: "local"
      model_name: "meta/llama-3.3-70b-instruct"
      context_length: 32768
      gpus: 4
      pvc_size: 25Gi
      tag: "1.8.5"
```

8. Set up embedding model name and endpoint

**Note:** You should consider the dimension of the vector output for each model. Elasticsearch configuration expects a 2024-dimension vector, so **nvidia/llama-3.2-nv-embedqa-1b-v2** works but other embedding models such as **nvidia/nv-embedqa-e5-v5** might fail due to the dimension mismatch issue, resulting in a "Elasticsearch Bulk Indexing Error".

```yaml
    # ICL config:
    # max context length, reserved tokens, max examples, min examples
    # example_selection: "uniform_distribution" or "semantic_similarity"
    icl_config:
      max_context_length: 32768
      reserved_tokens: 4096
      max_examples: 3
      min_examples: 1
      example_selection: "semantic_similarity"
      similarity_config:
        relevance_ratio: 0.7
        embedding_nim_config:
          deployment_type: "remote"
          url: "http://nemo-retriever-embedding-ms.nv-rag.svc.cluster.local:8000/v1/embeddings" # Replace this with your embedding model endpoint service
          model_name: "nvidia/llama-3.2-nv-embedqa-1b-v2"
          # deployment_type: "local"
          # model_name: "nvidia/llama-3.2-nv-embedqa-1b-v2"
          # context_length: 32768
          # gpus: 1
          # pvc_size: "25Gi"
          # tag: "1.9.0"
```

Alternatively, you can use a locally deployed embedding model by uncommenting the local deployment option.

```yaml
          deployment_type: "local"
          model_name: "nvidia/llama-3.2-nv-embedqa-1b-v2"
          context_length: 32768
          gpus: 1
          pvc_size: "25Gi"
          tag: "1.9.0"
```

9. Replace the default DNS hostnames with the correct cluster service url and domain.

```yaml
    external:
      rootUrl: http://nemo-data-store.data-flywheel.svc.cluster.local
      domain: nemo-data-store.data-flywheel.svc.cluster.local:3000
```

10. Set up a Virtual Service using the DNS entry created by the generic service above to route traffic to different services.

```yaml
  virtualService:
    enabled: true
    main:
      hosts: ["df-generic-service.data-flywheel.svc.cluster.local"]
    additional:
      data-store:
        hosts: ["df-data-store.data-flywheel.svc.cluster.local"]
      nim-proxy:
        hosts: ["nim-proxy.data-flywheel.svc.cluster.local"]
```

11. Set up the StorageClass 

```yaml
    modelsStorage:
      storageClassName: "" # Or specific storage class option available on your system, ex., "gl4f-filesystem"
```

## Import framework:

1. Access the HPE AI Essentials portal
2. Click the Tools & Frameworks icon on the left navigation bar
3. Click + Import Framework.
- Choose a Framework name, ex., NVIDIA Data Flywheel Blueprint
- Description 
- Category: of your choice, for example Data Science.
- Framework Icon: Click Select File and select the icon logo file in this repo
- Helm Chart: Choose the packaged .tgz chart file in this repo
- Namespace: "data-flywheel". Make sure that this is identical to the namespace specified in the helm chart's values.yaml
- Release: Optional

## Additional Notes

-For details on importing arbitrary custom frameworks into Private Cloud AI, follow the steps in the [HPE documentation for importing applications as custom frameworks](https://support.hpe.com/hpesc/public/docDisplay?docId=a00aie16hen_us&page=ManageClusters/importing-applications.html) 