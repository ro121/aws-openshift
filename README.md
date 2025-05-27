# Connecting an On-Premises OpenShift Application to AWS-Hosted MongoDB (Atlas vs. DocumentDB)
Detailed plan on connecting an on-premises OpenShift cluster (KCS) to a managed MongoDB database in AWS,  two primary options – MongoDB Atlas (MongoDB Inc.’s cloud service) and Amazon DocumentDB (AWS’s MongoDB-compatible service)
# MongoDB Atlas
MongoDB Atlas is MongoDB Inc.’s fully-managed, cloud-native Database-as-a-Service (DBaaS). It provides automated provisioning, scaling, backups, patching, and security for MongoDB clusters, it supports major CLoud service providers.
On AWS, each Atlas node is an EC2 instance in a MongoDB-managed VPC, using EBS GP3 for storage and S3 for snapshots. for connectivity we use IP Access Lists for simple, public-endpoint connectivity. But for our current state, it is not suitable due to mongodb cloud service restriction. The better option on AWS is the native solution of DocumentDB.

# Amazon DocumentDB
Amazon DocumentDB (with MongoDB compatibility) is Amazon Web Services’ fully managed, highly available document database service designed to be compatible with MongoDB workloads. It handles the undifferentiated heavy lifting of database management. it better suits our use case and has inbuilt AWS options for disaster recovery.

Before starting, we need a roadmap on how to integrate AWS DocumentDB with KCS (openshift cluster), network configurations and deployment changes.

This document will provide a basic walkthrough for connecting an on-premises OpenShift cluster to an Amazon DocumentDB cluster in AWS (us-gov-west-1)

# Connecting OpenShift to Amazon DocumentDB

1. **Create an Amazon DocumentDB Cluster:** using terraform IaC for AWS we need to provision a DocumentDB cluster with suitable to sie based on the use case. and using subnet group spanning multiple Availability Zones for high availability.

2. **Network Integration between OpenShift and AWS**
   2.1 There are two primary options for this integration: a **Site-to-Site VPN** or **AWS Direct Connect**. but for our use case site to site VPN would be enough.

   2.2 As our data centers are on-prem (KCS), we need connected to the AWS VPC via a Site-to-Site VPN or AWS Direct Connect, ensuring that routing is in place. The OpenShift nodes’ network should be allowed to reach the DocumentDB subnet and port.
   
 **Site-to-Site VPN:** We need to set up an IPsec VPN tunnel between our on-premises network and the AWS VPC. For verification, after setting up VPN, we can test basic network connectivity. For example, from an on-premises host ( OpenShift nodes), ping an EC2 instance in the AWS VPC or use telnet/nc to test connectivity to the DocumentDB port (27017) on the AWS side. Ensure security rules are not blocking the traffic.

 2.3 **AWS VPC and Subnet Configuration**: 
 **VPC Setup:**

Using an AWS VPC in us-gov-west-1 to host DocumentDB.

DocumentDB should be placed in private subnets (no public IPs), spanning at least two availability zones for high availability.

Grouping these subnets in a DB Subnet Group during cluster creation.

**Network Routing:**

Update route tables for these private subnets to send on-premises traffic, This allows DocumentDB to communicate with on-prem resources securely.

**DNS Resolution:**

DocumentDB endpoints use AWS internal DNS (*.docdb.amazonaws.com). With AmazonProvidedDNS (VPC default), resolution works automatically over VPN.

Using the custom DNS of Boeing, set up a conditional forwarder for docdb.amazonaws.com to the VPC DNS resolver.
These settings provide secure, private, and highly available DocumentDB access from both AWS and on-prem environments, with reliable connectivity and name resolution.

2.4 **AWS Security Group Configuration**
Create a new Security Group in the VPC where your DocumentDB cluster lives.

Inbound rules:
Type: Custom TCP Rule
Port: 27017 (the MongoDB default)
Source: our on-prem network CIDR or our VPN/Direct Connect tunnel range.
Attach this Security Group to the DocumentDB cluster’s primary and replica instances.

2. On-Premises Firewall Rules
Outbound rule on your datacenter (or office) firewall:
Destination: DocumentDB’s subnet range (or specific cluster endpoint IPs) in your AWS VPC.
Port: 27017/TCP
Source: OpenShift node subnets (or the application subnet CIDR).
As we are using a VPN, set the AWS-side IP range as “internal”— the firewall must allow that private-to-private traffic on 27017/TCP.

3. No Public Exposure
DocumentDB endpoints are private-only (no Internet-facing endpoints).
All client traffic must traverse your private network (VPN, Direct Connect, or a bastion host/proxy in AWS).

# DocumentDB Endpoints and Connectivity4
1. **Cluster Endpoints & Connection Strings:** Amazon DocumentDB provides a Cluster Endpoint (writer endpoint) for the cluster. Always routes to the current primary.
   eg: mydocdbcluster.cluster-ABCDEFGHI.us-west-1.docdb.amazonaws.com:27017
2. **Instance Endpoints:**
Each node also has its own DNS name (e.g., mydocdbcluster-instance-1.XXXXXXXX.us-west-1.docdb.amazonaws.com).
3. **DNS and Access:**
The endpoints above are DNS names resolving to internal IPs in AWS. Since our OpenShift cluster is now network-connected, it should resolve and reach these.
Ensuring our DNS resolution is working. If resolution fails, double-check that our on-prem DNS setup forwards queries for docdb.amazonaws.com appropriately. We can use AWS VPC DNS by default over the VPN.

# OpenShift Configuration
Here’s a step-by-step to configure OpenShift apps into Amazon DocumentDB via Secrets, ConfigMaps and Deployment tweaks:

---

## 1. Create a Secret for your credentials

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: docdb-credentials
type: Opaque
stringData:
  username: yourDbUser
  password: yourStrongPassword
```

```bash
oc apply -f docdb-credentials-secret.yaml
```

---

## 2. Import the TLS CA bundle

Amazon DocumentDB speaks TLS with Amazon’s CA. Download the RDS CA bundle (e.g. `rds-combined-ca-bundle.pem`) and store it in a Secret:

```bash
# locally fetch the CA bundle
curl https://truststore.pki.rds.amazonaws.com/2024/rds-ca-2019-root.pem \
  -o rds-combined-ca-bundle.pem

# create the secret
oc create secret generic docdb-tls-ca \
  --from-file=ca.pem=./rds-combined-ca-bundle.pem
```

---

## 3. Store connection string in a ConfigMap

Put cluster endpoint and options in a ConfigMap so it’s easy to rotate or reuse:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: docdb-config
data:
  MONGODB_URI: >-
    mongodb://$(DB_USER):$(DB_PASS)@
    mydocdbcluster.cluster-ABCDEFGHI.us-west-1.docdb.amazonaws.com:27017/
    myDatabase?ssl=true&replicaSet=rs0&readPreference=secondaryPreferred
```

```bash
oc apply -f docdb-configmap.yaml
```

---

## 4. Update Deployment to consume them

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: your-registry/my-app:latest
        env:
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: docdb-credentials
              key: username
        - name: DB_PASS
          valueFrom:
            secretKeyRef:
              name: docdb-credentials
              key: password
        - name: MONGODB_URI
          valueFrom:
            configMapKeyRef:
              name: docdb-config
              key: MONGODB_URI
        volumeMounts:
        - name: tls-ca
          mountPath: /etc/ssl/certs/docdb-ca.pem
          subPath: ca.pem
          readOnly: true
      volumes:
      - name: tls-ca
        secret:
          secretName: docdb-tls-ca
```

1. **Environment variables** inject `DB_USER`, `DB_PASS` and the full `MONGODB_URI`.
2. **Volume mount** places the CA at `/etc/ssl/certs/docdb-ca.pem`.
3. Make sure the app’s MongoDB client is configured to trust that file (e.g., `sslCAFile=/etc/ssl/certs/docdb-ca.pem`).

---


### Final sanity checks

* `oc get secret/docdb-credentials` and `oc get secret/docdb-tls-ca` exist.
* `oc get configmap/docdb-config` shows your URI.
* Pods mount the CA:

  ```bash
  oc rsh <pod-name> ls /etc/ssl/certs | grep docdb-ca.pem
  ```
* App logs show successful connection (no SSL or auth errors).

Once everything is in place, the OpenShift pods will securely authenticate and TLS-encrypt traffic to the Amazon DocumentDB cluster without any credentials or certificates baked into the image.

# Application Connection
To connect the application on OpenShift to Amazon DocumentDB, construct the MongoDB URI using the standard format and include required parameters: tls=true for encryption, replicaSet=rs0 to identify the cluster, and retryWrites=false since DocumentDB does not support retryable writes. Optionally, use readPreference=secondaryPreferred to distribute reads across replicas. Store database credentials in a Kubernetes Secret and the connection string or its components in a ConfigMap. Mount the Amazon RDS CA certificate as a volume from a Secret and reference it in our application's TLS configuration. Ensure the OpenShift pods can resolve the DocumentDB cluster's DNS and establish a TLS connection using the mounted certificate.

# Verification and Testing
**Smoke Tests: Connectivity and Queries**:
* **Check application logs**:
  Run `oc logs deployment/myapp` to view startup logs and connection attempts.

* **Look for common errors**:
  * **TLS/SSL error** → CA bundle missing or not mounted correctly.
  * **Authentication error** → Incorrect username/password in Secret.
  * **Network timeout** → Misconfigured Security Group or firewall/VPN issue.

* **Confirm DNS resolution**:
  Use `host <docdb-endpoint>` inside the pod to verify name resolution.

* **Test TLS connection**:
  Run `openssl s_client -connect <host>:27017 -CAfile <mounted-ca-path>` from inside the pod.

* **Run simple query**:
  Use a CLI or the app itself to insert/read a document from the target database.

* **Remove temporary rules**:
  If ICMP/ping was enabled for testing, remove those Security Group rules after verification.

# Backup and Data Recovery – Key Points

#### **AWS Automated Backups**

* DocumentDB supports **automated backups** with configurable retention (1–35 days).
* **Check and adjust** the "Backup retention period" in the AWS Console to match your RPO (e.g., 7 or 14 days).
* Ensure a **daily backup window** is defined for consistent snapshots.
* **Point-in-time restore** creates a new cluster with a new endpoint; existing cluster is unaffected.

#### **On-Prem / Manual Backups**

* Use `mongodump` for logical backups; run as a **cronjob pod** in OpenShift or manually.
* Include `--sslCAFile` to ensure TLS connection to DocumentDB.
* Store dumps safely—on-prem backup server or S3 if allowed.
* Be aware that `mongodump` is **resource-intensive** on large datasets; prefer AWS snapshots where possible.

#### **Restore Drills**

* Periodically test **AWS restore** by spinning up a new cluster from backup and validating with a test app.
* Validate `mongodump` backups using `mongorestore` to a test database (local or cloud).

#### **Disaster Recovery Considerations**

* DocumentDB **does not support cross-region or on-prem replication**.
* DR to other regions or on-prem must rely on manual backup/export or external tools (e.g., CDC-based).

# sample CronJob YAML (OpenShift/Kubernetes)
---

### `mongodump` CronJob YAML (OpenShift/Kubernetes)

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: docdb-backup-job
spec:
  schedule: "0 2 * * *"  # Runs daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: mongodump
            image: mongo:4.4
            command:
            - /bin/sh
            - -c
            - |
              mongodump \
                --uri="mongodb://$(DB_USER):$(DB_PASS)@mydocdbcluster.cluster-XYZ.us-west-1.docdb.amazonaws.com:27017/mydatabase?tls=true&retryWrites=false" \
                --sslCAFile=/etc/ssl/certs/rds-combined-ca-bundle.pem \
                --out=/backup/dump-$(date +%F)
            env:
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: docdb-credentials
                  key: username
            - name: DB_PASS
              valueFrom:
                secretKeyRef:
                  name: docdb-credentials
                  key: password
            volumeMounts:
            - name: cert-volume
              mountPath: /etc/ssl/certs/rds-combined-ca-bundle.pem
              subPath: ca.pem
            - name: backup-volume
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: cert-volume
            secret:
              secretName: docdb-tls-ca
          - name: backup-volume
            persistentVolumeClaim:
              claimName: docdb-backup-pvc  # Your PVC should be pre-created
```

---

### AWS CLI – Restore DocumentDB Cluster from Backup

```bash
aws docdb restore-db-cluster-to-point-in-time \
  --db-cluster-identifier mydocdbcluster-restore-2025 \
  --source-db-cluster-identifier mydocdbcluster \
  --restore-to-time 2025-05-26T01:00:00Z \
  --engine docdb \
  --vpc-security-group-ids sg-xxxxxxxx \
  --subnet-group-name my-subnet-group
```

* `--restore-to-time`: ISO timestamp within your retention period
* Creates a **new cluster** with its own endpoint
* Attach instances separately using `aws docdb create-db-instance`

---










