# k8s the hard(er) way

The purpose of this project is to provide a guided approach to bootstrapping a bare-metal k8s cluster, with an emphasis on explanation and the assumption of the OS X platform. It is inspired by the [k8s the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way). However, since we assume an OS X platform (whereas k8s the hard way assumes a google cloud environment), we are able to bootstrap our cluster locally without requiring a cloud vendor.

This project philosophically also differs from k8s the hard way in that we allow ourselves to meander a bit more -- providing color on topics such as operating system behaviors, networking tools and concepts, and debugging utilities. These are not k8s concerns per se -- but our general aim is to consolidate and improve the baseline understanding of system behavior of readers, especially those without years of sysadmin experience.

We want to extend deep thanks to the [k8s the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way) project which serves as the major source of inspitation for much of the content here that we expand upon.

## Docs

**TODO: Link here**

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
