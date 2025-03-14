# Model Canary

## Requriment
- Implement "model canary" in KServe without Knative
- It should be simple, strong and easy to maintain

## Design of helm chart
- Previous helm chart name is kserve-model, include all template, like authentication, hpa, ratelimit...
- Add a new helm chart named kserve-general, include
    - helm release of primary
    - helm release of canary
    - virtual service to split traffic

![Helm Chart Template](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/Canary/diagrams/helmChart-Canary.png)
  

### Introduction of helm release of primary and canary
    They are same except name, just create two instances of kserve-model helm chart. [Code]()
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

     Question 1: Why we create two helm release of kserve-model? instead of create two inference service (primary / canary) inside kserve-model helm chart?

     Answer: Each inference service has its own hpa, ratelimit, etc. If we create two inference service inside one helm chart and share hpa, ratelimit, authentication between them, it will be complex and difficult to maintain. 

     Question 2: how to access primary and canary inference service directly, for testing purpose?

     Answer: The have seperate domain, like:
     - https://sklearn-primary-predictor-myproject.api.sandbox-uw2.sample.io/v1/models/sklearn:predict
     - https://sklearn-canary-predictor-myproject.api.sandbox-uw2.sample.io/v1/models/sklearn:predict


###  Introduction of virutal service
    It is for traffic split between primary and canary. [Code]()
     ```yaml
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

## Flux code to render helm chart
   ```
   ```

## Test
- 
