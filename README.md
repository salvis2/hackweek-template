# Hackweek-Template

### About

This repo serves as a template for all the resources you need to deploy a
Pangeo-style JupyterHub. The focus of this template is for hackweek hubs,
which should be easy to spin up or tear down and have most of the settings
that short-term users will want and need.

This project is heavily inspired from Yuvi Panda's
[TESS Prototype Deployment repo](https://github.com/yuvipanda/tess-prototype-deploy)
and directly utilizes his open-source
[Hubploy Template](https://github.com/yuvipanda/hubploy-template). 

The two primary tools that are used for this deployment are
[Terraform](https://www.terraform.io/) and
[Hubploy](https://github.com/yuvipanda/hubploy). 
- Terraform is used to store the cloud infrastructure as code and make
deploying the Kubernetes cluster easy.
- Hubploy is used to deploy the JupyterHub software onto the cluster and
enables continuous integration (CI) through GitHub Actions.

Note: This repo spins up infrastructure on AWS. If you want it on another
cloud provider, it is advised that you become familiar with Hubploy,
Hubploy-Template, and Terraform and build a new template yourself. In the
future, this repo may expand to include deployments on other cloud providers.

## Installation

### Prerequisites

You'll need the following tools installed:

- [Terraform](https://www.terraform.io/downloads.html)
  - If you are on MacOS, you can install it with `brew install terraform`
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
  - If you are on MacOS, you can install it with `brew install kubectl`
- [awscli](https://aws.amazon.com/cli/)
- [Helm](https://github.com/helm/helm#install)
- A [Docker Environment](https://docs.docker.com/install/)
- The [Hackweek Template](https://github.com/salvis2/hackweek-template)
  - Get the template repo locally by forking the repo to your own workspace /
  organization and then cloning.

### Cloud Infrastructure with Terraform

### Get `terraform-deploy` Submodule

This module builds off of `terraform-deploy` for the infrastructure management
. You can find that repo
[here](https://github.com/pangeo-data/terraform-deploy)
; we are currently using the `hackweek-template-infrastructure` branch.

It is recommended to fork the `terraform-deploy` repo and host it wherever
your fork of this repo is. You can then change `.gitmodules` to have the
new location of the submodule.

Get the submodule into the `cloud-infrastructure` folder by running

```
git submodule init
```

This will bring in the infrastructure repo at a specific commit. You can
work with it as a normal git repo by running

```
cd cloud-infrastructure
git checkout master
```

#### Configure Permissions

Before running any Terraform commands, you need to be authenticated to the
awscli. The `cloud-infrastructure/aws-creds/` directory has all the
permissions needed for Terraform to run. You can choose to generate a user or
role to insure minimum permission levels. Both of these options are present
in `iam.tf`. If you choose to use one of these, uncomment the relevent lines
and run `terraform init`, then `terraform apply`. You can then configure the
credentials as needed with `aws configure`.

#### Fill in Variable Names 

The terraform deployment needs several variable names set before it
can start. You can copy the file
`cloud-infrastructure/aws/your-cluster.tfvars.template` into a file
named `<your-cluster>.tfvars`, and modify the placeholders there as
appropriate. If you want extra users to be mapped to the Kubernetes masters,
add entries to `map_users` (it is a list of maps).

#### Create Infrastructure

In the `cloud-infrastructure/aws/` directory, run `terraform init` to
download the required Terraform plugins.

Then, run `terraform apply -var-file=<path/to/your-cluster.tfvars>`, look
through the resources Terraform plans to spin up, and then type yes.

The cluster creation process occasionally errors out. Re-running the previous
command again will usually succeed. The infrastructure can take 15-20 minutes
to create, so feel free to open another Terminal and continue with most of
the next section while you wait.

When the infrastructure is created, run
`aws eks update-kubeconfig --region=<your-region> --name=<your-cluster>` with
values from `your-cluster.tfvars` to allow `kubectl` to access the cluster.

### JupyterHub Deployment with Hubploy

#### Install Hubploy

```
python3 -m venv .
source bin/activate
python3 -m pip install -r requirements.txt
```

#### Rename the Hub

Each directory inside `deployments/` represents an installation of
JupyterHub. The default is called `hackweek-hub` in this repo, you are
recommended to change it to be more specific. You need to `git commit` the
change as well:

```
git mv deployments/hackweek-hub deployments/<your-hub-name>
git commit
```

#### Fill in the Config Details

You need to find all things marked TODO and fill them in. In particular,

- `hubploy.yaml` needs information about where your docker registry &
kubernetes cluster is, and paths to access keys as well.
- `secrets/prod.yaml` and `secrets/staging.yaml` require secure random keys
you can generate and fill in.

#### Build and Push the Hub's Image

- Make sure tha appropriate docker credential helper is installed, so hubploy
can push to the registry you need.
  - For AWS, you need
  [`docker-ecr-credential-helper`](https://github.com/awslabs/amazon-ecr-credential-helper)

- Make sure you are in your repo's root directory, so hubploy can find the
directory structure it expects.

- Build and push the image to the registry

```
hubploy build <hub-name> --push --check-registry
```

This should check if the user image for your hub needs to be rebuilt, and if
so, it’ll build and push it.

#### Deploy the Staging Hub

Note: This step will fail unless your infrastructure is built and you have
run the `aws eks update-kubeconfig` command above.

Each hub will always have two versions - a *staging* hub that isn’t used by
actual users, and a *production* hub that is. These two should be kept as
similar as possible, so you can fearlessly test stuff on the staging hub
without feaer that it is going to crash & burn when deployed to production.

To deploy to the staging hub,

```
hubploy deploy <hub-name> hub staging
```

This could take a few minutes, but eventually return successfully. You can
then find the public IP of your hub with:

```
kubectl -n <hub-name>-staging get svc proxy-public
```

If you access that, you should be able to get in with any username &
password. It might take a minute to be able to be accessible.

The defaults provision each user their own EBS / Persistent Disk, so this can
get expensive quickly :) Watch out!

#### Customize Your Hub

You can now customize your hub in two major ways:

-  Customize the hub image.
[`repo2docker`](https://repo2docker.readthedocs.io/) is used to build the
image, so you can put any of the
[supported configuration files](https://repo2docker.readthedocs.io/en/latest/config_files.html)
under `deployments/<hub-image>/image`. You *must* make a git commit after
modifying this for `hubploy build <hub-name> --push --check-registry` to
work, since it uses the commit hash as the image tag.

- Customize hub configuration with various YAML files.

`hub/values.yaml` is common to *all* hubs that exist in this repo (multiple
hubs can live under `deployments/`).

`deployments/<hub-name>/config/common.yaml` is where most of the config
specific to each hub should go. Examples include memory / cpu limits,
home directory definitions, etc

`deployments/<hub-name>/config/staging.yaml` and
`deployments/<hub-name>/config/prod.yaml` are files specific to the staging &
prod versions of the hub. These should be *as minimal as possible*. Ideally,
only DNS entries, IP addresses, should be here.

`deployments/<hub-name>/secrets/staging.yaml` and 
`deployments/<hub-name>/secrets/prod.yaml` should contain information that
mustn't be public. This would be proxy / hub secret tokens, any
authentication tokens you have, etc. These files *must* be protected by
something like [`git-crypt`](https://github.com/AGWA/git-crypt) or
[`sops`](https://github.com/mozilla/sops).
**THIS REPO TEMPLATE DOES NOT HAVE THIS PROTECTION SET UP YET**

You can customize the staging hub, deploy it with 
``hubploy deploy <hub-name> hub staging``, and iterate until you like how it
behaves.

#### Deploy to Prod

You can then do a production deployment with: 
``hubploy deploy <hub-name> hub prod``, and test it out!

#### Setup Git-Crypt for Secrets

[`git-crypt`](https://github.com/AGWA/git-crypt) is used to keep encrypted
secrets in the git repository.

- Install git-crypt. You can get it from brew or your package manager.
- In your repo, initialize it: `git crypt init`
- The `.gitattributes` file has the configuration of files it will encrypt.
- Make a copy of the encryption key. This will be used to decrypt the
secrets. You will need to share it with your CD provider (CircleCI, GitHub
Actions) and anyone else who will be using the repo for the same hub as you.
`git crypt export-key key` puts the key in a file called 'key'.

#### GitHub Workflows

- Get a base64 copy of your key: `cat key | base64`
- Put it as a secret named GIT_CRYPT_KEY in GitHub Secrets.
- Make sure you change `hackweek-hub` to your deployment's name in the
workflows under `.github/workflows/`.
- Push to the staging branch and check out GitHub Actions to see if the
action completes.
- If the staging action succeeds, make a PR from staging to prod and merge
the PR. This should also trigger an action; make sure the action completes.

Note: *Always* make a PR from staging to prod. Never push directly to prod.
We want to keep the staging and prod branches as close to each other as
possible, and this is the only long-term guaranteed way to do that.

### Uninstallation

Hopefully you had a good hackweek! Now you can remove the hub and cloud
infrastructure so you stop paying for them.

#### Remove the Hub

You will need the helm release's name and namespace. These are procedurally
generated, usually both in the format `<your-hub>-hub-<branch>`. For example,
with a `deployment/` named `hackweek-hub` on my `staging` branch, the
helm release and namespace are both named `hackweek-hub-staging`. 

Uninstalling the hub from the cluster is done with 

```
helm delete <release-name> -n <namespace-name>
```

For my example, this would be

```
helm delete hackweek-hub-staging -n hackweek-hub-staging
```

#### Release the Cloud Infrastructure

Before releasing, make sure that the result of `kubectl get svc -A` shows no
entries with an `EXTERNAL-IP`.

If this is the case, you can run

```
terraform destroy -var-file=<path/to/your-cluster.tfvars>
```

Note: This also takes 15-20 minutes and may error out as it tries to destroy
a couple Kubernetes resources. Try re-running the command again.

#### Delete the GitHub Repo

You may now delete the GitHub Repo you set up or forked, and you are done!


