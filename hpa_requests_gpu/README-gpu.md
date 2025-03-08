## Custom metrics with prometheus adapter (GPU usage)

### Pre-condition 
- Please go through [README-requestsPerSecond.md](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/hpa_requests_gpu/README-requestsPerSecond.md), to understand the basic concept of "HPA based to custom metrics".

### Requirments
- Support Horizontal Pod Autoscaling based on GPU Usage.

### Solution
1. Install "Prometheus adapter" to support HPA based on custom metric, as I introduced in [README-requestsPerSecond.md](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/hpa_requests_gpu/README-requestsPerSecond.md)
2. Collecting GPU Metrics
3. Implement HPA based on GPU usage


### Collecting GPU Metrics

- [NVIDIA Data Center GPU Manager (DCGM)](https://developer.nvidia.com/blog/monitoring-gpus-in-kubernetes-with-dcgm/) can provide GPU metrics.

- [NVIDIA gpu-operator](https://github.com/NVIDIA/gpu-operator) automate the management of all NVIDIA software components needed to provision GPU.

   So, install gpu-operator can cover NVIDIA Device Plugin, DCGM.

   [Sample Installation Code](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/flux_samples/gpu-operator_installation.yaml)
   ```
   ---
   apiVersion: source.toolkit.fluxcd.io/v1
   kind: HelmRepository
   metadata:
     name: gpu-operator
     namespace: infra
   spec:
     interval: 10m
     url: https://helm.ngc.nvidia.com/nvidia
   ---
   apiVersion: helm.toolkit.fluxcd.io/v2
   kind: HelmRelease
   metadata:
     name: gpu-operator
     namespace: infra
   spec:
     interval: 5m # The interval at which to reconcile the Helm release
     timeout: 10m
     releaseName: gpu-operator
     chart:
       spec:
         chart: gpu-operator
         version: v24.9.2 # https://github.com/NVIDIA/gpu-operator/releases
         sourceRef:
           kind: HelmRepository
           name: gpu-operator
         interval: 10m
     values:
       nodeSelector:      
         node-pool: gpu
       toolkit:
         version: "v1.13.1-centos7"
   ```

- After `NVIDIA gpu-operator` is installed, query in Prometheus.
   - You got `DCGM_FI_DEV_GPU_UTIL` for "HPA Based on GPU Usage"
   
     ![GPU UTIL](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/hpa_requests_gpu/diagrams/gpu-metrics-prometheus-gpuUtil.png)

   - You also got other GPU related metrics.
   
     ![GPU All](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/hpa_requests_gpu/diagrams/gpu-metrics-prometheus-all.png)

### Implement HPA based on GPU usage
- Use prometheus adapter configmap for this example
- Install AI service which use gpu
- Prepare HPA configure for this AI service
- Test Result: HPA based on GPU usage

#### Use prometheus adapter configmap for this example
- Prepare current adapter configmap with below, save as cm-prometheus-adapter-gpu.yaml.
  ```
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
      - metricsQuery: avg(avg_over_time(<<.Series>>{<<.LabelMatchers>>}[1m])) by (<<.GroupBy>>)
        name:
          as: gpu_utilization
          matches: DCGM_FI_DEV_GPU_UTIL
        resources:
          overrides:
            exported_namespace:
              resource: namespace
            pod:
              resource: pod
        seriesQuery: '{__name__=~"^DCGM_FI_DEV_GPU_UTIL$", app="nvidia-dcgm-exporter", container="service",
          service="nvidia-dcgm-exporter"}'
  kind: ConfigMap
  metadata:
    name: prometheus-adapter
    namespace: infra
  ```

- Replace this configmap, and restart.
  ```
  # Backup old configmap
  $ kubectl  get cm prometheus-adapter -oyaml > bk_cm_prometheus_adaptor.yaml
  
  # Replace for this example.
  $ kubectl replace -f cm-prometheus-adapter-gpu.yaml --force

  # Restart prom-adapter pods
  $ kubectl rollout restart deployment prometheus-adapter -n default
  ```

#### Install AI service which use gpu 
- Prepare AI service which use gpu.
- Deploy AI service.


#### Configuring the HPA with Istio metrics

You can define a HPA that will scale the aiservice workload based on gpu utilization。

For testing purpose, set average Value is 60%. minReplicas is 1, maxReplicas is 3.

Prepare HPA file, save as hpa.yaml
```
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: aiservice
  namespace: zone-itg
spec:
  maxReplicas: 3
  metrics:
  - pods:
      metric:
        name: gpu_utilization
      target:
        averageValue: "60"
        type: Value
    type: Pods
  minReplicas: 1
  scaleTargetRef:
    apiVersion: argoproj.io/v1alpha1
    kind: Rollout
    name: aiservice
```

Create the HPA with:

```bash
kubectl apply -f ./hpa.yaml
```

#### Test Result: HPA based on GPU usage
- HPA based on GPU usage works well, as below:

  ![GPU Node Auto Scaling Test Result](https://github.com/johnzheng1975/kcd_beijing2025/blob/main/hpa_requests_gpu/diagrams/hpa-example-gpu.png)
 
