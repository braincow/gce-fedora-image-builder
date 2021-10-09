VPC_NETWORK=default
VPC_SUBNET=default

build:
	./fedora-gce-builder.sh

cloudbuild:
	gcloud builds submit --timeout=1h . --substitutions=_BUILD_NETWORK=bcows-vpc,_BUILD_SUBNET=europe-north1

cloudbuild-async:
	gcloud builds submit --timeout=1h --async . --substitutions=_BUILD_NETWORK=${VPC_NETWORK},_BUILD_SUBNET=${VPC_SUBNET}

clean-failed-cloudbuild:
	./clean-failed-builds.sh

# eof
