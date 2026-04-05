podman run -d \
    --name openshift-claw \
    --env-file .env \
    -v ./data:/var/lib/openclaw:Z \
    --tmpfs /tmp:size=256m \
    -p 18789:18789 \
    openshift-claw
