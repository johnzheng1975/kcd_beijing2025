# Securer When Expose Model

## mTLS enabled
- With peerauthentication, enable mTLS.
- [Sample](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/flux_samples/istio_mTLS.yaml)

## Expose Model With Istio Virtual Service
- For model named "sample", service "sample-predictor" will be created automatically. 
- Expose this service by Istio Virtual Service. [Sample](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/helmcharts_samples/securityRelated/virtualservice.yaml)

## How to protect model by JWT token?
