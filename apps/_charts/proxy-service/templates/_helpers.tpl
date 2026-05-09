{{/*
Fail fast if a required value is missing — easier to debug than a deployment
that quietly came up with the wrong name.
*/}}
{{- define "proxy-service.name" -}}
{{- if not .Values.name -}}
{{- fail "values.name is required (no default)" -}}
{{- end -}}
{{- .Values.name -}}
{{- end -}}

{{- define "proxy-service.host" -}}
{{- if not .Values.ingress.host -}}
{{- fail "values.ingress.host is required when ingress.enabled is true" -}}
{{- end -}}
{{- .Values.ingress.host -}}
{{- end -}}
