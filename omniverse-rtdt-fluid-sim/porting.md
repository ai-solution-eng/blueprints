# Omniverse RTDT for Fluid Dynamics: PCAI Porting
## Helm chart changes
The helm chart included with the latest revision requires two changes to the chart resources themselves, as well as some additions for PCAI.
### Environment variables
Many PCAI systems are behind a corporate web proxy. The aeronim pod pulls files from the internet, and as such needs the ability to configure the proxy. The `env` section in `deployment-aeronim.yaml` was modified to add `extraEnv` to pass proxy variables
```yaml
          env:
            - name: NGC_API_KEY
              valueFrom:
                secretKeyRef:
                  name: {{ include "rtdt.ngcApiSecretName" . }}
                  key: NGC_API_KEY
            {{- range $key, $value := .Values.aeronim.extraEnv }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
```

### Web init container
The web pod has an init container that polls the kit app signaling port and will not start until the kit app on the signaling port returns http 200. However, even though the kit app is fully ready (at least in our setup) it will never return http 200 on the webrtc signaling port and the main pod will never start. To accommodate this, the curl command was very slightly changed to reflect below:
```yaml
      initContainers:
        # Wait for Kit signaling to be available
        - name: wait-for-kit
          image: curlimages/curl:8.5.0
          imagePullPolicy: IfNotPresent
          command:
            - /bin/sh
            - -c
            - |
              echo "Waiting for Kit to be ready..."
              until curl -s --max-time 5 http://{{ include "rtdt.fullname" . }}-kit:{{ .Values.kit.ports.signaling }}/ > /dev/null 2>&1; do
                echo "  Kit not ready yet, retrying in 10s..."
                sleep 10
              done
              echo "Kit is ready."
```

### PCAI-related additions
The `ezua` directory was added to provide additional PCAI resources
```
├── Chart.yaml
├── templates
│   ├── _helpers.tpl
│   ├── configmap-nginx.yaml
│   ├── deployment-aeronim.yaml
│   ├── deployment-kit.yaml
│   ├── deployment-web.yaml
│   ├── ezua
│   │   ├── gateway.yaml
│   │   ├── kyverno.yaml
│   │   └── virtualservice.yaml
│   ├── NOTES.txt
│   ├── pvc-kit.yaml
│   ├── secret-ngc.yaml
│   ├── service-aeronim.yaml
│   ├── service-kit.yaml
│   └── service-web.yaml
└── values.yaml
```

Typically, we add both a `VirtualService` and a Kyverno `ClusterPolicy` to the vendor helm chart. The `VirtualService` configures the istio `Gateway` with an external route so that the web app is available to users outside of the PCAI cluster. The included AIE `Gateway` terminates TLS at the `Gateway` and is HTTPS/TLS only. This is an issue for us in this Blueprint because the kit app uses Websockets and is configured for host networking. If the web app is delivered to the user with TLS, it cannot then connect to the insecure websocket on the host network - this connection is blocked for security reasons (cannot connect to an insecure Websocket from a tls website). 

The easiest way around this was for us to add an additional, non-TLS `Gateway` to serve the web connection. 

>[!NOTE]
>At first, I tried also adding the kit signaling port as a route to istio, but then the signaling server and kit webrtc server would be different (signaling server would be the ingress domain name, and kit would be the host network IP), and the app does not support this.

Finally, a Kyverno `ClusterPolicy` is added. This adds PCAI vendor labels to all workload pods. This is required (in AIE 1.11) for GPU workload admission.

>[!NOTE]
>There are 2 options here: use `vendor` as `hpe-ezua/app` or use the actual chart name (`{{ .Chart.Name }}`). If you use the chart name, you need to (in AIE 1.11 only) make the following configmap change in the cluster prior to or just after deploying the chart:
> `k patch cm -n ezua-system gpu-partition-configuration --type merge -p '{"data":{"rtdt-fluid-sim.global": "small, medium, large, whole"}}'`
