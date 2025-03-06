## Custom metrics with prometheus adapter
- Refer to "https://github.com/stefanprodan/istio-hpa", which use kube-metrics-adapter. However, we use rometheus adapter in this example since it is more popular.
- Use Istio metrics "istio_requests_total", create custom metrics, for HPA.
- The hpa is based on requests per second.

### Architecture diagram
![Istio HPA](https://raw.githubusercontent.com/stefanprodan/istio-hpa/master/diagrams/istio-hpa-overview.png)

### Docs Reference
- https://github.com/prometheus-community/helm-charts/tree/main/charts
- https://github.com/kubernetes-sigs/prometheus-adapter/blob/master/docs/walkthrough.md

### Installation
- Pre-condition: Prometheus is installed.
- Install prometheus adapter. 
  ```
  # helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  # helm repo update
  # helm install prometheus  prometheus-community/prometheus
  
  # Install prometheus, with prometheus.url, prometheus.port.
  $ helm install prometheus-adapter prometheus-community/prometheus-adapter  --set prometheus.url=http://prometheus-server.default.svc.cluster.local    --set prometheus.port=80

  # Verify 
  $ helm ls -A
    NAME                    NAMESPACE       REVISION        UPDATED              STATUS   CHART                      APP VERSION
    prometheus-adapter      default         1               2025-02-05 17:58:01  deployed prometheus-adapter-4.11.0  0.12.0 
  ```

### Replace prometheus adapter for this example
- Prepare current adapter configmap with below, save as cm-prometheus-adapter.yaml.
  ```
  # kubectl  get cm prometheus-adapter -oyaml
  apiVersion: v1
  data:
    config.yaml: |
      rules:
      - metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>}[2m])) by (<<.GroupBy>>)'
        name:
          matches: "istio_requests_total"
          as: "requests_per_second"
        resources:
          overrides:
            namespace:
              resource: namespace
            pod:
              resource: pod
        seriesQuery: istio_requests_total{pod!="", namespace!=""}
  kind: ConfigMap
  metadata:
    name: prometheus-adapter
    namespace: default
  ```

- Replace this configmap, and restart.
  ```
  # Backup old configmap
  $ kubectl  get cm prometheus-adapter -oyaml > bk_cm_prometheus_adaptor.yaml
  
  # Replace for this example.
  $ kubectl replace -f cm-prometheus-adapter.yaml --force  

  # Restart prom-adapter pods
  $ kubectl rollout restart deployment prometheus-adapter -n default
  ```


### Installing the demo app
 
First create a `test` namespace with Istio sidecar injection enabled:

```bash
kubectl apply -f ./namespaces/
```

Create the podinfo deployment and ClusterIP service in the `test` namespace:

```bash
kubectl apply -f ./podinfo/deployment.yaml,./podinfo/service.yaml
```

In order to trigger the auto scaling, you'll need a tool to generate traffic.
Deploy the load test service in the `test` namespace:

```bash
kubectl apply -f ./loadtester/
```

Verify the install by calling the podinfo API.
Exec into the load tester pod and use `hey` to generate load for a couple of seconds:

```bash
export loadtester=$(kubectl -n test get pod -l "app=loadtester" -o jsonpath='{.items[0].metadata.name}')
kubectl -n test exec -it ${loadtester} -- sh

~ $ hey -z 10s -c 10 -q 2 http://podinfo.test:9898

Summary:
  Total:	10.0138 secs
  Requests/sec:	19.9451

Status code distribution:
  [200]	200 responses

  $ exit
```

The podinfo [ClusterIP service](https://github.com/stefanprodan/istio-hpa/blob/master/podinfo/service.yaml)
exposes port 9898 under the `http` name. When using the http prefix, the Envoy sidecar will
switch to L7 routing and the telemetry service will collect HTTP metrics.

### Querying the Istio metrics

The Istio telemetry service collects metrics from the mesh and stores them in Prometheus. One such metric is
`istio_requests_total`, with it you can determine the rate of requests per second a workload receives.

This is how you can query Prometheus for the req/sec rate received by podinfo in the last two minute:

```sql
   sum(rate(istio_requests_total{namespace="test",pod=~".*"}[2m])) by (namespace, pod)
```


### Configuring the HPA with Istio metrics

Using the req/sec query you can define a HPA that will scale the podinfo workload based on the number of requests
per second that each instance receives:

Prepare HPA file, save as hpa.yaml
```
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: podinfo
  namespace: test
spec:
  maxReplicas: 20
  metrics:
  - pods:
      metric:
        name: requests_per_second 
      target:
        averageValue: 5
        type: Value
    type: Pods
  minReplicas: 1
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
```
 

The above configuration will instruct the Horizontal Pod Autoscaler to scale up the deployment when the average traffic
load goes over 5 req/sec per replica.

Create the HPA with:

```bash
kubectl apply -f ./hpa.yaml
```


### Autoscaling based on HTTP traffic

To test the HPA you can use the load tester to trigger a scale up event.

Exec into the tester pod and use `hey` to generate load for a 5 minutes:

```bash
kubectl -n test exec -it ${loadtester} -- sh

~ $  hey -z 500s -c 10 -q 2 http://podinfo.test:9898
```
Press ctrl+c then exit to get out of load test terminal if you wanna stop prematurely.
 

### After muinutes, the replicas go upper to 4.  (20 / 5 = 4)
- In k8s command:
```
# kubectl  get hpa -n test
NAME      REFERENCE            TARGETS     MINPODS   MAXPODS   REPLICAS   AGE
podinfo   Deployment/podinfo   484m/500m   1         20        4          14h
```
 

You can find some deploy to show metrics in hpa, and scale down. This is fine and as design.
 
