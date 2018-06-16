kubectl create namespace gitlab-managed-apps
kubectl create -f ./config/gitlab-sa.yaml
kubectl -o json get secrets -n gitlab-managed-apps | jq .items[0] | jq -r '.data.token' | base64 -D -
kubectl -o json get secrets -n gitlab-managed-apps | jq .items[0] | jq -r '.data."ca.crt"' | base64 -D - | tee ca.crt
openssl x509 -in ca.crt -noout -subject -issuer
openssl s_client -showcerts -connect api.${KOPS_CLUSTER_NAME}:443 < /dev/null &> apiserver.crt
openssl verify -verbose -CAfile ca.crt apiserver.crt
kubectl create clusterrolebinding permissive-binding --clusterrole=cluster-admin --user=admin --user=kubelet --group=system:serviceaccounts
rm -rf ca.crt apiserver.crt

kubectl create -f ./config/glr.values.configmap.yaml
kubectl create -f ./config/glr.register.configmap.yaml
kubectl create -f ./config/glr.token.secret.yaml.tmp
kubectl create -f ./config/glr.statefulset.yaml

rm -rf ./config/*.tmp*