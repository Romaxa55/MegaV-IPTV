#!/bin/bash

# Deploy IPTV Parser to Kubernetes
# Usage: ./deploy-iptv-parser.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NAMESPACE="megav-iptv"
RELEASE_NAME="iptv-parser"
CHART_PATH="./charts/iptv-parser/"

echo -e "${GREEN}Deploying IPTV Parser to ${NAMESPACE}...${NC}"

# Check namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}Creating namespace ${NAMESPACE}...${NC}"
    kubectl create namespace "$NAMESPACE"
fi

# Check secrets exist
for secret in "postgres.megav-heavy.credentials.postgresql.acid.zalan.do" "redis" "ghcr-secret"; do
    if ! kubectl get secret "$secret" -n "$NAMESPACE" &>/dev/null; then
        echo -e "${RED}Secret ${secret} not found in ${NAMESPACE}. Copy it from megav namespace first.${NC}"
        exit 1
    fi
done

echo -e "${GREEN}All secrets found.${NC}"

# Deploy with Helm
helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
    --namespace "$NAMESPACE" \
    --wait \
    --timeout 5m

echo -e "${GREEN}Deployment complete!${NC}"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl get cronjobs -n $NAMESPACE"
echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=api -f"
echo ""
echo -e "${YELLOW}Trigger M3U parser manually:${NC}"
echo "  kubectl create job --from=cronjob/${RELEASE_NAME}-m3u-parser ${RELEASE_NAME}-m3u-parser-manual-\$(date +%s) -n $NAMESPACE"
