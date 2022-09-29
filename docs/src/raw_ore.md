# Raw Ore (Errata)

**Random notes that need to get turned into proper docs pages....**

## Developers

1. Install Lima via homebrew
1. Install VDE setup for lima -- https://hub.0z.gs/lima-vm/lima/blob/master/docs/network.md
   note: need to update the sudoers file per the instructions all the way at the bottom of the page
1. `ip address` on the `lima0` interface shows the IP address assigned

# Run

```bash
./run.sh
```

# Notes

- etcd environment variable in the unit file since its not officially supported
- ```
  export ETCDCTL_CACERT=/etc/etcd/ca.pem
  export ETCDCTL_CERT=/etc/etcd/kubernetes.pem
  export ETCDCTL_KEY=/etc/etcd/kubernetes-key.pem
  etcdctl member list --endpoints=https://127.0.0.1:2379 --debug
  ```
- check the service account issuer in step 12 -- i set it to 0.0.0.0
- lima handles the proxying of the kubectl on the mac os host I think since we bind the API server to the public network interface
- hostname-override is used in the bootstrapping of the workers -- https://kubernetes.io/docs/reference/access-authn-authz/node/

## Ingress

https://kubernetes.github.io/ingress-nginx/deploy/baremetal/
https://metallb.universe.tf/concepts/
https://metallb.universe.tf/installation/

Required tools:

```
brew install jq cfssl prips dnsmasq
```

## dnsmasq

- Update the system preferences to add DNS via 127.0.0.1 and another domain
- Limitation of customizing the port requires in turn to run as root
  https://thinkingeek.com/2020/06/06/local-domain-and-dhcp-with-dnsmasq/

/System/Volumes/Data/opt/homebrew/etc/dnsmasq.conf
