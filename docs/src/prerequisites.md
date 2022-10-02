# Prerequisites

Before we begin, we really need to ensure that your machine has the required tools needed to run the rest of this tutorial.

## Clone our repository

You will need access to our source code (cough... set of bash scripts) to run the tutorials on your local machine.

```bash
git clone https://github.com/jacobdr/k8s-the-harder-way.git
```

## Get a system package manager

System package managers can do many things, but at their core their responsibility is to get useful executables and system libraries from public sources onto your local machine. If your computer did not leave the factory with `curl` installed on it, a package manager would help you install that tool and make it available to you as a CLI / executable within your terminal.

Sometimes system managers install pre-built binaries (lift-and-shift the correct executable onto your local machine), other times they distribute the source code and dependencies, and provide a recipe that executes on your box to turn the source into executable files that you can then run.

Package managers are generally pretty operating system specific (e.g. Ubuntu has `aptitude` aka `apt`, OS X `homebrew` aka `brew`, CentOS/RedHat `yum`, Alpine `apk`). Each package manager distributes their "recipes" (read: packages) differently -- Cloudflare has a [really friendly tutorial](https://blog.cloudflare.com/using-cloudflare-r2-as-an-apt-yum-repository/) that unapcks how aptitude works, and Homebrew has a [cookbook for how their formulae work](https://docs.brew.sh/Formula-Cookbook).

Anyway, enough on package managers.... Lets actually make sure you have one.


### OS X

[Homebrew](https://brew.sh) is required to install a series of CLI tools that our required by this project. See the official site for installation instructions. Please make sure that PATH variable where `brew` installs executables to is availabe on your $PATH. Their docs and StackOverflow will do a better job of helping you out... Just know by the end of this step you should be able to open a fresh terminal and run `brew --help` and see output.


### Linux

If you are on Linux you probably already are bored by all this talk of package managers and know how to use yours.... Lets move on.


## Install Required Packages + Tools

This project makes use of a few different tools that you are going to need if you want to follow along. To check what you are missing, run `make check-prod` from the root of the repository. It should tell you what tools (if any) you are missing and need to install via your package manager.

When all goes well it should look something like the following....

```bash
❯ make check-prod
./dev/check-required-prod-dependencies.sh
k8s::check-required-prod-dependencies.sh::INFO -- Starting to check for required system dependencies....
/opt/homebrew/bin/cfssl
/opt/homebrew/bin/cfssljson
/usr/local/bin/docker
/opt/homebrew/bin/kubectl
/usr/bin/openssl
k8s::check-required-prod-dependencies.sh::INFO -- All required production dependencies are installed
```

If you are misisng anything we try to provide useful inline links to the official docs of our dependendent projects that should contain installation instructions. Some of these projects should have official packages available for your package manager for easy installation, but for others you might need to download the release binary(ies) and copy it to a location available on your PATH.

_Contribution Welcome: Make a PR that improves the `dev/check-required-prod-dependencies.sh` script with better instructions for each component_

Re-run `make check-prod` until such time as it exits successfully (i.e. with a zero exit code) before moving on to the next step.
