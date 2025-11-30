#!/usr/bin/env bash
set -euo pipefail

echo ">>> NUKING ISTIO FROM CLUSTER (CRDs, webhooks, RBAC, namespaces, Helm releases)"
echo ">>> You MUST be cluster-admin and have kubectl pointing at the right cluster."
echo

############################
# 1. Uninstall Helm releases
############################

echo ">>> Uninstalling possible Istio Helm releases (if they exist)..."

# Common Istio releases / namespaces you used
RELEASES=(istio-base istiod istio-ingress istio-egress)
NAMESPACES=(istio-system istio-ingress istio-egress)

for ns in "${NAMESPACES[@]}"; do
  for rel in "${RELEASES[@]}"; do
    echo " - helm uninstall ${rel} -n ${ns} (if present)"
    helm uninstall "${rel}" -n "${ns}" 2>/dev/null || true
  done
done

echo

###################################
# 2. Delete Istio-related namespaces
###################################

echo ">>> Deleting Istio namespaces (if present)..."

for ns in istio-system istio-ingress istio-egress; do
  echo " - kubectl delete namespace ${ns}"
  kubectl delete namespace "${ns}" --ignore-not-found=true || true
done

echo ">>> Waiting a few seconds for namespaces to terminate..."
sleep 5
echo

##########################
# 3. Delete Istio CRDs
##########################

echo ">>> Deleting Istio CRDs (*.istio.io)..."

ISTIO_CRDS=$(kubectl get crd 2>/dev/null | awk '/istio.io/ {print $1}' || true)
if [[ -n "${ISTIO_CRDS}" ]]; then
  echo "${ISTIO_CRDS}" | xargs -r kubectl delete crd
else
  echo " - No Istio CRDs found."
fi

echo

#######################################
# 4. Delete Istio webhooks (validating)
#######################################

echo ">>> Deleting Istio ValidatingWebhookConfigurations..."

VALIDATING_WEBHOOKS=$(kubectl get validatingwebhookconfigurations 2>/dev/null | awk '/istio/i {print $1}' || true)
if [[ -n "${VALIDATING_WEBHOOKS}" ]]; then
  echo "${VALIDATING_WEBHOOKS}" | xargs -r kubectl delete validatingwebhookconfiguration
else
  echo " - No Istio validating webhooks found."
fi

echo

#######################################
# 5. Delete Istio webhooks (mutating)
#######################################

echo ">>> Deleting Istio MutatingWebhookConfigurations..."

MUTATING_WEBHOOKS=$(kubectl get mutatingwebhookconfigurations 2>/dev/null | awk '/istio/i {print $1}' || true)
if [[ -n "${MUTATING_WEBHOOKS}" ]]; then
  echo "${MUTATING_WEBHOOKS}" | xargs -r kubectl delete mutatingwebhookconfiguration
else
  echo " - No Istio mutating webhooks found."
fi

echo

######################################
# 6. Delete Istio ClusterRoles
######################################

echo ">>> Deleting Istio ClusterRoles..."

ISTIO_CLUSTERROLES=$(kubectl get clusterrole 2>/dev/null | awk '/istio/i {print $1}' || true)
if [[ -n "${ISTIO_CLUSTERROLES}" ]]; then
  echo "${ISTIO_CLUSTERROLES}" | xargs -r kubectl delete clusterrole
else
  echo " - No Istio ClusterRoles found."
fi

echo

############################################
# 7. Delete Istio ClusterRoleBindings
############################################

echo ">>> Deleting Istio ClusterRoleBindings..."

ISTIO_CLUSTERROLEBINDINGS=$(kubectl get clusterrolebinding 2>/dev/null | awk '/istio/i {print $1}' || true)
if [[ -n "${ISTIO_CLUSTERROLEBINDINGS}" ]]; then
  echo "${ISTIO_CLUSTERROLEBINDINGS}" | xargs -r kubectl delete clusterrolebinding
else
  echo " - No Istio ClusterRoleBindings found."
fi

echo

##########################
# 8. Final sanity checks
##########################

echo ">>> Sanity check: remaining Istio resources (should be empty or minimal)..."

echo "CRDs with 'istio.io':"
kubectl get crd 2>/dev/null | grep 'istio.io' || echo " - none"

echo
echo "ValidatingWebhookConfigurations with 'istio':"
kubectl get validatingwebhookconfigurations 2>/dev/null | grep -i istio || echo " - none"

echo
echo "MutatingWebhookConfigurations with 'istio':"
kubectl get mutatingwebhookconfigurations 2>/dev/null | grep -i istio || echo " - none"

echo
echo "ClusterRoles with 'istio':"
kubectl get clusterrole 2>/dev/null | grep -i istio || echo " - none"

echo
echo "ClusterRoleBindings with 'istio':"
kubectl get clusterrolebinding 2>/dev/null | grep -i istio || echo " - none"

echo
echo "Namespaces istio-system / istio-ingress / istio-egress:"
kubectl get ns 2>/dev/null | egrep 'istio-system|istio-ingress|istio-egress' || echo " - none"

echo
echo ">>> Istio nuke script completed."
