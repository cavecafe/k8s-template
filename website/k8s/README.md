
Run this command to create a secret in the same namespace as the service account:

* create .env file with the following content:
```
namespace=<namespace_of_the_project>
docker_username=<my_dockerhub_username>
docker_password=<my_dockerhub_token>
docker_email=<my_email@email.com>
image_repository=<dockerhub-user>/<registry-name>
exposed_port="<external port to be used for sevice>"
target_port="<internal target port>"
node_port="<internal node port, ie.30080>"
host_name="<your website DNS host name, i.e. www.yourdomain.com>"
replicas="<count of replicas, i.e. 1>"
image_tag="latest"
run_as_user="<your user's uid, i.e. 1001>"
run_as_group="<your user's gid, i.e. 1001>"
run_as_username="<your app user name, associated with uid and gid>"
memory_request="<i.e. 32Mi>"
cpu_request="<i.e. 40m>"
```

* Run the following command:
```bash
# environment_name is optional
# if not specified, then no environment will be created
> ./setup-website.sh [environment_name, i.e. DEV, QA, PROD, etc.]
```

* The script will create a secret in the same namespace as the service account.
