echo "${_group}Preparing for air-gapped environment ..."

echo ""

execute_on_remote() {
  ssh "${REMOTE_HOST}" "$1"
  if [ $? -ne 0 ]; then
    echo "Failed to connect to ${REMOTE_HOST}"
    exit 1
  fi
}

$dc pull -q

for image in $($dc config --images|sort|uniq); do
  echo "Extracting $image with $CONTAINER_ENGINE"
  echo "Finding image ID for $image"
  IMAGE_ID=$($CONTAINER_ENGINE images -q --filter=reference="*$image*")
  if [ -z "$IMAGE_ID" ]; then
    echo "Failed to find image ID for $image"
    exit 1
  fi
  echo "Exporting $image ($IMAGE_ID) to /tmp/$IMAGE_ID.tar.gz"

  $CONTAINER_ENGINE save -o /tmp/$IMAGE_ID.tar $image
  tar -C /tmp -czf /tmp/$IMAGE_ID.tar.gz $IMAGE_ID.tar

  if [[ -z ${REMOTE_HOST+set} ]]; then
  echo "REMOTE_HOST not specified. Skipping copying to and extraction on remote machine."
  else
    echo "Copying /tmp/$IMAGE_ID.tar.gz to ${REMOTE_HOST}"
    scp /tmp/$IMAGE_ID.tar.gz "${REMOTE_HOST}":/tmp/$IMAGE_ID.tar.gz
    if [ $? -ne 0 ]; then
      echo "Failed to connect to ${REMOTE_HOST}"
      exit 1
    fi
    echo "Copying done."

    echo "Extracting /tmp/${IMAGE_ID}.tar from /tmp/${IMAGE_ID}.tar.gz on ${REMOTE_HOST}"
    execute_on_remote "tar -xzf /tmp/${IMAGE_ID}.tar.gz -C /tmp"
    
    echo "Load docker image $image (${IMAGE_ID}) on ${REMOTE_HOST}"
    execute_on_remote "podman load -i /tmp/${IMAGE_ID}.tar"

    echo "Removing /tmp/${IMAGE_ID}.tar* from ${REMOTE_HOST}"
    execute_on_remote "rm /tmp/${IMAGE_ID}.tar*"
    
    echo "Removing /tmp/${IMAGE_ID}.tar from local"
    rm /tmp/${IMAGE_ID}.tar*
  fi
done

echo ""
echo "Done"
echo "${_endgroup}"
