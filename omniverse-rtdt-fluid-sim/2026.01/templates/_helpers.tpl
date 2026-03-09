{{/*
Copyright (c) 2024-2025, NVIDIA CORPORATION.  All rights reserved.

NVIDIA CORPORATION and its licensors retain all intellectual property
and proprietary rights in and to this software, related documentation
and any modifications thereto.  Any use, reproduction, disclosure or
distribution of this software and related documentation without an express
license agreement from NVIDIA CORPORATION is strictly prohibited.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "rtdt.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "rtdt.fullname" -}}
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
{{- define "rtdt.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "rtdt.labels" -}}
helm.sh/chart: {{ include "rtdt.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Kit selector labels
*/}}
{{- define "rtdt.kit.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rtdt.name" . }}-kit
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: kit
{{- end }}

{{/*
Web selector labels
*/}}
{{- define "rtdt.web.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rtdt.name" . }}-web
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: web
{{- end }}

{{/*
AeroNIM selector labels
*/}}
{{- define "rtdt.aeronim.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rtdt.name" . }}-aeronim
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: aeronim
{{- end }}

{{/*
NGC API key secret name
*/}}
{{- define "rtdt.ngcApiSecretName" -}}
{{ include "rtdt.fullname" . }}-ngc-api-key
{{- end }}
