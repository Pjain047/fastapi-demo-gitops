{{/* Expand the chart name. */}}
{{- define "fastapi-demo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Create a fully qualified resource name. */}}
{{- define "fastapi-demo.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if contains (include "fastapi-demo.name" .) .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "fastapi-demo.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/* Select the namespace used by namespaced resources. */}}
{{- define "fastapi-demo.namespace" -}}
{{- default .Release.Namespace .Values.namespace.name }}
{{- end }}

{{/* Common labels. */}}
{{- define "fastapi-demo.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app: {{ include "fastapi-demo.name" . }}
app.kubernetes.io/name: {{ include "fastapi-demo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Selector labels. */}}
{{- define "fastapi-demo.selectorLabels" -}}
app: {{ include "fastapi-demo.name" . }}
app.kubernetes.io/name: {{ include "fastapi-demo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
