#!/bin/bash

function failed() {
   local error=${1:-Undefined error}
   echo "Failed: $error" >&2
   exit 1
}

#function addGitIgnore() {
#  gitignore_file=".gitignore"
#  current_dir=$(pwd)
#
#  while [ "$current_dir" != "/" ]; do
#    if [ -f "$current_dir/$gitignore_file" ]; then
#      break
#    fi
#    current_dir=$(dirname "$current_dir")
#  done
#
#  if [ -f "$current_dir/$gitignore_file" ]; then
#    entry="/$(basename $PWD)/.*"
#    if grep -q "$entry" "$current_dir/$gitignore_file"; then
#      echo "Entry already exists in $gitignore_file"
#    else
#      echo "$entry" >> "$current_dir/$gitignore_file"
#      echo "Added entry to $gitignore_file"
#    fi
#  else
#    echo "No .gitignore file found!"
#    echo "Be aware that sensitive files may be committed to your repository."
#  fi
#}

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
   repo="https://raw.githubusercontent.com/cavecafe/k8s-template/main/dotnet/k8s"
   if [ -f "$yml" ]; then
     echo "$yml exists"
   else
     echo "$yml does not exist, downloading from $repo/$yml"
     echo "curl -o $yml $repo/$yml"
     curl -o "$yml" "$repo/$yml"
   fi
}

ENV=$1
echo "ENV: $ENV"
if [ -z "$ENV" ]; then
  failed "ENV is empty, ENV can be (DEV, QA, or PROD)"
fi


env_file=".env"
while IFS= read -r line; do
  key=$(echo "$line" | cut -d'=' -f1)
  value=$(echo "$line" | cut -d'=' -f2)

  if [ -z "$value" ]; then
    read -r -p "Enter value for $key: " new_value
    line="$key=$new_value"
  fi
done < "$env_file"

echo ""
echo "Updated .env file:"
echo ""
while IFS= read -r line; do
  echo "$line"
done < "$env_file"

echo ""
read -r -p "Write changes to $env_file? (y/n) " confirm
if [[ $confirm = "y" ]] || [[ $confirm = "Y" ]]; then
  while IFS= read -r line; do
    echo "$line"
  done < "$env_file" > temp && mv temp "$env_file"
  echo ".env file updated!"
  addGitIgnore .env
  addGitIgnore .env.*
  addGitIgnore .secret.yml
  addGitIgnore .secret.*.yml
  addGitIgnore .DS_Store
else
  failed "confirmed not to update .env file"
fi

# Load values from .env file
source .env

# get value of the key namespace from .env file
NAMESPACE=$(grep namespace .env | cut -d'=' -f2)
echo "Namespace: $NAMESPACE"

# loop all *.yml files in the template directory
for file in template/*.template.yml; do
  # Read YAML into a variable
  yaml=$(cat "$file")

  # search all keys in .env file and replace the placeholders
  while IFS= read -r line; do
    key=$(echo "$line" | cut -d'=' -f1)
    value=$(echo "$line" | cut -d'=' -f2)
    yaml=${yaml//\_\_\{$key\}\_\_/$value}
  done < "$env_file"

  # Write the output to a new file
  new_yml="${file//.template/}"
  new_yml="${new_yml//template\//}"
  echo "$yaml" > "$new_yml"
  echo "created $new_yml"
done

kubectl apply -f namespace.yml || failed "failed to apply namespace"
kubectl apply -f secret.yml || failed "failed to apply secret"
mv secret.yml .secret.yml

kubectl create namespace ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.6/deploy/static/provider/cloud/deploy.yaml || failed "failed to apply ingress-nginx"
echo "Waiting for ingress-nginx to be ready..."
sleep 20
kubectl apply -f network.yml
kubectl apply -f deployment.yml || failed "failed to apply deployment"
