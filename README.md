# Twoge web app deployment on Minikube/EKS wih CI/CD in github actions

## Prerequiste:
- Dockerhub account
- Aws account 
- Dockerfile 
- Vscode 
- OPS(ubuntu,wsl2.etc)

## Before starting up minikube make sure you have a dockerfile already made for the application we are going to deploy and have it pushed to the docker repository 
```bash
FROM python:3-alpine
ENV SQLALCHEMY_DATABASE_URI="postgresql://username:password@db-host:port/database"
RUN apk update && \
    apk add --no-cache build-base libffi-dev openssl-dev
COPY . /app
WORKDIR /app
RUN pip install -r requirements.txt
EXPOSE 80
CMD ["gunicorn"  , "--bind", "0.0.0.0:80", "app:app"]

```
## Above me is the contents of the Dockerfile I'm going to use
- how to push Dockerfile image to docker repo 
```bash
docker build -t "<docker-username>/<docker-image-name>:<tag>" -f <specific dockerfile> .
docker push <docker-username>/<docker-image-name>:<tag>
```

## Start up Minikube
```bash
minikube start
```
## Create database directory called "db-dep" to store Deployment, Secret, Service, StorageClass, Resource quota, PersistenVolumeClamim yml files
- db_dep/db-dep.yml:
```bash
apiVersion: apps/v1
kind: Deployment
metadata:
  name: twoge-db
  namespace: edwin
spec:
  selector:
    matchLabels:
      app: twoge-db
  template:
    metadata:
      labels:
        app: twoge-db
    spec:
      containers:
      - name: twoge-db
        image: postgres
        volumeMounts:
        - name: db-data 
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            cpu: "100m"
            memory: "100Mi"
          limits:
            cpu: "200m"
            memory: "200Mi"
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: username
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: database
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
        startupProbe:
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 3
          exec:
            command:
              - pg_isready
              - -q 
              - -d 
              - twoge 
              - -U 
              - cp2023
        ports:
        - containerPort: 5432
      volumes:
      - name: db-data
        persistentVolumeClaim:
          claimName: db-vpc

```
- db_dep/db-secret.yml:

```bash
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  namespace: edwin 
type: Opaque
data:
  username: Y3AyMDIz 
  database: dHdvZ2U= 
  password: ZWR3aW4yMDIzCg== 
  port: NTQzMg== 
```
- db_dep/db-svc.yml:
```bash
apiVersion: v1
kind: Service
metadata:
  name: db-service
  namespace: edwin
spec:
  selector:
    app: twoge-db
  type: ClusterIP
  ports:
  - port: 5432
    targetPort: 5432
```
- db_dep/db-storage.yml:
```bash
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: db-storage
  namespace: edwin
provisioner: k8s.io/minikube-hostpath

# apiVersion: storage.k8s.io/v1
# kind: StorageClass
# metadata:
#   name: db-storage
#   namespace: edwin
# provisioner: ebs.csi.aws.com
# volumeBindingMode: WaitForFirstConsumer
# allowVolumeExpansion: true


```
- db_dep/db-quota:
```bash
apiVersion: v1
kind: ResourceQuota
metadata:
  name: db-quota
  namespace: edwin 
spec:
  hard:
    pods: 10
    requests.cpu: "1"
    requests.memory: 2Gi
    limits.cpu: "2"
    limits.memory: 4Gi
```
- db-dep/db-pvc:
```bash
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: db-vpc
  namespace: edwin
spec:
  storageClassName: db-storage
  resources:
    requests:
      storage: 2Gi  
  accessModes:
    - ReadWriteOnce


```

## Create twoge directory called "twoge_dep" to store Deployment, Secret, Service, StorageClass, PersistenVolumeClamim yml files
- twoge_dep/twoge-dep.yml:
```bash
apiVersion: apps/v1
kind: Deployment
metadata:
  name: twoge
  namespace: edwin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: twoge
  template:
    metadata:
      labels:
        app: twoge
    spec:
      containers:
      - name: twoge
        image: epquito/twoge-flask:v1
        resources:
          requests:
            cpu: "50m"
            memory: "50Mi"
          limits:
            cpu: "100m"
            memory: "100Mi"
        volumeMounts:
        - name: data-volume
          mountPath: /data

        env:
        - name: SQLALCHEMY_DATABASE_URI
          valueFrom:
            secretKeyRef:
              name: twoge-secret
              key: db_url
  
        # - name: SQLALCHEMY_DATABASE_URI
        #   valueFrom:
        #     configMapKeyRef:
        #       name: twoge-configmap
        #       key: db_host


        readinessProbe:
          httpGet:
            path: /
            port: 80
          successThreshold: 5
          periodSeconds: 5
        ports:
        - containerPort: 80
      volumes: 
      - name: data-volume
        persistentVolumeClaim:
          claimName: twoge-vpc
```
- twoge_dep/twoge-secret.yml:

```bash
apiVersion: v1
kind: Secret
metadata:
  name: twoge-secret
  namespace: edwin
type: Opaque
data:
  db_url: cG9zdGdyZXNxbDovL2NwMjAyMzplZHdpbjIwMjNAZGItc2VydmljZTo1NDMyL3R3b2dl
```
- twoge_dep/twoge-svc.yml:
```bash
apiVersion: v1
kind: Service
metadata:
  name: twoge-service 
  namespace: edwin
spec:
  selector:
    app: twoge
  # type: LoadBalancer
  type: NodePort
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30005

```
- twoge_dep/twoge-storage.yml:
```bash
# apiVersion: storage.k8s.io/v1
# kind: StorageClass
# metadata:
#   name: twoge-storage 
#   namespace: edwin
# provisioner: ebs.csi.aws.com
# volumeBindingMode: WaitForFirstConsumer
# allowVolumeExpansion: true

apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: twoge-storage
  namespace: edwin
provisioner: k8s.io/minikube-hostpath
```
- twoge_dep/twoge-pvc:
```bash
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: twoge-vpc
  namespace: edwin
spec:
  storageClassName: twoge-storage
  resources:
    requests:
      storage: 2Gi
  accessModes:
    - ReadWriteOnce


```
## Create a final directory called "NameSpace" to store namespace
```bash
apiVersion: v1
kind: Namespace
metadata:
  name: edwin
```
## Once all the directories with there respected config yml files are created you can deploy them now
- Always deploy database first 

```bash
kubectl apply -f db_dep/ -n edwin
kubectl get all -n edwin
kubectl get pvc -n edwin 
kubectl get storageclass -n edwin
```
- To check logs and desciribe pod:

```bash
kubectl logs <pod name> -n edwin
kubectl describe <pod-name> -n edwin
```
- To describe pvc and storageclass

```bash
kubectl describe pvc <pvc name> -n edwin 
kubectl describe storageclass <storageclass name> -n edwin
```
- deploy twoge app  

```bash
kubectl apply -f twoge/ -n edwin
kubectl get all -n edwin
kubectl get pvc -n edwin 
kubectl get storageclass -n edwin
```

- to access the web app on minikube

```bash
kubectl service <service name> --url -n edwin 
# once url is populted hold CTRL and click on the url 
```