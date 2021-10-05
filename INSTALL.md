# Installation Guides

In order to install and use Pipelines-as-Code, you need to

* Install the Pipelines-as-Code infrastructure on your cluster
* Create a Pipelines-as-Code GitHub App on your GitHub account or organization
* Configure Pipelines-as-Code on your cluster to access the GitHub App

Here is a video walkthrough of the install process :

[![Pipelines as Code Install Walkthought](https://img.youtube.com/vi/d81rIHNFjJM/0.jpg)](https://www.youtube.com/watch?v=d81rIHNFjJM)

## Install Pipelines as Code infrastructure

To install Pipelines as Code on your cluster you simply need to run this command :

```shell
VERSION=0.3
kubectl apply -f https://raw.githubusercontent.com/openshift-pipelines/pipelines-as-code/release-$VERSION/release-$VERSION.yaml
```

If you would like to install the current development version you can simply install it like this :

```shell
kubectl apply -f https://raw.githubusercontent.com/openshift-pipelines/pipelines-as-code/nightly/release.yaml
```

It will apply the release.yaml to your kubernetes cluster, creating the admin namespace `pipelines-as-code`, the roles
and all other bits needed.

The `pipelines-as-code` namespace is where the Pipelines-as-Code infrastructure runs and is supposed to be accessible
only by the admin.

The Route for the EventListener URL is automatically created when you apply the release.yaml. You will need to grab the
url for the next section when creating the GitHub App. You can run this command to get the route created on your
cluster:

```shell
echo https://$(oc get route -n pipelines-as-code el-pipelines-as-code-interceptor -o jsonpath='{.spec.host}')
```

### Create a Pipelines-as-Code GitHub App

You should now create a Pipelines-as-Code GitHub App which acts as the integration point with OpenShift Pipelines and
brings the Git workflow into Tekton pipelines. You need the webhook of the GitHub App pointing to your Pipelines-as-Code
EventListener route endpoint which would then trigger pipelines on GitHub events.

* Go to https://github.com/settings/apps (or *Settings > Developer settings > GitHub Apps*) and click on **New GitHub
  App** button
* Provide the following info in the GitHub App form
    * **GitHub Application Name**: `OpenShift Pipelines`
    * **Homepage URL**: *[OpenShift Console URL]*
    * **Webhook URL**: *[the EventListener route URL copies in the previous section]*
    * **Webhook secret**: *[an arbitrary secret, you can generate one with `openssl rand -hex 20`]*

* Select the following repository permissions:
    * **Checks**: `Read & Write`
    * **Contents**: `Read & Write`
    * **Issues**: `Read & Write`
    * **Metadata**: `Readonly`
    * **Pull request**: `Read & Write`

* Select the following organization permissions:
    * **Members**: `Readonly`
    * **Plan**: `Readonly`

* Select the following user permissions:
    * Commit comment
    * Issue comment
    * Pull request
    * Pull request review
    * Pull request review comment
    * Push

> You can see a screenshot of how the GitHub App permissions look like [here](https://user-images.githubusercontent.com/98980/124132813-7e53f580-da81-11eb-9eb4-e4f1487cf7a0.png)

* Click on **Create GitHub App**.

* Take note of the **App ID** at the top of the page on the details page of the GitHub App you just created.

* In **Private keys** section, click on **Generate Private key* to generate a private key for the GitHub app. It will
  download automatically. Store the private key in a safe place as you need it in the next section and in future when
  reconfiguring this app to use a different cluster.

### Configure Pipelines-as-Code on your cluster to access the GitHub App

In order for Pipelines-as-Code to be able to authenticate to the GitHub App and have the GitHub App securely trigger the
Pipelines-as-Code webhook, you need to create a Kubernetes secret containing the private key of the GitHub App and the
webhook secret of the Pipelines-as-Code as it was provided when you created the GitHub App in the previous section. This
secret
is [used to generate](https://docs.github.com/en/developers/apps/building-github-apps/identifying-and-authorizing-users-for-github-apps)
a token on behalf of the user running the event and make sure to validate the webhook via the webhook secret.

Run the following command and replace:

* `APP_ID` with the GitHub App **App ID** copied in the previous section
* `WEBHOOK_SECRET` with the webhook secret provided when created the GitHub App in the previous section
* `PATH_PRIVATE_KEY` with the path to the private key that was downloaded in the previous section

```bash
kubectl -n pipelines-as-code create secret generic github-app-secret \
        --from-literal private.key="$(cat PATH_PRIVATE_KEY)" \
        --from-literal application_id="APP_ID" \
        --from-literal webhook.secret="WEBHOOK_SECRET"
```

### GitHub Enterprise

Pipelines as Code supports Github Enterprise.

You don't need to do anything special to get Pipelines as code working with GHE. Pipelines as code will automatically
detects the header as set from GHE and use it the GHE API auth url instead of the public github.

### Github Webhook

You can as well use [Github Webhooks](https://docs.github.com/en/developers/webhooks-and-events/webhooks/creating-webhooks) directly from your repository instead of a Github application.

Using Pipelines as Code via Github webhook does not allow access to the CheckRun API, the status of the tasks will be added as a Comment of the PR.

You will need to create a personal token to be able to do operation on the Github API.

Follow this guide to create a personal token :

<https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token>

The only permission needed is the *repo* permission. Make sure you note
somewhere the generated token or otherwise you will have to recreate it.

Go to you repository or organisation setting and click on *Hooks* and *"Add webhook"* links.

Set the payload URL to the event listenner public url, on OpenShift you can get it like this :

```shell
echo https://$(oc get route -n pipelines-as-code el-pipelines-as-code-interceptor -o jsonpath='{.spec.host}')
```

Add a secret or generate a random one with this command  :

```shell
openssl rand -hex 20
```

- Click on select individual events and check these events :

* Commit comments
* Issue comments
* Pull request reviews
* Pull request reviews
* Pushes

On your cluster you need to add the webhook secret set previously in the *pipelines-as-code* namespace.

```shell
kubectl -n pipelines-as-code create secret generic github-app-secret \
        --from-literal webhook.secret="WEBHOOK_SECRET_AS_SET"
```

Now to use this from the Repository CRD you first need to create a secret with
the Github API token

```shell
kubectl -n target-namespace create secret generic github-token \
        --from-literal token="TOKEN_AS_GENERATED_PREVIOUSLY"
```

And from your Repositry CRD you can add the secret field to reference this :

For example :

```yaml
---
apiVersion: "pipelinesascode.tekton.dev/v1alpha1"
kind: Repository
metadata:
  name: my-repo
  namespace: target-namespace
spec:
  url: "https://github.com/owner/repo"
  branch: "main"
  event_type: "pull_request"
  # Set this if you run with Github Enteprise
  # webvcs_api_url: "github.enteprise.com"
  webvcs_secret:
    name: "github-token"
    # Set this if you have a different key in your secret
    # key: "token"
```

`webvcs_secret` cannot reference a secret in another namespace, Pipelines as
code assumes always it is in the same namespace where the repository has been
created.

### Kubernetes

Pipelines as Code should work directly on kubernetes/minikube/kind. You just need to install the release.yaml
for [pipeline](https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml)
, [triggers](https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml) and
its [interceptors](https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml) on your cluster.
The release yaml to install pipelines are for the relesaed version :

```shell
VERSION=0.3
kubectl apply -f https://raw.githubusercontent.com/openshift-pipelines/pipelines-as-code/release-$VERSION/release-$VERSION.k8s.yaml
```

and for the nightly :

```shell
kubectl apply -f https://raw.githubusercontent.com/openshift-pipelines/pipelines-as-code/release-$VERSION/release.k8s.yaml
```

Kubernetes Dashboard is not yet supported for logs links but help is always welcome ;)

## CLI

`Pipelines as Code` provide a CLI which is design to work as tkn plugin. To install the plugin see the instruction
below.

### Binary releases

You can grab the latest binary directly from the
[releases](https://github.com/openshift-pipelines/pipelines-as-code/releases)
page.

### Dev release

If you want to install from the git repository you can just do :

```shell
go install github.com/openshift-pipelines/pipelines-as-code/cmd/tkn-pac
```

### Brew release

On [LinuxBrew](https://docs.brew.sh/Homebrew-on-Linux) or [OSX brew](https://brew.sh/) you can simply add the Brew tap
to have the tkn-pac plugin and its completion installed :

```shell
brew install openshift-pipelines/pipelines-as-code/tektoncd-pac
```

You simply need to do a :

```shell
brew upgrade openshift-pipelines/pipelines-as-code/tektoncd-pac
```

to upgrade to the latest released version.

### Container

`tkn-pac` is as well available inside the container image :

or from the container image user docker/podman:

```shell
docker run -e KUBECONFIG=/tmp/kube/config -v ${HOME}/.kube:/tmp/kube \
     -it quay.io/openshift-pipeline/pipelines-as-code tkn-pac help
```