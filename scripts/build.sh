#!/usr/bin/env bash
set -e
trap 'error "$(printf "Command \`%s\` at $BASH_SOURCE:$LINENO failed with exit code $?" "$BASH_COMMAND")"' ERR

## find directory where this script is located following symlinks if neccessary
readonly BASE_DIR="$(
  cd "$(
    dirname "$(
      (readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}") \
        | sed -e "s#^../#$(dirname "$(dirname "${BASH_SOURCE[0]}")")/#"
    )"
  )" >/dev/null \
  && pwd
)/.."
pushd ${BASE_DIR} >/dev/null

function error {
  >&2 printf "\033[31mERROR\033[0m: $@\n"
}
function fatal {
  error "$@"
  exit -1
}
function warning {
  >&2 printf "\033[33mWARNING\033[0m: $@\n"
}
function version {
  echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }';
}


## if --push is passed as first argument to script, this will login to docker hub and push images
PUSH_FLAG=${PUSH_FLAG:-0}
if [[ "${1:-}" = "--push" ]]; then
  PUSH_FLAG=1
  SEARCH_PATH="${2:-}"
else
  SEARCH_PATH="${1:-}"
fi

## since fpm images no longer can be traversed, this script should require a search path vs defaulting to build all
if [[ -z ${SEARCH_PATH} ]]; then
  fatal "Missing search path. Please try again passing an image type as an argument."
fi

## login to docker hub as needed
if [[ ${PUSH_FLAG} != 0 && ${PRE_AUTH:-0} != 1 ]]; then
  if [[ ${DOCKER_USERNAME:-} ]]; then
    echo "Attempting non-interactive docker login (via provided credentials)"
    echo "${DOCKER_PASSWORD:-}" | docker login -u "${DOCKER_USERNAME:-}" --password-stdin ${DOCKER_REGISTRY:-docker.io}
  elif [[ -t 1 ]]; then
    echo "Attempting interactive docker login (tty)"
    docker login ${DOCKER_REGISTRY:-docker.io}
  fi
fi

## define image repository to push
WARDEN_IMAGE_REPOSITORY="${WARDEN_IMAGE_REPOSITORY:-"docker.io/ytorbyk"}"

docker buildx create --use

export PHP_SOURCE_IMAGE="${PHP_SOURCE_IMAGE:-"docker.io/davidalger/php"}"
if [[ "${INDEV_FLAG:-1}" != "0" ]]; then
  export PHP_SOURCE_IMAGE="${PHP_SOURCE_IMAGE}-indev"
fi

export ENV_SOURCE_IMAGE="${ENV_SOURCE_IMAGE:-"${WARDEN_IMAGE_REPOSITORY}/php-fpm"}"
if [[ "${INDEV_FLAG:-1}" != "0" ]]; then
  export ENV_SOURCE_IMAGE="${ENV_SOURCE_IMAGE}-indev"
fi

## iterate over and build each Dockerfile
for file in $(find ${SEARCH_PATH} -type f -name Dockerfile | sort -V); do
    BUILD_DIR="$(dirname "${file}")"
    IMAGE_TAG="${WARDEN_IMAGE_REPOSITORY}/$(echo "${BUILD_DIR}" | cut -d/ -f1)"
    if [[ "${INDEV_FLAG:-1}" != "0" ]]; then
      IMAGE_TAG="${IMAGE_TAG}-indev"
    fi
    IMAGE_SUFFIX="$(echo "${BUILD_DIR}" | cut -d/ -f2- -s | tr / - | sed 's/^-//')"
    echo $IMAGE_SUFFIX

    ## due to build matrix requirements, magento1 and magento2 specific varients are built in separate invocation
    if [[ ${SEARCH_PATH} == "php-fpm" ]] && [[ ${file} =~ php-fpm/magento[1-2] ]]; then
      continue;
    fi

    ## fpm images will not have each version in a directory tree; require version be passed
    ## in as env variable for use as a build argument
    BUILD_ARGS=()
    if [[ ${SEARCH_PATH} = *fpm* ]]; then
      if [[ -z ${PHP_VERSION} ]]; then
        fatal "Building ${SEARCH_PATH} images requires PHP_VERSION env variable be set."
      fi

      ## define default sources for main php and environment images
      BUILD_ARGS+=("--build-arg")
      BUILD_ARGS+=("PHP_SOURCE_IMAGE")

      BUILD_ARGS+=("--build-arg")
      BUILD_ARGS+=("ENV_SOURCE_IMAGE")

      export PHP_VERSION

      IMAGE_TAG+=":${PHP_VERSION}"
      if [[ ${IMAGE_SUFFIX} ]]; then
        IMAGE_TAG+="-${IMAGE_SUFFIX}"
      fi
      BUILD_ARGS+=("--build-arg")
      BUILD_ARGS+=("PHP_VERSION")

      # Support for PHP 8 images which require (temporarily at least) use of non-loader variant of base image
      if [[ ${PHP_VARIANT:-} ]]; then
        export PHP_VARIANT
        BUILD_ARGS+=("--build-arg")
        BUILD_ARGS+=("PHP_VARIANT")
      fi
    else
      IMAGE_TAG+=":${IMAGE_SUFFIX}"
    fi

    # Skip build of xdebug3 fpm images on older versions of PHP (it requires PHP 7.2 or greater)
    if [[ ${IMAGE_SUFFIX} =~ xdebug3 ]] && test $(version ${PHP_VERSION}) -lt $(version "7.2"); then
      warning "Skipping build for ${IMAGE_TAG} (xdebug3 is unavailable for PHP ${PHP_VERSION})"
      continue
    fi

    if [[ -d "$(echo ${BUILD_DIR} | cut -d/ -f1)/context" ]]; then
      BUILD_CONTEXT="$(echo ${BUILD_DIR} | cut -d/ -f1)/context"
    else
      BUILD_CONTEXT="${BUILD_DIR}"
    fi

    printf "\e[01;31m==> building ${IMAGE_TAG} from ${BUILD_DIR}/Dockerfile with context ${BUILD_CONTEXT}\033[0m\n"
    if [[ $PUSH_FLAG != 0 ]]; then PUSH_ARG="--push"; fi
    docker buildx build --platform=linux/arm64,linux/amd64 ${PUSH_ARG:-} -t "${IMAGE_TAG}" -f ${BUILD_DIR}/Dockerfile ${BUILD_ARGS[@]} ${BUILD_CONTEXT}
done
