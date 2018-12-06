# Simple DBO Application
## Build from scratch
```
$ oc new-project sample-dbo
```
### Load Envirinment variables
```
$ vi env.sh
$ source env.sh
```

### Create import secret and link it with 'default' service-account (to pull images from private registry)
```
$ oc create secret docker-registry $DOCKER_SECRET_NAME \
    --docker-server=docker.io \
    --docker-username=$DOCKER_HUB_USER \
    --docker-password=$DOCKER_HUNB_PASS \
    --docker-email=$DOCKER_HUB_EMAIL

$ oc get secret $DOCKER_SECRET_NAME -o jsonpath='{ .data.\.dockerconfigjson }' |base64 -d
$ oc secrets link default $DOCKER_SECRET_NAME --for=pull
```

### Load Images into OpenShift project
```
$ oc import-image customerui:altyn --from=docker.io/infinit10/customerui:altyn --scheduled --confirm
$ oc import-image integration-service:altyn --from=docker.io/infinit10/integration-service:altyn --scheduled --confirm
$ oc import-image infinit10/core:oracle_scripts --from=docker.io/infinit10/core:oracle_scripts --scheduled --confirm
```

### Create Integration Service from imagestream
```
$ oc new-app --name integration-service integration-service:altyn -e PARAMS="--server.port=8080"
$ oc expose dc/integration-service --name integrator --port 8080 --target-port 8080
```

### Create Core Service
```
$ oc new-app --name core core:oracle_scripts \
    -e DRIVER_CLASS_NAME=oracle.jdbc.OracleDriver \
    -e INTEGRATOR_URL=http://integrator:8080/integration/v1 \
    -e DRIVER=ojdbc8.jar \
    -e DATASOURCE_URL=jdbc:oracle:thin:@//$DB_HOST:$DB_PORT/$DB_SID \
    -e DATASOURCE_USER=$DB_USER \
    -e DATASOURCE_PASSWORD=$DB_PASS \
    -e FLYWAY_LOCATIONS=classpath:db/oracle
$ oc expose dc/core --name core --port 8080 --target-port 8080
```

### Prepare FileServer Endpoint and service
```
$ oc create -f openshift/fileserver-svc.yaml
$ oc create -f openshift/fileserver-ep.yaml
$ oc get ep,svc
```

### Manage Customerui Service
```
$ oc new-app --name customerui customerui:altyn
$ # cancel and pause rolling updates and triggering config changes
$ oc rollout cancel dc/customerui
$ oc rollout pause dc/customerui
$ # override nginx configuration
$ oc create cm nginx-config --from-file=conf/nginx.conf
$ oc create cm default-site-config --from-file=conf/default
$ oc create cm include-config --from-file=conf/default.conf
$ oc set volume dc/customerui --add \
    --name default-site \
    --mount-path=/etc/nginx/sites-enabled/default \
    --sub-path=default \
    -t configmap \
    --configmap-name=default-site-config
$ oc set volume dc/customerui --add \
    --name include-config \
    --mount-path=/etc/nginx/conf.d \
    -t configmap \
    --configmap-name=include-config
$ oc set volume dc/customerui --add \
    --name nginx-config \
    --mount-path=/etc/nginx/nginx.conf \
    --sub-path=nginx.conf \
    -t configmap \
    --configmap-name=nginx-config
$ oc set volume dc/customerui --add \
    --name cache \
    --mount-path=/var/cache/nginx \
    -t emptyDir \
$ # check attached volumes with new nginx configuration
$ oc set volumes dc/customerui
$ # enable rollout for service Customerui
$ oc rollout resume dc/customerui
$ oc expose dc/customerui --name customerui-secure --port 8443 --target-port 8443
$ oc create route passthrough --service=customerui-secure
$ # open url
$ echo URL=https://$(oc get route customerui-secure -o jsonpath='{ .spec.host }')
```
## Build from template
### Create project and load template
```
$ oc new-project sample-dbo
$ oc create -f openshift/altyn-dbo.yaml
$ vi 
```
### Load Envirinment variables
```
$ vi env.sh
$ source env.sh
```
### Create import secret and link it with 'default' service-account (to pull images from private registry)
```
$ oc create secret docker-registry $DOCKER_SECRET_NAME \
    --docker-server=docker.io \
    --docker-username=$DOCKER_HUB_USER \
    --docker-password=$DOCKER_HUNB_PASS \
    --docker-email=$DOCKER_HUB_EMAIL

$ oc get secret $DOCKER_SECRET_NAME -o jsonpath='{ .data.\.dockerconfigjson }' |base64 -d
$ oc secrets link default $DOCKER_SECRET_NAME --for=pull
```
### Build sample-dbo application
```
$ oc describe template altyn-dbo-template
$ oc new-app altyn-dbo-template \
    -p APP_NAME=my-dbo \
    -p DB_PASSWORD=$DB_PASS \
    -p DB_USER=$DB_PASS \
    -p DB_HOST=$DB_HOST \
    -p DB_PORT=$DB_PORT \
    -p DB_NAME=$DB_SID \
    -p FILESERVER_IP=$FILESERVER_IP \
    -p FILESERVER_PORT=$FILESERVER_PORT
```
