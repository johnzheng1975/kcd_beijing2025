# Securer When Expose Model


## mTLS enabled
- With peerauthentication, enable mTLS.
- [Sample](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/flux_samples/istio_mTLS.yaml)


## Expose Model With Istio Virtual Service
- For model named "sample", service "sample-predictor" will be created automatically. 
- Expose this service by Istio Virtual Service. [Sample](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/helmcharts_samples/SecurerWhenExposeModel/virtualservice.yaml)


## How to protect model by JWT token?
- Here is the simplest sample

### External Access (Other Namespaces) Need Token
- Create on namespace level, all services in this namespace share this one.
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
- Create on namespace level, all services in this namespace share this one.
  ```
  # Just for sample. In real project, developer can configure whether need token.
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
- Create on service level.
- [Sample](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/flux_samples/istio_mTLS.yaml)

### Define CUSTOM AuthorizationPolicy for further authz [Optional]
- As [Sample](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/helmcharts_samples/SecurerWhenExposeModel/authorizationpolicy-custom.yaml), add custom authorizationpolicy, for further authz.
- For details, please view my previous introduction. [Details] (https://github.com/johnzheng1975/istiocon2023/tree/main/samples/AuthenticationAndAuthorization/ExtAuthz-AuthzCustom)
- Since all request header/ body will be sent to external authz service for verify, you can use any validation logic you like.