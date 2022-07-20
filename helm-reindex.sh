#!/bin/bash

helm package helm/uitstor -d helm-releases/

helm repo index --merge index.yaml --url https://charts.min.io .
