gcloud iam service-accounts create gcloudrigkey \
    --description="gcloudrigkey for cloud run" \
    --display-name="gcloudrigkey"

gcloud projects add-iam-policy-binding massive-seer-267723 \
    --member="serviceAccount:gcloudrigkey@${project_id}.iam.gserviceaccount.com" \
    --role="roles/editor"

gcloud iam service-accounts keys create service_account.json \
  --iam-account "gcloudrigkey@${project_id}.iam.gserviceaccount.com"