{{/*
Expand the name of the chart.
*/}}
{{- define "kokoro-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kokoro-server.fullname" -}}
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
{{- define "kokoro-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kokoro-server.labels" -}}
helm.sh/chart: {{ include "kokoro-server.chart" . }}
{{ include "kokoro-server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kokoro-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kokoro-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "kokoro-server.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kokoro-server.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
The Secret holding the API key, and the key within it. One of two sources: a
Secret the operator manages, or one this chart creates from apiKey.value.
Asking for both is a mistake worth failing on — silently preferring one would
leave the other looking applied.
*/}}
{{- define "kokoro-server.apiKeySecretName" -}}
{{- $k := .Values.kokoroTTS.apiKey -}}
{{- if and $k.existingSecret $k.value -}}
{{- fail "kokoroTTS.apiKey: set existingSecret OR value, not both" -}}
{{- end -}}
{{- if $k.existingSecret -}}
{{- $k.existingSecret -}}
{{- else -}}
{{- printf "%s-api-key" (include "kokoro-server.fullname" .) -}}
{{- end -}}
{{- end }}

{{- define "kokoro-server.apiKeySecretKey" -}}
{{- if .Values.kokoroTTS.apiKey.existingSecret -}}
{{- .Values.kokoroTTS.apiKey.secretKey -}}
{{- else -}}
api-key
{{- end -}}
{{- end }}

{{/*
The PVC backing the data directory: an existing claim when one is named,
otherwise the one this chart creates.
*/}}
{{- define "kokoro-server.dataClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "kokoro-server.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
Where the certificate and key are read from. A mounted Secret wins; then an
explicit path; otherwise nothing, and the server falls back to its own default
under the data directory — which is where it writes a self-signed pair.
*/}}
{{- define "kokoro-server.tlsCertPath" -}}
{{- if .Values.tls.existingSecret -}}
/etc/kokoro/tls/{{ .Values.tls.certSecretKey }}
{{- else -}}
{{- .Values.tls.certFile -}}
{{- end -}}
{{- end }}

{{- define "kokoro-server.tlsKeyPath" -}}
{{- if .Values.tls.existingSecret -}}
/etc/kokoro/tls/{{ .Values.tls.keySecretKey }}
{{- else -}}
{{- .Values.tls.keyFile -}}
{{- end -}}
{{- end }}

{{/*
Resources with the accelerator request merged in. `resources` stays free-form
for CPU and memory; the GPU key comes from the `gpu` block, so the vendor
resource name is a value rather than a literal buried in a defaults file.
*/}}
{{- define "kokoro-server.resources" -}}
{{- $r := deepCopy (.Values.kokoroTTS.resources | default dict) -}}
{{- if .Values.gpu.enabled -}}
{{- $key := required "gpu.resourceKey is required when gpu.enabled" .Values.gpu.resourceKey -}}
{{- $limits := deepCopy (get $r "limits" | default dict) -}}
{{- $_ := set $limits $key .Values.gpu.count -}}
{{- $_ := set $r "limits" $limits -}}
{{- $requests := deepCopy (get $r "requests" | default dict) -}}
{{- $_ := set $requests $key .Values.gpu.count -}}
{{- $_ := set $r "requests" $requests -}}
{{- end -}}
{{- toYaml $r -}}
{{- end }}

{{/*
A probe from values, with the scheme corrected when the server speaks HTTPS.
Without this, enabling TLS turns every probe into a plaintext request against
an SSL listener and the pod never goes ready — a failure that reads as a broken
application rather than a misconfigured probe.
*/}}
{{- define "kokoro-server.probe" -}}
{{- $p := deepCopy .probe -}}
{{- if and .ctx.Values.tls.enabled (hasKey $p "httpGet") -}}
{{- $_ := set (get $p "httpGet") "scheme" "HTTPS" -}}
{{- end -}}
{{- toYaml $p -}}
{{- end }}
