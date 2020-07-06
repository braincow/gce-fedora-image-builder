cloudbuild:
	gcloud builds submit --timeout=1h.

cloudbuild-async:
	gcloud builds submit --timeout=1h --async .

clean-failed:
	./clean-failed-builds.sh

# eof