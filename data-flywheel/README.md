# pcai-nvidia-dataflywheel [Work in Progress]
NVDIDIA Data Flywheel on PCAI

### Current status: 

The chart spin up automatically (without any patch) and all the pods are spun up successfully. 

### Modifications already made (or to be made) to the data-flywheel's values.yaml

1. Add the following part to configure virtualService. Note that the namespace configured here and on the UI has to be consistent - "data-flywheel" (already made)


```yaml
ezua:
  virtualService:
    endpoint: "data-flywheel.${DOMAIN_NAME}"
    istioGateway: "istio-system/ezaf-gateway"
  # if your cluster has self-signed certs, and you're using an MLIS endpoint, you'll need to enable this
  # to add the certs to the agent deployment so it can trust it
  #and then uncomment out the extrapod volume and args section below
  selfSignedCert: true

# Default values for data-flywheel.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

namespace: "data-flywheel"
```

2. Add you NGC API KEY & NVIDIA API KEY

```yaml
# imagePullSecrets used for pulling candidate NIMs
imagePullSecrets:
  - name: nvcrimagepullsecret
    registry: nvcr.io
    username: $oauthtoken
    password: <YOUR NGC-API-KEY>
```

```yaml
secrets:
  ngcApiKey: <YOUR NGC-API-KEY>  # Set this to your NGC API key
  nvidiaApiKey: <YOUR NVIDIA-API-KEY> # Set this to your NVIDIA API key
  hfToken: <YOUR HF-TOKEN> # Set this to your HF Token
  llmJudgeApiKey: <YOUR LLM JUDGE MODEL ENDPOINT API KEY>
  embApiKey: <YOUR EMBEDDING MODEL ENDPOINT API KEY>
```

3. Add config to enable/disable istio sidecar injection for elasticsearch, mongodb, redis, data-store, entity-store, nemo-operator, nim-operator, guardrails, customizer, nim-proxy, evaluator, and deployment-manager.

```yaml
    podAnnotations:
      sidecar.istio.io/inject: "false"  # ← Add this
```

4. Add generic service for NeMo Microservices virtualService routing
```yaml
# ═══════════════════════════════════════════════════════════
  # Generic Service for NeMo Microservices VirtualService Routing
  # ═══════════════════════════════════════════════════════════
  genericService:
    # -- Enable the generic service for NeMo VirtualService routing
    enabled: true
    fullnameOverride: "df-generic-service"
    service:
      type: ClusterIP
      # This service doesn't need a port - it's just a DNS entry for Istio
      # But Kubernetes requires at least one port, so we define a dummy one
      port: 8000
      # -- Annotations for Istio mesh integration
      labels: {}
      annotations:
        # This service is for Istio VirtualService routing only
        networking.istio.io/exportTo: "."
```

5. Modify the URLs using cluster services

```yaml
  config:
    nmp_config:
      # nemo_base_url: "http://nemo.test"
      # nim_base_url: "http://nim.test"
      # datastore_base_url: "http://data-store.test"
      nemo_base_url: "http://df-generic-service.data-flywheel.svc.cluster.local:8000" # route to the generic df-generic-service
      nim_base_url: "http://nemo-nim-proxy.data-flywheel.svc.cluster.local:8000"
      datastore_base_url: "http://nemo-data-store.data-flywheel.svc.cluster.local:3000"
```

6. Add endpoint URL for Judge LLM model 

```yaml
    llm_judge_config:
      deployment_type: "remote"
      url: <ENDPOINT-URL>
      model_name: <MODEL-NAME> # Ex., "meta-llama/Llama-3.1-8B-Instruct"
    #   To spin up a dedicated NIM in your cluster, comment the above uncomment and fill these:
    #   deployment_type: "local"
    #   model_name: "meta/llama-3.3-70b-instruct"
    #   context_length: 32768
    #   gpus: 4
    #   pvc_size: 25Gi
    #   tag: "1.8.5"
```

Note: You should consider the dimension of the vector output for each model. Elasticsearch configuration expects a 2024-dimension vector, so ***nvidia/llama-3.2-nv-embedqa-1b-v2*** works but embedding model such as ***nvidia/nv-embedqa-e5-v5*** fails due to dimension mismatch, resulting in a "Elasticsearch Bulk Indexing Error".

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
          url: <EMBEDDING-ENDPOINT-URL>
          model_name: <EMBEDDING-MODEL-NAME>
          input_type: "query" # ← Add this line
        #   model_name: "nvidia/llama-3.2-nv-embedqa-1b-v2"
        #   deployment_type: "local"
        #   model_name: "nvidia/llama-3.2-nv-embedqa-1b-v2"
        #   context_length: 32768
        #   gpus: 1
        #   pvc_size: "25Gi"
        #   tag: "1.9.0"
```

7. Istrio sidecar injection for nemo microservices 

```yaml
# Nemo Microservices configuration
nemo-microservices-helm-chart:
  enabled: true

  existingSecret: ngc-api
  existingImagePullSecret: nvcrimagepullsecret

  # ═══════════════════════════════════════════════════════════
  # Global Istio Sidecar Injection for All NeMo Microservices
  # ═══════════════════════════════════════════════════════════
  global:
    podAnnotations:
      sidecar.istio.io/inject: "true"
      # Exclude database ports from Istio mesh
      traffic.sidecar.istio.io/excludeOutboundPorts: "5432,9200,6379,27017"
```

### CURRENT ISSUE

However an issue happens when submitting a job from the UI with failed write permission in a customizer pod. Is this a BUG? Probably. Let's see the details.

**WHY IS THIS A BUG?** 
If the ConfigMap has both volumes and volumeMounts configured, but the resulting jobs only have the entity-volume (not scratch), then the customizer must be ignoring the volumes configuration when creating jobs.

ConfigMap has the configuration ✓
Jobs don't have the scratch volume ✓
Therefore: customizer isn't applying that part of the config

The pattern suggests the customizer might be hardcoded to only create certain volumes (like entity-volume) and doesn't dynamically add volumes from the nemoDataStoreTools configuration, even though the configuration structure supports it. 

Let's take a step back ...

####  What are issue symtoms?

- On the UI: 'error': 'Error starting customization: Job cust-9NAvCSuV18nJi3M9u3AdB1 failed: The training job is pending'. The finetuning never starts. It looks something like this when user sends a get-job-status request after submitting the job. 


```yaml
{'id': '68e8d40a8d56442795349994',
 'workload_id': 'primary_assistant',
 'client_id': 'aiva-1',
 'status': 'completed',
 'started_at': '2025-10-10T09:38:18.371000',
 'finished_at': '2025-10-10T10:10:55.843000',
 'num_records': 1000,
 'llm_judge': {'model_name': 'meta-llama/Llama-3.1-8B-Instruct',
  'type': 'remote',
  'deployment_status': 'ready',
  'error': None},
 'nims': [{'model_name': 'meta/llama-3.2-1b-instruct',
   'status': 'completed',
   'deployment_status': 'completed',
   'runtime_seconds': 1376.959294,
   'evaluations': [{'eval_type': 'base-eval',
     'scores': {'function_name': 0.56,
      'function_name_and_args_accuracy': 0.0,
      'tool_calling_correctness': 0.12},
     'started_at': '2025-10-10T10:00:41.726000',
     'finished_at': '2025-10-10T10:09:53.838000',
     'runtime_seconds': 554.061625,
     'progress': 100.0,
     'nmp_uri': 'http://df-generic-service.data-flywheel.svc.cluster.local:8000/v1/evaluation/jobs/eval-J6jgppPsh2eJ2yXKEzujDZ',
     'mlflow_uri': 'http://df-mlflow-service:5000/#/experiments/149856809913389854',
     'error': None},
    {'eval_type': 'icl-eval',
     'scores': {'function_name': 0.63,
      'function_name_and_args_accuracy': 0.0,
      'tool_calling_correctness': 0.19},
     'started_at': '2025-10-10T10:00:41.728000',
     'finished_at': '2025-10-10T10:09:53.839000',
     'runtime_seconds': 553.606738,
     'progress': 100.0,
     'nmp_uri': 'http://df-generic-service.data-flywheel.svc.cluster.local:8000/v1/evaluation/jobs/eval-PUavHgKYLfKfxGTF1BvK8e',
     'mlflow_uri': None,
     'error': None}],
   'customizations': [{'started_at': '2025-10-10T10:00:41.732000',
     'finished_at': '2025-10-10T10:07:45.439000',
     'runtime_seconds': 423.706129,
     'progress': 0.0,
     'epochs_completed': 0,
     'steps_completed': 0,
     'nmp_uri': 'http://df-generic-service.data-flywheel.svc.cluster.local:8000/v1/customization/jobs/cust-9NAvCSuV18nJi3M9u3AdB1',
     'customized_model': 'dfwbp/customized-meta-llama-3.2-1b-instruct@cust-9NAvCSuV18nJi3M9u3AdB1',
     'error': 'Error starting customization: Job cust-9NAvCSuV18nJi3M9u3AdB1 failed: The training job is pending'}],
   'error': None}],
 'datasets': [{'name': 'flywheel-eval-primary_assistant-1760089098',
   'num_records': 100,
   'nmp_uri': 'hf://datasets/dfwbp/flywheel-eval-primary_assistant-1760089098'},
  {'name': 'flywheel-icl-primary_assistant-1760089098',
   'num_records': 100,
   'nmp_uri': 'hf://datasets/dfwbp/flywheel-icl-primary_assistant-1760089098'},
  {'name': 'flywheel-train-primary_assistant-1760089098',
   'num_records': 810,
   'nmp_uri': 'hf://datasets/dfwbp/flywheel-train-primary_assistant-1760089098'}],
 'error': None}
```


```sh
PermissionError: [Errno 13] Permission denied: '/scratch'
```

#### What could have happended?

The Error Chain:

- Entity-handler pods are trying to write to /scratch directory
- The /scratch directory doesn't exist or isn't writable because no volume is mounted there
- These pods are created by the customizer service

What nemoDataStoreTools is:

- It's a configuration section that tells the customizer HOW to create entity-handler jobs
- These jobs download datasets/models from the Data Store
- The configuration should specify volumes, mounts, and container settings

Why it's not working:
- Looking at the current ConfigMap template, the nemoDataStoreTools configuration IS being passed to the customizer, BUT the customizer application code isn't using the `volumes` section when creating jobs.
- This code reads the ConfigMap and creates Kubernetes Jobs for entity handling. The bug is that this code ignores the volumes configuration from nemoDataStoreTools when creating jobs.

The Root Problem Explained:

- Entity-handler jobs need to download data to /scratch before moving it to /pvc
- The customizer service creates these jobs based on configuration
- The bug: The customizer's Python code (inside the container image) ignores the volumes section of nemoDataStoreTools when creating jobs
- Result: Jobs are created WITHOUT the scratch volume, causing permission errors

#### What solutions have been tried?

##### 1. Adding an emptyDir-type volume

###### 1a. On the fly

Save an existing customizer job (which fails)'s config to this *customizer-job-patch.yaml* and add the scratch volume and volume path. This solves the issue. BUT escalate to a new issue - *KeyError: 'state'*

*customizer-job-patch.yaml*
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: cust-9hkmp47jdht6cpxga9s7pl-entity-handler-0-fixed
  namespace: data-flywheel
  labels:
    app: nemo-k8s-operator
    app.kubernetes.io/name: cust-9hkmp47jdht6cpxga9s7pl
spec:
  backoffLimit: 5
  completions: 1
  parallelism: 1
  template:
    metadata:
      annotations:
        sidecar.istio.io/inject: "false"
      labels:
        app: nemo-k8s-operator
        app.kubernetes.io/managed-by: nemo-k8s-operator
        app.kubernetes.io/name: cust-9hkmp47jdht6cpxga9s7pl
    spec:
      restartPolicy: Never
      securityContext:
        fsGroup: 1000
        fsGroupChangePolicy: OnRootMismatch
      imagePullSecrets:
      - name: nvcrimagepullsecret
      containers:
      - name: main
        image: nvcr.io/nvidia/nemo-microservices/nds-v2-huggingface-cli:25.08
        imagePullPolicy: Always
        command:
        - sh
        args:
        - -c
        - huggingface-cli download --repo-type dataset $ENTITY_NAME --local-dir /scratch/dataset && mkdir -p $ENTITY_PATH && mv /scratch/dataset/* $ENTITY_PATH
        env:
        - name: ENTITY_TYPE
          value: Dataset
        - name: ENTITY_NAME
          value: dfwbp/flywheel-train-primary_assistant-1760096570
        - name: ENTITY_PATH
          value: /pvc/cust-9hkmp47jdht6cpxga9s7pl/entities/Dataset/dfwbp/flywheel-train-primary_assistant-1760096570
        - name: HF_ENDPOINT
          value: http://nemo-data-store:3000/v1/hf
        - name: HF_HOME
          value: /tmp/hf_cache
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 500m
            memory: 1Gi
        volumeMounts:
        - name: entity-volume
          mountPath: /pvc
        - name: tmp
          mountPath: /tmp
        - name: scratch
          mountPath: /scratch
      volumes:
      - name: entity-volume
        persistentVolumeClaim:
          claimName: cust-9hkmp47jdht6cpxga9s7pl
      - name: tmp
        emptyDir: {}
      - name: scratch
        emptyDir: {}
```

```sh
The above exception was the direct cause of the following exception:

Traceback (most recent call last):
  ...
  File "/app/.venv/lib/python3.11/site-packages/sqlalchemy/dialects/postgresql/asyncpg.py", line 508, in _handle_exception
    self._adapt_connection._handle_exception(error)
  File "/app/.venv/lib/python3.11/site-packages/sqlalchemy/dialects/postgresql/asyncpg.py", line 792, in _handle_exception
    raise translated_error from error
sqlalchemy.exc.IntegrityError: (sqlalchemy.dialects.postgresql.asyncpg.IntegrityError) <class 'asyncpg.exceptions.UniqueViolationError'>: duplicate key value violates unique constraint "uq_customization_config"
DETAIL:  Key (namespace, name)=(dfwbp, llama-3.2-1b-instruct@v1.0.0+dfw) already exists.
[SQL: INSERT INTO customizationconfigtemplates (id, created_at, updated_at, schema_version, description, type_prefix, namespace, project, created_by, access_policies, name, target_id, training_precision, max_seq_length, pod_spec, prompt_template, chat_prompt_template, dataset_schemas) VALUES ($1::VARCHAR, $2::TIMESTAMP WITHOUT TIME ZONE, $3::TIMESTAMP WITHOUT TIME ZONE, $4::VARCHAR, $5::VARCHAR, $6::VARCHAR, $7::VARCHAR, $8::VARCHAR, $9::VARCHAR, $10::VARCHAR, $11::VARCHAR, $12::VARCHAR, $13::VARCHAR, $14::INTEGER, $15::JSON, $16::VARCHAR, $17::VARCHAR, $18::JSON)]
[parameters: ('cust-config-4F3wFHVay4sUq3uonNpgjF', datetime.datetime(2025, 10, 10, 12, 4, 15, 852071), datetime.datetime(2025, 10, 10, 12, 4, 15, 852078), '1.0', None, None, 'dfwbp', None, '', '{}', 'llama-3.2-1b-instruct@v1.0.0+dfw', 'cust-target-BmguZ6wnihrDoDKABWgMSY', <ModelPrecision.BF16_MIXED: 'bf16-mixed'>, 8192, 'null', '{prompt} {completion}', None, '[{"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "https://nemo.nvidia.com/schema.json", "title": "Newline-Delimited JSON File", "d ... (2964 characters truncated) ... n to train on", "title": "Completion", "type": "string"}}, "required": ["prompt", "completion"], "title": "SFTDatasetItemSchema", "type": "object"}}]')]
(Background on this error at: https://sqlalche.me/e/20/gkpj)
      INFO   127.0.0.6:59277 - "POST /v1/customization/configs HTTP/1.1" 409
2025-10-10T12:04:15Z WARNING: opentelemetry.sdk.trace - SDK is disabled.
2025-10-10T12:04:17Z INFO: customizer - Successfully created repo dfwbp/customized-meta-llama-3.2-1b-instruct and branch cust-9Hkmp47jdht6cPxgA9S7PL
2025-10-10T12:04:17Z WARNING: opentelemetry.sdk.trace - SDK is disabled.
2025-10-10T12:04:17Z INFO: customizer - Loaded in-cluster K8s config
2025-10-10T12:04:17Z ERROR: customizer - JobWatcher(cust-9Hkmp47jdht6cPxgA9S7PL) caught exception in watch loop
Traceback (most recent call last):
  File "/app/.venv/lib/python3.11/site-packages/customizer/jobs/tasks.py", line 173, in watch
    if await self.done():
       ^^^^^^^^^^^^^^^^^
  File "/app/.venv/lib/python3.11/site-packages/customizer/jobs/tasks.py", line 107, in done
    ntj_state = ntj_status["state"]
                ~~~~~~~~~~^^^^^^^^^
KeyError: 'state'
2025-10-10T12:04:17Z INFO: customizer - Created Job cust-9Hkmp47jdht6cPxgA9S7PL
      INFO   127.0.0.6:44565 - "POST /v1/customization/jobs HTTP/1.1" 200
      INFO   127.0.0.6:44565 - "GET                                             
             /v1/customization/jobs/cust-9Hkmp47jdht6cPxgA9S7PL/status HTTP/1.1"
             200
      INFO   127.0.0.6:36335 - "GET                                             
             /v1/customization/jobs/cust-9Hkmp47jdht6cPxgA9S7PL/status HTTP/1.1"
             200
      INFO   127.0.0.6:47303 - "GET                                             
             /v1/customization/jobs/cust-9Hkmp47jdht6cPxgA9S7PL/status HTTP/1.1"
             200
      INFO   127.0.0.6:37961 - "GET                                             
             /v1/customization/jobs/cust-9Hkmp47jdht6cPxgA9S7PL/status HTTP/1.1"
             200
      INFO   127.0.0.6:48087 - "GET                                             
             /v1/customization/jobs/cust-9Hkmp47jdht6cPxgA9S7PL/status HTTP/1.1"
             200
      INFO   127.0.0.6:53031 - "GET                                             
             /v1/customization/jobs/cust-9Hkmp47jdht6cPxgA9S7PL/status HTTP/1.1"
             200
      INFO   127.0.0.6:40597 - "GET                                             
             /v1/customization/jobs/cust-9Hkmp47jdht6cPxgA9S7PL/status HTTP/1.1"
             200
      INFO   127.0.0.6:60477 - "GET                                             
             /v1/customization/jobs/cust-9Hkmp47jdht6cPxgA9S7PL/status HTTP/1.1"
             200
      INFO   127.0.0.6:58367 - "GET                                             
             /v1/customization/jobs/cust-9Hkmp47jdht6cPxgA9S7PL/status HTTP/1.1"
             200
      INFO   127.0.0.6:49965 - "GET                                             
             /v1/customization/jobs/cust-9Hkmp47jdht6cPxgA9S7PL/status HTTP/1.1"
             200
      INFO   127.0.0.6:39375 - "GET                                             
             /v1/customization/jobs/cust-9Hkmp47jdht6cPxgA9S7PL/status HTTP/1.1"
             200
      INFO   127.0.0.6:37269 - "GET                                             
             /v1/customization/jobs/cust-9Hkmp47jdht6cPxgA9S7PL/status HTTP/1.1"
             200
      INFO   127.0.0.6:53005 - "GET                                             
             /v1/customization/jobs/cust-9Hkmp47jdht6cPxgA9S7PL/status HTTP/1.1"
             200
      INFO   127.0.0.6:47019 - "GET                                             
             /v1/customization/jobs/cust-9Hkmp47jdht6cPxgA9S7PL/status HTTP/1.1"
             200
2025-10-10T12:11:08Z INFO: customizer - JobWatcher(cust-9Hkmp47jdht6cPxgA9S7PL) in terminal state: failed
2025-10-10T12:11:08Z INFO: customizer - JobWatcher(cust-9Hkmp47jdht6cPxgA9S7PL) fetching all events and logs associated with this NemoTrainingJob.
      INFO   127.0.0.6:60417 - "GET                                             
             /v1/customization/jobs/cust-9Hkmp47jdht6cPxgA9S7PL/status HTTP/1.1"
             200
      INFO   127.0.0.6:50973 - "POST                                            
             /v1/customizations/cust-9Hkmp47jdht6cPxgA9S7PL/cancel HTTP/1.1" 404
```

###### 1b. Prebuilt emptyDir volume

This modification in the top chart's values.yaml - adding emptyDir volume type and mount it to the customizer pod under both customizerConfig and nemoDataStoreTools has NOT worked yet. The root issue is that the nemoDataStoreTools configuration in the helm chart isn't being applied to entity-handler jobs by the customizer. This needs to be fixed in the customizer application code itself. The nemoDataStoreTools.volumes configuration should be applied to entity-handler jobs but it's not working. 

```yaml
    customizerConfig:
      training:
        pvc:
          storageClass: "gl4f-filesystem"
          volumeAccessMode: "ReadWriteOnce"
          size: 20Gi  # Increased to handle scratch needs
        # Add volumes here - these get applied to ALL jobs including entity-handlers
        volumes:
          - name: scratch
            emptyDir:
              sizeLimit: 10Gi
        container_defaults:
          volumeMounts:
            - name: scratch
              mountPath: /scratch

    nemoDataStoreTools:
      registry: nvcr.io
      repository: nvidia/nemo-microservices/nds-v2-huggingface-cli
      tag: "25.08"
      imagePullSecret: nvcrimagepullsecret
      # FIX: Mount /scratch from emptyDir
      # (Fixes entity handler /scratch permission errors)
      # ═══════════════════════════════════════════════════════════
      container_defaults:
        volumeMounts:
          - name: scratch
            mountPath: /scratch
      volumes:
        - name: scratch
          emptyDir:
            sizeLimit: 10Gi
      # ═══════════════════════════════════════════════════════════
```

###### 1c. Apply entity handler fixer/patcher strategies
This approach doesn't yield a successful outcome.

#### How should we solve this issue?

To solve this, we have three options:

- Report the bug to NVIDIA - The customizer needs to be fixed to use the volumes from nemoDataStoreTools config
- Use a different storage approach - Mount a persistent volume at /scratch instead of emptyDir
- Create jobs manually with the correct volume configuration when needed

The issue is a clear bug: the customizer reads nemo_data_store_tools.container_defaults.volumeMounts but ignores nemo_data_store_tools.volumes, resulting in jobs with volume mounts but no actual volumes.