#!/bin/bash

kubectl get nodes
kubectl get svc
cat consul-helm/demo.values.yaml
helm install ./consul-helm -f ./consul-helm/demo.values.yaml --name consul
kubectl get svc