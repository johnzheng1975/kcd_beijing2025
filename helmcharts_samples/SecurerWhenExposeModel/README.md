# Securer When Expose Model

## mTLS enabled
- With peerauthentication, enable mTLS.
- [Sample](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/flux_samples/istio_mTLS.yaml)

## Expose Model With Istio Virtual Service
- For model named "sample", service "sample-predictor" will be created automatically. 
- Expose this service by Istio Virtual Service. [Sample](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/helmcharts_samples/securityRelated/virtualservice.yaml)

## How to protect model by JWT token?

### External Access (Other Namespaces) Need Token
```
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: {{ .Release.Namespace }}
  namespace: {{ .Release.Namespace }}
spec:
  action: ALLOW
  rules:
  - from:
    - source:
        namespaces:
        - {{ .Release.Namespace }}
    when:
    - key: request.auth.principal
      values: ["*"]
```

### Same Namespace Need Not Token
```
# Just for sample.
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: {{ .Release.Namespace }}
  namespace: {{ .Release.Namespace }}
spec:
  action: ALLOW
  rules:
  - from:
    - source:
        namespaces:
        - {{ .Release.Namespace }}
```

### Define RequestAuthentication for TOKEN Verify
- [Sample](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/flux_samples/istio_mTLS.yaml)

### Define CUSTOM AuthorizationPolicy
- As 