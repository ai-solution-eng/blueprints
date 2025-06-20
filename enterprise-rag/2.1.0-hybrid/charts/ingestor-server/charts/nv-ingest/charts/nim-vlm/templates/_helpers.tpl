{{/*
Expand the name of the chart.
*/}}
{{- define "nim-vlm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "nim-vlm.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "nim-vlm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nim-vlm.labels" -}}
helm.sh/chart: {{ include "nim-vlm.chart" . }}
{{ include "nim-vlm.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nim-vlm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nim-vlm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "nim-vlm.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "nim-vlm.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
For inline NGC key, create image pull secret
*/}}
{{- define "nim-vlm.generatedImagePullSecret" -}}
{{- if .Values.model.ngcAPIKey }}
{{- printf "{\"auths\":{\"nvcr.io\":{\"username\":\"$oauthtoken\",\"password\":\"%s\"}}}" .Values.model.ngcAPIKey | b64enc }}
{{- end }}
{{- end }}

{{/*
Generating logging variables for multi-node inference
*/}}
{{- define "nim-vlm.trtLLMLoggingLevel" -}}
{{- if eq .Values.model.logLevel "DEFAULT" -}}
ERROR
{{-  else if eq .Values.model.logLevel "CRITICAL" -}}
ERROR
{{- else -}}
{{ .Values.model.logLevel | upper }}
{{- end }}
{{- end }}

{{/*
Generating logging variables for multi-node inference
*/}}
{{- define "nim-vlm.vllmNVEXTLogLevel" -}}
{{- if eq .Values.model.logLevel "TRACE" -}}
DEBUG
{{-  else if eq .Values.model.logLevel "DEFAULT" -}}
INFO
{{- else -}}
{{ .Values.model.logLevel | upper }}
{{- end }}
{{- end }}

{{/*
Generating logging variables for multi-node inference
*/}}
{{- define "nim-vlm.uvicornLogLevel" -}}
{{- if eq .Values.model.logLevel "DEFAULT" -}}
info
{{- else -}}
{{ .Values.model.logLevel | lower }}
{{- end }}
{{- end }}

{{/*
Environment variables based on JSONL logging value for multi-node inference
*/}}
{{- define "nim-vlm.JSONLLoggingEnvVars" -}}
{{- if .Values.model.jsonLogging }}
- name: VLLM_LOGGING_CONFIG_PATH
  value: "/etc/nim/config/python_jsonl_logging_config.json"
- name: VLLM_NVEXT_LOGGING_CONFIG_PATH
  value: "/etc/nim/config/python_jsonl_logging_config.json"
{{- else }}
- name: VLLM_LOGGING_CONFIG_PATH
  value: "/etc/nim/config/python_readable_logging_config.json"
- name: VLLM_NVEXT_LOGGING_CONFIG_PATH
  value: "/etc/nim/config/python_readable_logging_config.json"
{{- end }}
{{- end }}

{{/*
Define probes for single and multi-node templates
*/}}
{{- define "nim-vlm.probes" -}}
{{- if .Values.livenessProbe.enabled }}
{{- with .Values.livenessProbe }}
livenessProbe:
{{- if eq .method "http" }}
  httpGet:
    path: {{ .path }}
    port: {{ $.Values.model.legacyCompat | ternary "health" "http-openai" }}
{{- else if eq .method "script" }}
  exec:
    command:
    {{- toYaml .command | nindent 16 }}
{{- end }}
  initialDelaySeconds: {{ .initialDelaySeconds }}
  periodSeconds: {{ .periodSeconds }}
  timeoutSeconds: {{ .timeoutSeconds }}
  successThreshold: {{ .successThreshold }}
  failureThreshold: {{ .failureThreshold }}
{{- end }}
{{- end }}
{{- if .Values.readinessProbe.enabled }}
{{- with .Values.readinessProbe }}
readinessProbe:
  httpGet:
    path: {{ .path }}
    port: {{ $.Values.model.legacyCompat | ternary "health" "http-openai" }}
  initialDelaySeconds: {{ .initialDelaySeconds }}
  periodSeconds: {{ .periodSeconds }}
  timeoutSeconds: {{ .timeoutSeconds }}
  successThreshold: {{ .successThreshold }}
  failureThreshold: {{ .failureThreshold }}
{{- end }}
{{- end }}
{{- if .Values.startupProbe.enabled }}
{{- with .Values.startupProbe }}
startupProbe:
  httpGet:
    path: {{ .path }}
    port: {{ $.Values.model.legacyCompat | ternary "health" "http-openai" }}
  initialDelaySeconds: {{ .initialDelaySeconds }}
  periodSeconds: {{ .periodSeconds }}
  timeoutSeconds: {{ .timeoutSeconds }}
  successThreshold: {{ .successThreshold }}
  failureThreshold: {{ .failureThreshold }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Define the container ports for NIMs using either legacy triton or current backends
*/}}
{{- define "nim-vlm.ports" -}}
{{- if .Values.model.legacyCompat }}
- containerPort: 8000
  name: http
{{- end }}
{{- if and .Values.healthPort .Values.model.legacyCompat }}
- containerPort: {{ .Values.healthPort }}
  name: health
{{- end }}
{{- if .Values.service.grpc_port }}
- containerPort: 8001
  name: grpc
{{- end }}
{{- if and .Values.metrics.enabled .Values.model.legacyCompat }}
- containerPort: 8002
  name: metrics
{{- end }}
{{- if or .Values.model.openaiPort .Values.model.openai_port }}
- containerPort: {{ .Values.model.openai_port | default .Values.model.openaiPort }}
  name: http-openai
{{- end }}
{{- if or .Values.model.nemoPort .Values.model.nemo_port }}
- containerPort: {{ .Values.model.nemoPort | default .Values.model.nemo_port }}
  name: http-nemo
{{- end }}
{{- end }}

{{/*
Define volume mounts for every nim hosting definition
*/}}
{{- define "nim-vlm.volumeMounts" -}}
- name: model-store
  {{- if .Values.model.legacyCompat }}
  mountPath: {{ .Values.model.nimCache }}
  subPath: {{ .Values.model.subPath }}
  {{- else }}
  mountPath: {{ .Values.model.nimCache }}
  {{- end }}
- mountPath: /dev/shm
  name: dshm
- name: scripts-volume 
  mountPath: /scripts
{{- if .Values.extraVolumeMounts }}
{{- range $k, $v := .Values.extraVolumeMounts }}
- name: {{ $k }}
  {{- toYaml $v | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Volume set for multi-node options
*/}}
{{- define "nim-vlm.multinodeVolumes" -}}
- name: dshm
  emptyDir:
    medium: Memory
- name: scripts-volume
  configMap:
    name: {{ $.Release.Name }}-scripts-configmap
    defaultMode: 0555
- name: model-store
  {{- if $.Values.persistence.enabled }}
  persistentVolumeClaim:
    claimName:  {{ $.Values.persistence.existingClaim | default (include "nim-vlm.fullname" $) }}
  {{- else if $.Values.hostPath.enabled }}
  hostPath:
    path: {{ $.Values.hostPath.path }}
    type: DirectoryOrCreate
  {{- else if $.Values.nfs.enabled }}
  nfs:
    server: {{ $.Values.nfs.server | quote }}
    path: {{ $.Values.nfs.path }}
    readOnly: {{ $.Values.nfs.readOnly }}
  {{- else }}
  emptyDir: {}
  {{- end }}
{{- if $.Values.extraVolumes }}
{{- range $k, $v := $.Values.extraVolumes }}
- name: {{ $k }}
  {{- toYaml $v | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Max replicas to prepare for in certain cases
*/}}
{{- define "nim-vlm.totalMaxReplicas" -}}
{{ ternary .Values.autoscaling.maxReplicas .Values.replicaCount .Values.autoscaling.enabled }}
{{- end }}

{{/*
The .ssh mount dir for multiNode
*/}}
{{- define "nim-vlm.sshDir" -}}
{{ ternary "/root/.ssh" "/opt/nim/llm/.ssh" (eq (int $.Values.podSecurityContext.runAsUser) 0) }}
{{- end }}

{{/*
Executable for multinode deployments -- if using a container 1.1.2 or less, script doesn't exist
*/}}
{{- define "nim-vlm.multiNodeExec" -}}
{{- if regexMatch "^\\d+\\.\\d+\\.\\d+" ( .Values.image.tag | default .Chart.AppVersion ) -}}
{{- $nimver := regexReplaceAll "^(\\d+\\.\\d+\\.\\d+).*" ( .Values.image.tag | default .Chart.AppVersion ) "${1}" -}}
{{- if eq (semver $nimver | (semver "1.1.2").Compare) -1 -}}
/opt/nim/start-mpi-cluster.sh
{{- else -}}
/opt/nim/llm/.venv/bin/python3 -m vllm_nvext.entrypoints.openai.api_server
{{- end -}}
{{- else -}}
/opt/nim/start-mpi-cluster.sh
{{- end -}}
{{- end -}}
