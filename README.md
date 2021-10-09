# Google Compute Engine - Fedora Cloud image converter

In GCP (as of writing this README) there is no Fedora Cloud images pre-built images available. Debian, Ubuntu, RedHat and CentOS are available, but oddly enough no Fedora.

As a keen user of Fedora these days I decided to automate the process needed to convert latest Fedora Cloud image from cloud-init to GCP compatible format.

## CloudBuild

NOTE! Cloudbuild service account in IAM requires Compute Admin and Storage Admin roles for this pipeline to function. These are obviously way too wide privileges for production use and it is recommended that required permissions are given to a custom role that is then given for the service account. Figuring out for the actual permissions are left for the reader (CloudBuild needs to be able to create and delete virtual machines and storage buckets for example).

1. CloudBuild is used to create a virtual server.
2. CloudBuild connects to the server and executes a shell script on this remote worker that converts the actual image. Since we need chroot we cant really do this in a container.
3. CloudBuild copies the now gcp'ed version of the file image, uploads it to a temporary storage bucket and creates an GCE image out of it.
4. CloudBuild proceeds to clean up after itself by removing all resources used to build the image.

However if the build for any reason fails resources are left over to run and need to be cleaned up manually. For this a utility script called "clean-failed-builds.sh" is provided that automates the cleanup.

## Makefile

Targets provided:

* build - executes build locally, WARNING! You need to be in a Fedora/CentOS host system and be able to execute this make target as root via sudo or su.
* cloudbuild - executes the build in GCP project
* cloudbuild-async - executes the build in GCP project asyncronously.
* clean-failed-cloudbuild - executes the cleanup script

Makefile variables can be used to describe the names of your VPC network and subnet if the default GCE ones are not available. For example:

```sh
make VPC_SUBNET=my-vpc VPC_SUBNET=my-subnet clean-failed-cloudbuild cloudbuild
```
