{{- define "serviceAuth.audiences" -}}
      {{- if and .Values.exposeModel.jwtVerify .Values.exposeModel.jwtVerify.Audiences }}
        {{- print "  audiences:\n" }}
        {{- range .Values.exposeModel.jwtVerify.Audiences }}
          {{- print "  - "  .  "\n" }}
        {{- end }}
      {{- end }}
{{- end }}

{{- define "serviceAuth.others" -}}
      {{- if and .Values.exposeModel.jwtVerify }}
        {{- print "  forwardOriginalToken: true\n" }}
      {{- end }}
{{- end }}

{{- define "serviceAuth.jwt_jwks_issuer" -}}
    ... ...

    {{- else if and (eq .Values.regionCode "uw2") (eq .Values.env "stg") }}
      {{- print "- issuer: https://xxxxxxxxxxxxxx" }}
      {{- print "  jwksUri: https://xxxxxx/us2/stg/jwks.json\n" }}
      {{- include "serviceAuth.audiences" . }}
	  {{- include "serviceAuth.others" . }}

    {{- else if and (eq .Values.regionCode "ec1") (eq .Values.env "stg") }}
      {{- print "- issuer: https://xxxxxxxxxxxxxx" }}
      {{- print "  jwksUri: https://xxxxxx/ec1/stg/jwks.json\n" }}
      {{- include "serviceAuth.audiences" . }}
	  {{- include "serviceAuth.others" . }}

    ... ...

    {{- else }}
      {{ fail "Incorrect region or env!" }}
    {{- end }}
{{- end }}
