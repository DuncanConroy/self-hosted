echo "${_group}Checking minimum requirements ..."

source install/_min-requirements.sh

DOCKER_VERSION=$($CONTAINER_ENGINE version --format '{{.Server.Version}}' || echo '')
if [[ -z "$DOCKER_VERSION" ]]; then
  echo "FAIL: Unable to get $CONTAINER_ENGINE version, is the $CONTAINER_ENGINE daemon running?"
  exit 1
fi

if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
  if ! vergte ${DOCKER_VERSION//v/} $MIN_DOCKER_VERSION; then
    echo "FAIL: Expected minimum docker version to be $MIN_DOCKER_VERSION but found $DOCKER_VERSION"
    exit 1
  fi
  if ! vergte ${COMPOSE_VERSION//v/} $MIN_COMPOSE_VERSION; then
    echo "FAIL: Expected minimum $dc_base version to be $MIN_COMPOSE_VERSION but found $COMPOSE_VERSION"
    exit 1
  fi
elif [[ "$CONTAINER_ENGINE" == "podman" ]]; then
  if ! vergte ${DOCKER_VERSION//v/} $MIN_PODMAN_VERSION; then
    echo "FAIL: Expected minimum podman version to be $MIN_PODMAN_VERSION but found $DOCKER_VERSION"
    exit 1
  fi
  if ! vergte ${COMPOSE_VERSION//v/} $MIN_PODMAN_COMPOSE_VERSION; then
    echo "FAIL: Expected minimum $dc_base version to be $MIN_PODMAN_COMPOSE_VERSION but found $COMPOSE_VERSION"
    exit 1
  fi
fi
echo "Found $CONTAINER_ENGINE version $DOCKER_VERSION"
echo "Found $CONTAINER_ENGINE Compose version $COMPOSE_VERSION"

CPU_AVAILABLE_IN_DOCKER=$($CONTAINER_ENGINE run --rm busybox nproc --all)
if [[ "$CPU_AVAILABLE_IN_DOCKER" -lt "$MIN_CPU_HARD" ]]; then
  echo "FAIL: Required minimum CPU cores available to Docker is $MIN_CPU_HARD, found $CPU_AVAILABLE_IN_DOCKER"
  exit 1
fi

RAM_AVAILABLE_IN_DOCKER=$($CONTAINER_ENGINE run --rm busybox free -m 2>/dev/null | awk '/Mem/ {print $2}')
if [[ "$RAM_AVAILABLE_IN_DOCKER" -lt "$MIN_RAM_HARD" ]]; then
  echo "FAIL: Required minimum RAM available to Docker is $MIN_RAM_HARD MB, found $RAM_AVAILABLE_IN_DOCKER MB"
  exit 1
fi

#SSE4.2 required by Clickhouse (https://clickhouse.yandex/docs/en/operations/requirements/)
# On KVM, cpuinfo could falsely not report SSE 4.2 support, so skip the check. https://github.com/ClickHouse/ClickHouse/issues/20#issuecomment-226849297
# This may also happen on other virtualization software such as on VMWare ESXi hosts.
IS_KVM=$($CONTAINER_ENGINE run --rm busybox grep -c 'Common KVM processor' /proc/cpuinfo || :)
if [[ ! "$SKIP_SSE42_REQUIREMENTS" -eq 1 && "$IS_KVM" -eq 0 && "$DOCKER_ARCH" = "x86_64" ]]; then
  SUPPORTS_SSE42=$($CONTAINER_ENGINE run --rm busybox grep -c sse4_2 /proc/cpuinfo || :)
  if [[ "$SUPPORTS_SSE42" -eq 0 ]]; then
    echo "FAIL: The CPU your machine is running on does not support the SSE 4.2 instruction set, which is required for one of the services Sentry uses (Clickhouse). See https://github.com/getsentry/self-hosted/issues/340 for more info."
    exit 1
  fi
fi

echo "${_endgroup}"
