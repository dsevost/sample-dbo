# Simple DBO Application
## Build from scratch
```
$ export PROJECT_NAME=example-dbo
$ oc new-project $PROJECT_NAME
```
### Load Envirinment variables
```
$ vi env.sh
$ source env.sh
```

### Import Source Images to OpenShift

1. Create ImageSteams directly from remote registry

Create import secret and link it with 'default' service-account (to pull images from private registry)
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
$ oc import-image $FRONTEND_IMAGE_NAME --from=docker.io/infinit10/$FRONTEND_IMAGE_NAME --scheduled --confirm
$ oc import-image $INTEGRATION_IMAGE_NAME --from=docker.io/infinit10/$INTEGRATION_IMAGE_NAME --scheduled --confirm
$ oc import-image $BACKEND_IMAGE_NAME --from=docker.io/infinit10/$BACKEND_IMAGE_NAME --scheduled --confirm
```

2. Create a mirrors of remote images locally in OpenShift Registry
```
$ mkdir tmp
$ oc get secrets $(oc get secrets | awk '/builder-dockercfg/ { print $1; }') \
    -o jsonpath='{ .data.\.dockercfg }' | base64 -d > tmp/config.json
$ sed -i 's/}$/}}/; /^{/i{ "auths": ' tmp/config.json
$ for i in $BACKEND_IMAGE_NAME $FRONTEND_IMAGE_NAME $INTEGRATION_IMAGE_NAME ; do \
    skopeo copy --screds=$DOCKER_HUB_USER:$DOCKER_HUB_PASS \
	--dest-tls-verify=false \
	--dest-cert-dir=. \
	--authfile=tmp/config.json \
	docker://docker.io/infinit10/$i \
	docker://docker-registry.default.svc:5000/$PROJECT_NAME/$i
  done
```

### Create Integration Service from imagestream
```
$ oc new-app --name ${INTEGRATION_SVC} $INTEGRATION_IMAGE_NAME -e PARAMS="--server.port=8080"
$ oc expose dc/${INTEGRATION_SVC} --name integrator --port 8080 --target-port 8080
```

### Create Core Service
```
$ oc new-app --name ${BACKEND_SVC} $BACKEND_IMAGE_NAME \
    -e DRIVER_CLASS_NAME=oracle.jdbc.OracleDriver \
    -e INTEGRATOR_URL=http://integrator:8080/integration/v1 \
    -e DRIVER=ojdbc8.jar \
    -e DATASOURCE_URL=jdbc:oracle:thin:@//$DB_HOST:$DB_PORT/$DB_SID \
    -e DATASOURCE_USER=$DB_USER \
    -e DATASOURCE_PASSWORD=$DB_PASS \
    -e FLYWAY_LOCATIONS=classpath:db/oracle
$ oc expose dc/${BACKEND_SVC} --name core --port 8080 --target-port 8080
```

### Prepare FileServer Endpoint and service
```
$ oc create -f openshift/fileserver-svc.yaml
$ oc create -f openshift/fileserver-ep.yaml
$ oc get ep,svc
```

### Manage Customer Service
```
$ oc new-app --name ${FRONTEND_SVC} $FRONTEND_IMAGE_NAME
$ # cancel and pause rolling updates and triggering config changes
$ oc rollout cancel dc/${FRONTEND_SVC}
$ oc rollout pause dc/${FRONTEND_SVC}
$ # override nginx configuration
$ oc create cm nginx-config --from-file=conf/nginx.conf
$ oc create cm default-site-config --from-file=conf/default
$ oc create cm include-config --from-file=conf/default.conf
$ oc set volume dc/${FRONTEND_SVC} --add \
    --name default-site \
    --mount-path=/etc/nginx/sites-enabled/default \
    --sub-path=default \
    -t configmap \
    --configmap-name=default-site-config
$ oc set volume dc/${FRONTEND_SVC} --add \
    --name include-config \
    --mount-path=/etc/nginx/conf.d \
    -t configmap \
    --configmap-name=include-config
$ oc set volume dc/${FRONTEND_SVC} --add \
    --name nginx-config \
    --mount-path=/etc/nginx/nginx.conf \
    --sub-path=nginx.conf \
    -t configmap \
    --configmap-name=nginx-config
$ oc set volume dc/${FRONTEND_SVC} --add \
    --name cache \
    --mount-path=/var/cache/nginx \
    -t emptyDir \
$ # check attached volumes with new nginx configuration
$ oc set volumes dc/${FRONTEND_SVC}
$ # enable rollout for service ${FRONTEND_SVC}
$ oc rollout resume dc/${FRONTEND_SVC}
$ oc expose dc/${FRONTEND_SVC} --name ${FRONTEND_SVC}-secure --port 8443 --target-port 8443
$ oc create route passthrough --service=${FRONTEND_SVC}-secure
$ # open url
$ echo URL=https://$(oc get route ${FRONTEND_SVC}-secure -o jsonpath='{ .spec.host }')
```
## Build from template
### Create project and load template
```
$ oc new-project example-dbo
$ oc create -f openshift/simple-dbo.yaml
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
### Build dbo application
```
$ oc describe template simple-dbo-template
$ oc new-app simple-dbo-template \
    -p APP_NAME=my-dbo \
    -p DB_PASSWORD=$DB_PASS \
    -p DB_USER=$DB_PASS \
    -p DB_HOST=$DB_HOST \
    -p DB_PORT=$DB_PORT \
    -p DB_NAME=$DB_SID \
    -p FILESERVER_IP=$FILESERVER_IP \
    -p FILESERVER_PORT=$FILESERVER_PORT
```
