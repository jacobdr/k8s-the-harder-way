#!/usr/bin/env bash
# kubectl apply -f - <<EOF
# ---
# apiVersion: apps/v1
# kind: Deployment
# metadata:
#   name: nginx
#   labels:
#     app: nginx
# spec:
#   replicas: 1
#   selector:
#     matchLabels:
#       app: nginx
#   template:
#     metadata:
#       labels:
#         app: nginx
#     spec:
#       containers:
#       - name: nginx
#         image: nginx:1.14.2
#         ports:
#         - containerPort: 80
# ---
# apiVersion: v1
# kind: Service
# metadata:
#   namespace: default
#   name: nginx
# spec:
#   selector:
#     app: nginx
#   ports:
#     - port: 80
#       targetPort: 80
#   type: LoadBalancer
# EOF

# # kubectl apply -f - <<EOF
# # ---
# # apiVersion: networking.k8s.io/v1
# # kind: Ingress
# # metadata:
# #   namespace: argocd
# #   name: ingress-argocd-http
# #   annotations:
# #     nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
# #     nginx.ingress.kubernetes.io/proxy-ssl-secret: "argocd/argocd-secret"
# #     nginx.ingress.kubernetes.io/proxy-ssl-verify: "off"
# #     nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
# # spec:
# #   ingressClassName: nginx
# #   rules:
# #   - host: argocd.k8s.local
# #     http:
# #       paths:
# #       - path: /
# #         pathType: Prefix
# #         backend:
# #           service:
# #             name: argocd-server
# #             port:
# #               name: https
# # EOF
