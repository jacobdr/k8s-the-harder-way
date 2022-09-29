# k8s the hard(er) way

:point_right: [Jump to the tutorials](https://jacobdr.github.io/k8s-the-harder-way/)

The purpose of this project is to provide a guided approach to bootstrapping a bare-metal k8s cluster, with an emphasis on explanation and the assumption that you want to avoid having to use a cloud provider like the plague.

* **Learn bare-metal k8s step-by-step with a very guiding and gentle hand**
* **Fast and completely local -- change the source code and have a play easily**
* **Brush up on Linux, OS, and networking fundamentals in a directed fashion**

It is inspired by the [k8s the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way). However, since we assume an Linux-like platform (whereas k8s the hard way assumes a google cloud environment), we are able to bootstrap our cluster locally without requiring a cloud vendor.

This project philosophically also differs from k8s the hard way in that we allow ourselves to meander a bit more -- providing color on topics such as operating system behaviors, networking tools and concepts, and debugging utilities. These are not k8s concerns per se -- but our general aim is to consolidate and improve the baseline understanding of system behavior of readers, especially those without years of sysadmin experience.

We want to extend deep thanks to the [k8s the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way) project which serves as the major source of inspitation for much of the content here that we expand upon.

## Developer Docs

(If you are not a contributor, you probably want the [main docs site](https://jacobdr.github.io/k8s-the-harder-way/))

### High-Level Overview

The main entrypoint is the `run.sh` script, which in turn loads helper functions of varying sorts (like bash logging functions and environment variable files) but primarily acts as a driver to run the scripts in the `scripts/` directory. These scripts are named sequentially and are expected to be created in order.

The general order of steps is:

* Spin up VMs on your local host to act as k8s "worker" nodes and also run the k8s-control plane components
* Get the IP addresses of the created VMs and set up inter-host networking
* Generate all the required PKI infrastructure -- a self-signed cluster root CA, which in turn is used to sign a bunch of other PKI certs used by various k8s components
* Install all the k8s required components onto each of the nodes -- first, the control plane components like `etcd`, `kube-apiserver`, etc., and then later on the k8s "worker" components (i.e. `kubelet`, `kube-proxy`)

**Directory structure:**

* `.github/{actions,workflows}`: Github CI stuff. Makes use of composable actions for code-reuse into the workflows.
* `csr`: Holds the certificate signging request config files used by [Cloudflare's `cfssl` tool](https://github.com/cloudflare/cfssl#using-the-command-line-tool). These are not secret. The actual secrets generated (like the root CA key and the various TLS certificate keys) are stored in the `outputs/` directory, which is not checked into source control
* `dev`: Random scripts meant for use by developers and other internal tools
* `docs`: Source code, configuration, and built artifacts for docs. The actual site is built to `docs/book` (i.e. this is where you find the root `index.html`). Actual markdown source is in `docs/src` -- of which the `docs/src/SUMMARY.md` is the entrypoint and builds the table of contents (TOC). `docs/book.toml` is the [configuraiton file](https://rust-lang.github.io/mdBook/format/configuration/general.html). This site is eventually published to [https://jacobdr.github.io/k8s-the-harder-way](https://jacobdr.github.io/k8s-the-harder-way/)
* `output`: A git-ignored directory that has the generated PKI secrets and certificates (`output/certificates`), kubectl configuration files (`output/kube-configs`), a downloads cache to speed up VM bootstrapping (`output/downloads`)

### Developer Tools

* `pre-commit`: Used to enforce code style and other rules. Install via system manager or their [official docs](https://pre-commit.com/#install). To initialize, run `pre-commit install --install-hooks` from the repo root. The GH actions will enforce this, so its useful to have your local git hoooks enforce the conventions for earlier feedback
* `Make`: We keep a basic set of Make targets as developer conveniences shortcuts. Why Make? Because its available everywhere and helps us KISS


### Support for Lima on OS X

[Lima](https://github.com/lima-vm/lima) is an awesome tool for creating Linux VMs on OS X. Under the covers it uses QEMU with Hypervisor Framework (HVF) acceleration to spin up "real" VMs, with added conveniences like automatic port-forwarding and file sharing to the host OS X machine.

It was the initial basis of this project, but to increase portability we shifted focus toward getting everything to work inside of Docker. We don't quite use "docker-in-docker" since we actually just run raw `containerd` ourselves inside the docker containers we spin up as the k8s nodes (so, no host docker socket mounting, the `containerd` sockets on our containers is managed by `systemd` inside the container). Another benefit of switching to Docker (aside from portability for Linux folk) is that its _way_ easier to test. While Github Actions support spinning up OS X hosts, they are 10x more expensive, whereas we can exercise our own docker-based flow on a vanilla Linux VM and test our repo readily on the docker path.

In the future we should add that OS X lima-based testing, but we'll need to find a way to help keep costs down by not running it super frequently in CI.

We need to better document the required networking setup for `socket_vmnet` as in the [lima networking docs](https://github.com/lima-vm/lima/blob/master/docs/network.md#managed-vmnet-networks-192168105024)


### Building Docs

The docs site is built using [`mdbook`](https://github.com/rust-lang/mdBook) which is maintaiend by the Rust folks (so we don't need to worry about stability), and is responsible for turning markdown files into a nicely formatted site a-la-Gitbook. We augment their setup by installing [`markdownbook-plantuml`](https://github.com/sytsereitsma/mdbook-plantuml) as a preprocessor. [PlatUML](https://plantuml.com) is an old-school but badass tool for creating diagrams and visualizations like sequence diagrams using a pretty friendly syntax. `markdownbook-plantuml` provides the glue to convert the PlantUML syntax into actual image files (like SVG), and then embed those images into our site.

`markdownbook-plantuml` is a pretty immature project and is a Rust dependency of ours, so the `docs/mdbook-shim.sh` file is our entrypoint into building the docs. It does as named and really just shims passed arguments to the `mdbook` executable, but does some checking of dependencies and PATH setup to get everything working as expected.

There is an excellent [online PlantUML editor](https://plantuml-editor.kkeisuke.com) that is super useful for working on diagrams before copying the source code into our repo. They also have a ["new version"](https://plantuml-editor.kkeisuke.dev) of the editor that we haven't really played with too much yet....

We might also want to explore making more use of the [network diagram](https://plantuml.com/nwdiag) feature.


### Things that are kind of shitty to improve

* Docs build time in CI
* DNS and HA from the host into the VMs (need to update the docs on using brew and dnsmasq on OS X, but sucks it needs sudo)
* Too easy to delete state
* How well do the containers withstand restarts?
* Sequential IP address assignment via side-effect
