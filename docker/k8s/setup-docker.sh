#!/bin/bash

function failed() {
   local error=${1:-Undefined error}
   echo "Failed: $error" >&2
   exit 1
}

function addGitIgnore() {
   fileName=$1
   GITIGNORE=".gitignore"
   if [ -f "$GITIGNORE" ]; then
     echo "$GITIGNORE file exists"
   else
     echo "create $GITIGNORE for current directory"
     touch $GITIGNORE
   fi

   if grep -q "$fileName" "$GITIGNORE"; then
     echo "$fileName already exists in $GITIGNORE"
   else
     echo "$fileName" >> "$GITIGNORE"
     echo "$fileName entry to $GITIGNORE"
   fi
}

function downloadTemplate() {
   yml=$1
   repo="https://raw.githubusercontent.com/cavecafe/k8s-template/main/docker/k8s"
   if [ -f "$yml" ]; then
     echo "$yml exists"
   else
     echo "$yml does not exist, downloading from $repo/$yml"
     echo "curl -o $yml $repo/$yml"
     curl -o "$yml" "$repo/$yml"
   fi
}

function applyTemplateEnvironmentValues() {
  env_file=".env.$1"
  # loop all *.yml files in the template directory
  for file in template/*.template.yml; do
    # Read YAML into a variable
    yaml=$(cat "$file")

    # search all keys in .env file and replace the placeholders
    while IFS= read -r line; do
      key=$(echo "$line" | cut -d'=' -f1)
      value=$(echo "$line" | cut -d'=' -f2)
      if [ -z "$value" ]; then
        echo "*** value for $key is empty, skipped"
        # check if yaml contains the key
        if [[ $yaml == *"$key"* ]]; then
          failed "*** value for $key is empty, please update .env.$1 file"
        fi
      else
        yaml=${yaml//\_\_\{$key\}\_\_/$value}
      fi
    done < "$env_file"

    # Write the output to a new file
    new_yml="${file//.template/}"
    new_yml="${new_yml//template\//}"
    echo "$yaml" > "$1/$new_yml"
    echo "created $1/$new_yml"
  done
}

function checkEnvironment() {
  mkdir -p "$1" || failed "failed to create $1 directory"

  # Fill the values of .env.$ENV file
  env_file=".env.$1"
  while IFS= read -r line; do
    key=$(echo "$line" | cut -d'=' -f1)
    value=$(echo "$line" | cut -d'=' -f2)
    echo "key: '$key', value: '$value'"

    if [ -z "$value" ]; then
      echo "*** value for $key is empty, skipped"
    fi
  done < "$env_file"

  # Show the updated .env.$1 file
  echo ""
  echo "updated .env.$1 file:"
  echo ""
  while IFS= read -r line; do
    echo "$line"
  done < "$env_file"

  echo ""
  read -r -n 1 -p "write changes to $env_file? (Press 'Y' to proceed) " confirm
  if [[ $confirm = "y" ]] || [[ $confirm = "Y" ]]; then
    while IFS= read -r line; do
      echo "$line"
    done < "$env_file" > temp && mv temp "$env_file"
    echo ".env.$1 file updated!"
  else
    failed "confirmed not to update .env.$1 file"
  fi

  # get value of the key namespace from .env file
  NAMESPACE=$(grep namespace .env."$1" | cut -d'=' -f2)
  echo "Namespace: $NAMESPACE"
  if [ -z "$NAMESPACE" ]; then
    failed "namespace is empty, please update .env.$1 file"
  fi
}

function initEnvironment() {

  if [ -z "$1" ]; then
    failed "ENV is empty, ENV can be (POC, DEV, QA, or PROD)"
  fi

  # Check if ENV is valid
  if [ "$1" != "POC" ] && [ "$1" != "DEV" ] && [ "$1" != "QA" ] && [ "$1" != "PROD" ]; then
    failed "ENV can be (POC, DEV, QA, or PROD)"
  fi

  # Check if .env file exists
  if [ ! -f ".env.$1" ]; then
    echo "No .env.$1 file found!"
    read -r -n 1 -p "Create .env.$1 file? (Press 'Y' to proceed)" confirm
    if [[ $confirm = "y" ]] || [[ $confirm = "Y" ]]; then
      touch .env."$1"
      echo "creating empty .env.$1 file, please refer to README.md to fill the values."
      cat <<EOF > ".env.$1"
namespace=
project_name=
docker_username=
docker_password=
docker_email=
exposed_port=
target_port=
node_port=
host_name=
replicas=
image_repository=
image_tag=
run_as_user=
run_as_group=
memory_request=
cpu_request=
EOF
    else
      failed "confirmed do not to create .env.$1 file"
    fi
  fi
}

function applyIngressController() {
  kubectl create namespace ingress-nginx
  latest_version=$(curl -s https://api.github.com/repos/kubernetes/ingress-nginx/releases/latest | grep "tag_name" | cut -d'"' -f4)
  cluster_version=$1
  echo "Latest version of ingress-nginx: $latest_version"
  echo "Cluster is using '$cluster_version', used it instead."
  echo "Installing ingress-nginx..."
  deploy_url="https://raw.githubusercontent.com/kubernetes/ingress-nginx/$cluster_version/deploy/static/provider/cloud/deploy.yaml"

  kubectl apply -f "$deploy_url" || failed "failed to apply ingress-nginx"
  echo "Waiting for ingress-nginx to be ready..."
  sleep 15
}

mkdir -p template || failed "failed to create template directory"
downloadTemplate template/namespace.template.yml
downloadTemplate template/network.template.yml
downloadTemplate template/secret.template.yml
downloadTemplate template/deployment.template.yml

addGitIgnore .env
addGitIgnore .env.*
addGitIgnore .secret.yml
addGitIgnore .secret.*.yml
addGitIgnore .DS_Store

ENV=$1
echo "ENV: $ENV"
initEnvironment "$ENV"
checkEnvironment "$ENV"
applyTemplateEnvironmentValues "$ENV"

kubectl apply -f "$ENV"/namespace.yml || failed "failed to apply $ENV/namespace.yml"
kubectl apply -f "$ENV"/secret.yml || failed "failed to apply $ENV/secret.yml"
mv "$ENV"/secret.yml "$ENV"/.secret.yml

# (TODO) need to add the logic to find the installed version of ingress controller 'controller-v1.9.6'
CONTROLLER_VERSION=controller-v1.9.6
echo "CONTROLLER_VERSION: $CONTROLLER_VERSION"
applyIngressController $CONTROLLER_VERSION

kubectl apply -f "$ENV"/network.yml || failed "failed to apply $ENV/network.yml"

# deployment.yml will be used to connected with CI/CD pipeline (i.e. GitHub Actions)
# kubectl apply -f "$ENV"/deployment.yml || failed "failed to apply $ENV/deployment.yml"
