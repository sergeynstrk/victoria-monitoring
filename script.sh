#delete all crds
echo "create namespace"
kubectl create namespace victoria-monitoring

CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
YAML_FILE="./victoria-metrics/vmagent.yaml"
sed -i -E "s/(k8s_cluster:)[[:space:]]+.*/\1 ${CLUSTER_NAME}/" "$YAML_FILE"

echo "install vmoperator"
helm install vmoperator -n victoria-monitoring ./victoria-metrics/victoria-metrics-operator-0.47.0.tgz -f ./victoria-metrics/values.yaml \
  --set operator.enabled=true

echo "create sa"
kubectl create sa victoria-metrics-operator

echo "create vmagent"
kubectl apply -f ./victoria-metrics/vmagent.yaml

echo "install prometheus-node-exporter"
helm upgrade -i prometheus-node-exporter -n victoria-monitoring ./node-exporter/prometheus-node-exporter-4.46.1.tgz

echo "install x509-certificate-exporter"
helm upgrade -i x509-certificate-exporter -n victoria-monitoring ./x509-exporter/x509-certificate-exporter-3.6.0.tgz -f ./x509-exporter/values.yaml

echo "install kube-state-metrics"
helm upgrade -i kube-state-metrics -n victoria-monitoring ./kube-state-metrics/kube-state-metrics-5.21.0.tgz

echo "create vmservicescrapes"
kubectl apply -f ./vmservicescrapes/

echo "включаем метрики kube-proxy"
kubectl -n kube-system get configmap kube-proxy -o json | \
  jq '.data["config.conf"] |= (sub("metricsBindAddress: \"\""; "metricsBindAddress: \"0.0.0.0:10249\""))' | \
  kubectl apply -f -
echo "rollout kube-proxy"
kubectl rollout restart -n kube-system ds kube-proxy

echo "install etcd-proxy-server"
kubectl apply  -n victoria-monitoring -f ./etcd-proxy-server/
########################
#включить метрики в /etc/kubernetes/manifests/kube-controller
#- --bind-address=0.0.0.0
