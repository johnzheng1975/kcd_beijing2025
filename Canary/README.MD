# Model Canary

## Requriment
- Implement "model canary" in KServe without Knative
- Ensure the implementation is simple, robust, and easy to maintain.

## Helm Chart Design
- **Existing Chart**: The previous Helm chart, named `kserve-model`, includes templates for features such as authentication, HPA (Horizontal Pod Autoscaling), rate limiting, and more.
- **New Chart**: Introduce a new Helm chart named `kserve-general`, which includes:
  - A Helm release for the primary model deployment.
  - A Helm release for the canary model deployment.
  - An Istio `VirtualService` to manage traffic splitting between primary and canary releases.
  ![Helm Chart Template](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/Canary/diagrams/helmChart-Canary.png)

### Introduction of helm release of primary and canary
 They are same except name, just create two instances of kserve-model helm chart. [Code](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/Canary/helmchart/kserve-general/templates/hr-primary.yaml)

 ```
 apiVersion: helm.toolkit.fluxcd.io/v2
 kind: HelmRelease
 metadata:
   namespace: {{ .Release.Namespace }}
   name: {{ .Release.Name }}-canary  # or -primary
 spec:
   chart:
      spec:
       chart: kserve-model
       sourceRef:
         kind: GitRepository
         name: charts-git
         namespace: flux-system
   values:
     {{- with .Values.inferenceservice }}
     inferenceservice:
     {{- toYaml . | nindent 6 }}
     {{- end }}
     {{- with .Values.exposeModel }}
     exposeModel:
     {{- toYaml . | nindent 6 }}
     {{- end }}
   valuesFrom:  #Get env, region, etc form ConfigMap file.
     - kind: ConfigMap
       name: namespace-envioroment
       valuesKey: env.yaml
 ```

 `Question 1`: Why we create two helm release of kserve-model? instead of create two inference service (primary / canary) inside kserve-model helm chart?

 `Answer`: Each inference service has its own hpa, ratelimit, etc. If we create two inference service inside one helm chart and share hpa, ratelimit, authentication between them, it will be complex and difficult to maintain. 

 `Question 2`: how to access primary and canary inference service directly, for testing purpose?

 `Answer`: The have seperate domain, like:
 - https://sklearn-primary-predictor-myproject.api.sandbox-uw2.sample.io/v1/models/sklearn:predict
 - https://sklearn-canary-predictor-myproject.api.sandbox-uw2.sample.io/v1/models/sklearn:predict


###  Introduction of virutal service
 It is for traffic split between primary and canary. [Code](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/Canary/helmchart/kserve-general/templates/virtualservice.yaml)

 ```
 apiVersion: networking.istio.io/v1
 kind: VirtualService
 metadata:
   name: {{ .Release.Name }}-predictor
   namespace: {{ .Release.Namespace }}
 spec:
   gateways:
   - istio-system/sample-gateway
   hosts:
   - {{ .Release.Name }}-predictor-{{ .Release.Namespace }}.api.{{ .Values.env }}-{{ .Values.region }}.sample.io
   http:
   - match:
     - uri:
         regex: ^/.+$
     name: {{ .Release.Name }}-predictor
     route:
     - destination:
         host: {{ .Release.Name }}-primary-predictor
         port:
           number: 80
       weight: {{ .Values.primaryLoad }}
     - destination:
         host: {{ .Release.Name }}-canary-predictor
         port:
           number: 80
       weight: {{ sub 100 .Values.primaryLoad }}
 ```

 It has a general domain for customers, like:
 - https://sklearn-predictor-myproject.api.sandbox-uw2.sample.io/v1/models/sklearn:predict

## Previous helm chart change
The changes for Existing chart is very less, as below:
1. Make model name is same for primary/ canary model, thus predict path will be same.
2. Make sure primary model use old `Storage URI`, canary model use new `Storage URI`

![Previous model chart code change](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/Canary/diagrams/kserve-model-change-for-canary.png)


## Flux code to render helm chart
- As below, all parameters are share except [Code](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/Canary/flux/sklearn.yaml)
  - primaryLoad - The percentage of primary model
  - storageUri, newStorageUri - For old and new model URI
  
  ```
  apiVersion: helm.toolkit.fluxcd.io/v2
  kind: HelmRelease
  metadata:
    namespace: sample-dev
    name: sklearn
  spec:
    interval: 1m
    releaseName: sklearn
    chart:
      spec:
        chart: kserve-general
        sourceRef:
          kind: GitRepository
          name: charts-git
          namespace: flux-system
    install:
      remediation:
        retries: 1
    upgrade:
      remediation:
        retries: 1
    values:
      primaryLoad: 60   ### Important
      inferenceservice:
        predictor:
          model:
            modelFormat:
              name: sklearn
            storageUri: "gs://kfserving-examples/models/sklearn/1.0/model"
            newStorageUri: "gs://kfserving-examples/models/sklearn/1.0/model-2"   ### Important
      exposeModel:
        enabled: true
        type: "api"
      replicaCount: 2
      autoscaling:
        maxReplicaCount: 4

  ```

## Test
Test as below, test result is as expected.

```
# Three helm release, sklearn is the parent helm release;
$ k get hr -n sample-dev | grep sklearn
sklearn                  15h    True    Helm install succeeded for release sample-dev/sklearn.v1 with chart kserve-general@0.3.0
sklearn-canary           15h    True    Helm install succeeded for release sample-dev/sklearn-canary.v1 with chart kserve-model@0.3.0
sklearn-primary          15h    True    Helm install succeeded for release sample-dev/sklearn-primary.v1 with chart kserve-model@0.3.0

# Two inference service is created, one for primary and one for canary.
$ k get isvc -n sample-dev | grep sklearn
sklearn-canary    http://sklearn-canary-sample-dev.example.com    True                                                                  15h
sklearn-primary   http://sklearn-primary-sample-dev.example.com   True                                                                  15h
 
# Two pods, one for primary and one for canary
$ k get pods -n onecloud-dev | grep sklearn
sklearn-canary-predictor-57c577ffb5-cxljn   2/2     Running   0          53m
sklearn-primary-predictor-6fc8d4f6-2cxfl    2/2     Running   0          50m

# Two service, one for primary and one for canary
$ k get svc -n onecloud-dev | grep sklearn
sklearn-canary-predictor    ClusterIP   172.20.172.136   <none>        80/TCP            15h
sklearn-primary-predictor   ClusterIP   172.20.217.108   <none>        80/TCP            15h
 
# Three virtual service, the main one is for customers accessing. The other two is for testing.
$ k get vs -n sample-dev | grep sklearn
sklearn-predictor           ["istio-system/apigee-gateway"]    ["sklearn-predictor-sample-dev.api.sandbox-uw2.hpsample.io"] 
sklearn-canary-predictor    ["istio-system/apigee-gateway"]    ["sklearn-canary-predictor-sample-dev.api.sandbox-uw2.hpsample.io"]  
sklearn-primary-predictor   ["istio-system/apigee-gateway"]    ["sklearn-primary-predictor-sample-dev.api.sandbox-uw2.hpsample.io"]        
 
 
# Test with primary domain
$ curl -X POST "https://sklearn-primary-predictor-sample-dev.api.sandbox-uw2.hpsample.io/v1/models/sklearn:predict"  -H "Content-Type: application/json"   -d '{"instances": [[1.0, 2.0, 3.0, 4.0]]}'
{"predictions":[2]}

# Test with canary domain
$ curl -X POST "https://sklearn-canary-predictor-sample-dev.api.sandbox-uw2.hpsample.io/v1/models/sklearn:predict"  -H "Content-Type: application/json"   -d '{"instances": [[1.0, 2.0, 3.0, 4.0]]}'
{"predictions":[2]}

# Test 100 times with customers' domain
$ for i in {1..100}; do curl -X POST "https://sklearn-predictor-onecloud-dev.api.sandbox-uw2.hponecloud.io/v1/models/sklearn:predict"  -H "Content-Type: application/json"   -d '{"instances": [[1.0, 2.0, 3.0, 4.0]]}'; done;
{"predictions":[2]}{"predictions":[2]}{"predictions":[2]}{"predictions":[2]} ... ...

# Expect value is 60 customers testing + 1 test =  61. Actual value is 62, they are similar. Test Pass.
$ k logs -n onecloud-dev sklearn-primary-predictor-6fc8d4f6-2cxfl  | grep "POST /v1/models/sklearn%3Apredict HTTP/1.1" | wc -l
62


# Expect value is 40 customers testing + 1 test =  41. Actual value is 40, they are similar. Test pass.
$ k logs -n onecloud-dev sklearn-canary-predictor-57c577ffb5-cxljn | grep "POST /v1/models/sklearn%3Apredict HTTP/1.1" | wc -l
40

```
