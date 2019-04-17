#!/bin/bash

# Create temp directory
TMPDIR=$(mktemp -d)

# System info
mkdir -p $TMPDIR/systeminfo
hostname > $TMPDIR/systeminfo/hostname 2>&1
hostname -f > $TMPDIR/systeminfo/hostnamefqdn 2>&1
cat /etc/hosts > $TMPDIR/systeminfo/etchosts 2>&1
cat /etc/resolv.conf > $TMPDIR/systeminfo/etcresolvconf 2>&1
date > $TMPDIR/systeminfo/date 2>&1
free -m > $TMPDIR/systeminfo/freem 2>&1
uptime > $TMPDIR/systeminfo/uptime 2>&1
dmesg > $TMPDIR/systeminfo/dmesg 2>&1
df -h > $TMPDIR/systeminfo/dfh 2>&1
if df -i >/dev/null 2>&1; then
  df -i > $TMPDIR/systeminfo/dfi 2>&1
fi
lsmod > $TMPDIR/systeminfo/lsmod 2>&1
mount > $TMPDIR/systeminfo/mount 2>&1
ps aux > $TMPDIR/systeminfo/psaux 2>&1
lsof -Pn > $TMPDIR/systeminfo/lsof 2>&1
if $(command -v sysctl >/dev/null 2>&1); then
  sysctl -a > $TMPDIR/systeminfo/sysctla 2>/dev/null
fi
# OS: Ubuntu
if $(command -v ufw >/dev/null 2>&1); then
  ufw status > $TMPDIR/systeminfo/ubuntu-ufw 2>&1
fi
if $(command -v apparmor_status >/dev/null 2>&1); then
  apparmor_status > $TMPDIR/systeminfo/ubuntu-apparmorstatus 2>&1
fi
# OS: RHEL
if [ -f /etc/redhat-release ]; then
  systemctl status NetworkManager > $TMPDIR/systeminfo/rhel-statusnetworkmanager 2>&1
  systemctl status firewalld > $TMPDIR/systeminfo/rhel-statusfirewalld 2>&1
  if $(command -v getenforce >/dev/null 2>&1); then
  getenforce > $TMPDIR/systeminfo/rhel-getenforce 2>&1
  fi
fi

# Docker
mkdir -p $TMPDIR/docker
docker info > $TMPDIR/docker/dockerinfo 2>&1
docker ps -a > $TMPDIR/docker/dockerpsa 2>&1
docker stats -a --no-stream > $TMPDIR/docker/dockerstats 2>&1
if [ -f /etc/docker/daemon.json ]; then
  cat /etc/docker/daemon.json > $TMPDIR/docker/etcdockerdaemon.json
fi
# Networking
mkdir -p $TMPDIR/networking
iptables-save > $TMPDIR/networking/iptablessave 2>&1
cat /proc/net/xfrm_stat > $TMPDIR/networking/procnetxfrmstat 2>&1
if $(command -v ip >/dev/null 2>&1); then
  ip addr show > $TMPDIR/networking/ipaddrshow 2>&1
  ip route > $TMPDIR/networking/iproute 2>&1
fi
if $(command -v ifconfig >/dev/null 2>&1); then
  ifconfig -a > $TMPDIR/networking/ifconfiga
fi

# System logging
mkdir -p $TMPDIR/systemlogs
cp /var/log/syslog* /var/log/messages* /var/log/kern* /var/log/docker* /var/log/system-docker* /var/log/audit/* $TMPDIR/systemlogs 2>/dev/null

# Rancher logging
# Discover any server or agent running
mkdir -p $TMPDIR/rancher/containerinspect
mkdir -p $TMPDIR/rancher/containerlogs
RANCHERSERVERS=$(docker ps -a | grep -E "rancher/rancher:|rancher/rancher " | awk '{ print $1 }')
RANCHERAGENTS=$(docker ps -a | grep -E "rancher/rancher-agent:|rancher/rancher-agent " | awk '{ print $1 }')

for RANCHERSERVER in $RANCHERSERVERS; do
  docker inspect $RANCHERSERVER > $TMPDIR/rancher/containerinspect/server-$RANCHERSERVER 2>&1
  docker logs -t $RANCHERSERVER > $TMPDIR/rancher/containerlogs/server-$RANCHERSERVER 2>&1
done

for RANCHERAGENT in $RANCHERAGENTS; do
  docker inspect $RANCHERAGENT > $TMPDIR/rancher/containerinspect/agent-$RANCHERAGENT 2>&1
  docker logs -t $RANCHERAGENT > $TMPDIR/rancher/containerlogs/agent-$RANCHERAGENT 2>&1
done

# K8s Docker container logging
mkdir -p $TMPDIR/k8s/containerlogs
mkdir -p $TMPDIR/k8s/containerinspect
KUBECONTAINERS=(etcd etcd-rolling-snapshots kube-apiserver kube-controller-manager kubelet kube-scheduler kube-proxy nginx-proxy)
for KUBECONTAINER in "${KUBECONTAINERS[@]}"; do
  if [ "$(docker ps -q -f name=$KUBECONTAINER)" ]; then
          docker inspect $KUBECONTAINER > $TMPDIR/k8s/containerinspect/$KUBECONTAINER 2>&1
	  docker logs -t $KUBECONTAINER > $TMPDIR/k8s/containerlogs/$KUBECONTAINER 2>&1
  fi
done

# System pods
mkdir -p $TMPDIR/k8s/podlogs
mkdir -p $TMPDIR/k8s/podinspect
SYSTEMNAMESPACES=(kube-system kube-public cattle-system cattle-alerting cattle-logging cattle-pipeline ingress-nginx cattle-prometheus)
for SYSTEMNAMESPACE in "${SYSTEMNAMESPACES[@]}"; do
  CONTAINERS=$(docker ps -a --filter name=$SYSTEMNAMESPACE --format "{{.Names}}")
  for CONTAINER in $CONTAINERS; do
    docker inspect $CONTAINER > $TMPDIR/k8s/podinspect/$CONTAINER 2>&1
    docker logs -t $CONTAINER > $TMPDIR/k8s/podlogs/$CONTAINER 2>&1
  done
done

# K8s directory state
mkdir -p $TMPDIR/k8s/directories
if [ -d /opt/rke/etc/kubernetes/ssl ]; then
  find /opt/rke/etc/kubernetes/ssl -type f -exec ls -la {} \; > $TMPDIR/k8s/directories/findoptrkeetckubernetesssl 2>&1
elif [ -d /etc/kubernetes/ssl ]; then
  find /etc/kubernetes/ssl -type f -exec ls -la {} \; > $TMPDIR/k8s/directories/findetckubernetesssl 2>&1
fi

# K8s certs
mkdir -p $TMPDIR/k8s/certs
if [ -d /opt/rke/etc/kubernetes/ssl ]; then
  CERTS=$(find /opt/rke/etc/kubernetes/ssl -type f -name *.pem | grep -v "\-key\.pem$")
  for CERT in $CERTS; do
    openssl x509 -in $CERT -text -noout > $TMPDIR/k8s/certs/$(basename $CERT) 2>&1
  done
elif [ -d /etc/kubernetes/ssl ]; then
  CERTS=$(find /etc/kubernetes/ssl -type f -name *.pem | grep -v "\-key\.pem$")
  for CERT in $CERTS; do
    openssl x509 -in $CERT -text -noout > $TMPDIR/k8s/certs/$(basename $CERT) 2>&1
  done
fi

# etcd
mkdir -p $TMPDIR/etcd
# /var/lib/etcd contents
if [ -d /var/lib/etcd ]; then
  find /var/lib/etcd -type f -exec ls -la {} \; > $TMPDIR/etcd/findvarlibetcd 2>&1
elif [ -d /opt/rke/var/lib/etcd ]; then
  find /opt/rke/var/lib/etcd -type f -exec ls -la {} \; > $TMPDIR/etcd/findoptrkevarlibetcd 2>&1
fi

# nginx-proxy
if docker inspect nginx-proxy >/dev/null 2>&1; then
  mkdir -p $TMPDIR/k8s/nginx-proxy
  docker exec nginx-proxy cat /etc/nginx/nginx.conf > $TMPDIR/k8s/nginx-proxy/nginx.conf 2>&1
fi

# /opt/rke contents
if [ -d /opt/rke/etcd-snapshots ]; then
  find /opt/rke/etcd-snapshots -type f -exec ls -la {} \; > $TMPDIR/etcd/findoptrkeetcdsnaphots 2>&1
fi

FILENAME="$(hostname)-$(date +'%Y-%m-%d_%H_%M_%S').tar"
tar cf /tmp/$FILENAME -C ${TMPDIR}/ .

if $(command -v gzip >/dev/null 2>&1); then
  gzip /tmp/${FILENAME}
  FILENAME="${FILENAME}.gz"
fi

echo "Created /tmp/${FILENAME}"
echo "You can now remove ${TMPDIR}"
