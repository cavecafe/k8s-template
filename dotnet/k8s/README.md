
Run this command to create a secret in the same namespace as the service account:

* create .env.{your ENV} file with the following content (example):
  with name in the path of k8s/.env.DEV (or k8s/.env.QA, depending on your environment any of POC, DEV, QA, PROD)
```
namespace=<namespace of project to be used in K8s>
docker_username=<your Docker Hub username>
docker_password=<your Docker Hub token>
docker_email=<your email address for Docker Hub>
exposed_port=<exposed port in public, like 80>
target_port=<target port, like 8080>
node_port=<node port, like 30090>
image_repository=<Docker Hub username>/<Docker Hub registry name>
image_tag=latest
host_name=<your DNS hostname for service>
replicas=<number of replicas for scaling in or out>
run_as_user=<your container user's permission>
run_as_group=<your container permission group>
memory_request=32Mi
cpu_request=60m
```

* Run the following command:
> ./setup-dotnet.sh DEV (any of POC, DEV, QA, PROD, as you set before)
