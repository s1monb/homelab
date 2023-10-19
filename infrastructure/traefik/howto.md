# How to add a new ingress

There are three step (Use same subdomain in all steps):
1. Create an ingress-resource. Se `nginx`-example bellow. 
2. Set up the hostname in CloudFlare > Zero Trust > Tunnels > Select your tunnel > Public Hostnames (Remember to check the "no verify tls" option)
3. (optional) If you want to add authentication, add the domain to the application settings in the Access-pane in zero trust (cloudflare) 

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  namespace: nginx
  annotations:
    cert-manager.io/cluster-issuer: cloudflare-issuer
spec:
  tls:
    - hosts:
        -  nginx.valley.no
      secretName: nginx-valley-no-tls
  rules:
    - host: nginx.valley.no
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx
                port:
                  name: web
```