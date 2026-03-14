{{/*
Expand the name of the chart.
*/}}
{{- define "iptv-parser.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "iptv-parser.fullname" -}}
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
Common labels
*/}}
{{- define "iptv-parser.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "iptv-parser.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "iptv-parser.selectorLabels" -}}
app.kubernetes.io/name: {{ include "iptv-parser.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name
*/}}
{{- define "iptv-parser.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "iptv-parser.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Database environment variables (cross-namespace)
*/}}
{{- define "iptv-parser.dbEnv" -}}
- name: DB_HOST
  value: {{ .Values.postgresql.host | quote }}
- name: DB_PORT
  value: {{ .Values.postgresql.port | quote }}
- name: DB_NAME
  value: {{ .Values.postgresql.database | quote }}
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.existingSecret }}
      key: {{ .Values.postgresql.usernameKey }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.existingSecret }}
      key: {{ .Values.postgresql.passwordKey }}
{{- end }}

{{/*
IPTV playlist/EPG URLs from a manually created Kubernetes Secret
*/}}
{{- define "iptv-parser.iptvEnv" -}}
- name: PLAYLIST_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.iptv.existingSecret }}
      key: {{ .Values.iptv.playlistUrlKey }}
- name: EPG_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.iptv.existingSecret }}
      key: {{ .Values.iptv.epgUrlKey }}
{{- end }}
