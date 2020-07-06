#!/bin/bash

STATUS_ARRAY=(FAILURE CANCELLED TIMEOUT)
for GCEINSTANCE in $(gcloud compute instances list --format "value(NAME)" |grep -i fedora |grep -i builder ); do
    # extract build id from gce instance
    BUILD_ID=$(echo $GCEINSTANCE | sed 's/fedora.*-builder-//g')
    # check status of the build job with the id
    STATUS=$(gcloud builds list --format="table(ID,STATUS)" | grep $BUILD_ID | awk '{print $2}')
    if [[ " ${STATUS_ARRAY[@]} " =~ " ${STATUS} " ]]; then
        echo "'$BUILD_ID' in state '$STATUS'"
        # it has failed, remove the template
        gcloud compute instances delete $GCEINSTANCE --quiet || true
        # also remove the firewall
        gcloud compute firewall-rules delete ${GCEINSTANCE}-allow-ssh --quiet || true
    fi
done

# eof