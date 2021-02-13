#!/bin/bash

. ~/.k8s_shortcuts

# Get the HELM 3 Version
HV="$(helm3 version --short | sed -e 's/\+.*$//g' -e 's/v//g')"

[[ "${HV}" < "3.2.0" ]] && echo "Error:  Must have helm v3.2.0 or higher" && exit 

# Get Namespace Name 
NAMESPACE=${1:-none}
[[ "${NAMESPACE}" == 'none' ]] && echo "No Namespace chosen" && exit || echo Namespace to be installed/updated: "${NAMESPACE}"

# Process HELM3 Chart
if  $(kubectl get namespaces "${NAMESPACE}" 2>/dev/null | grep -v grep | grep "${NAMESPACE}" >/dev/null) ; then
  helm3 upgrade "${NAMESPACE}"  . --namespace="${NAMESPACE}" --set namespace="${NAMESPACE}"  
else
  helm3 upgrade --install "${NAMESPACE}" .  --create-namespace --namespace "${NAMESPACE}" --set namespace="${NAMESPACE}"  
fi


# Gather Token
export TOKEN=`kubectl --namespace "${NAMESPACE}" get secrets -o json | \
 jq '.items[] | select(.metadata.annotations["kubernetes.io/service-account.name"] != "")  | select(.metadata.annotations["kubernetes.io/service-account.name"] == ("deployer"))' | \
 jq '.data.token' --raw-output | base64 -D`

export CA=`kubectl --namespace "${NAMESPACE}" get secrets -o json | \
 jq '.items[] | select(.metadata.annotations["kubernetes.io/service-account.name"] != "")  | select(.metadata.annotations["kubernetes.io/service-account.name"] == ("deployer"))' | \
 jq '.data."ca.crt"' --raw-output `

# Get Cluster Name
export CLUSTER=`kubectl config view --minify -o "jsonpath={.contexts[].context.cluster}"`

# Set Credentials

CONTEXT="${NAMESPACE}-deployer"
KC="--kubeconfig ${CONTEXT}.config"

#touch "${CONTEXT}.config"
kubectl  config view --minify > "${CONTEXT}.config"
kubectl "${KC}" config set-credentials "${CONTEXT}" --token="${TOKEN}"
kubectl "${KC}" config set-context "${CONTEXT}" --cluster="${CLUSTER}" --namespace="${NAMESPACE}"  --user="${CONTEXT}"
kubectl "${KC}" config set-cluster "${CLUSTER}" --certificate-authority=fake-ca-file
cat "${CONTEXT}.config" | sed -e "s/fake-ca-file/${CA}/g" -e "s/certificate-authority:/certificate-authority-data:/g" > "${CONTEXT}.new"
mv "${CONTEXT}.new" "${CONTEXT}.config"
export MY_CONTEXT=`kubectl "${KC}" config current-context`
kubectl "${KC}" config use-context "${CONTEXT}"


# Testing...
echo "Quick Unit Test..."

echo "Should PASS: " $(kubectl "${KC}" get services --namespace "${NAMESPACE}" 2>&1)
echo "Should FAIL: "  $(kubectl "${KC}" get nodes    --namespace "kube-system" 2>&1)

echo ""
echo "Please share the generated file ${KC} to the namespace requestor if the above tests pass"
