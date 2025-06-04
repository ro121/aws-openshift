Here’s a detailed document for deploying an application using AWS credentials (AWS\_ACCESS\_KEY\_ID and AWS\_SECRET\_ACCESS\_KEY) securely in OpenShift. This document will guide developers step by step.

---

# Deploying an Application with AWS Credentials in OpenShift

## **Purpose**

To configure and deploy an application on OpenShift using AWS credentials (ACCESS\_KEY\_ID and SECRET\_ACCESS\_KEY) securely for integration with AWS services like Redshift.

---

## **Prerequisites**

1. **Access to OpenShift Console**: Ensure you have the necessary access to the OpenShift project where the application will be deployed.
2. **AWS Credentials**: Have the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` available.
3. **Application Repository**: Access to the application repository (second image) containing the deployment files.
4. **Redshift Configuration**: Confirm AWS Redshift endpoint, database name, and user details are available for use.

---

## **Steps**

### **1. Create OpenShift Secrets**

Secrets are used to securely store AWS credentials in OpenShift.

1. **Login to OpenShift Console**.
2. Navigate to the **Secrets** section under **Workloads** in the project.
3. Click **Create Secret** and choose **Key/Value** type.
4. Add the following key-value pairs:

   * **Key:** `AWS_ACCESS_KEY_ID` | **Value:** `<Your AWS_ACCESS_KEY_ID>`
   * **Key:** `AWS_SECRET_ACCESS_KEY` | **Value:** `<Your AWS_SECRET_ACCESS_KEY>`
5. Save the secret and note its name (e.g., `aws-credentials-secret`).

**CLI Example:**

```bash
oc create secret generic aws-credentials-secret \
  --from-literal=AWS_ACCESS_KEY_ID=<Your AWS_ACCESS_KEY_ID> \
  --from-literal=AWS_SECRET_ACCESS_KEY=<Your AWS_SECRET_ACCESS_KEY> \
  -n <namespace>
```

---

### **2. Update Deployment Configuration**

Modify the deployment YAML file to use the secret in the environment variables.

1. Locate the **DeploymentConfig** or **Deployment** YAML file in the application repository.

2. Add the following `envFrom` section under the `containers` spec to reference the secret:

   ```yaml
   spec:
     containers:
       - name: <container-name>
         image: <application-image>
         envFrom:
           - secretRef:
               name: aws-credentials-secret
   ```

3. Save the changes and apply the updated deployment.

**CLI Example:**

```bash
oc apply -f deployment.yaml -n <namespace>
```

---

### **3. Test the Deployment**

1. **Redeploy the Application**:

   * Trigger a redeployment of the application if it is already running.

   ```bash
   oc rollout restart deployment/<deployment-name> -n <namespace>
   ```

2. **Validate Environment Variables**:

   * Check if the AWS credentials are available in the container.

   ```bash
   oc exec -it <pod-name> -- env | grep AWS
   ```

   Ensure `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are correctly set.

---

### **4. Integrate with Redshift**

1. **Update Application Code**:

   * Ensure the application code uses environment variables for Redshift integration:

     ```python
     import os
     import psycopg2

     conn = psycopg2.connect(
         dbname='your_db',
         user=os.getenv('AWS_ACCESS_KEY_ID'),
         password=os.getenv('AWS_SECRET_ACCESS_KEY'),
         host='redshift-cluster-endpoint',
         port='5439'
     )
     ```

2. **Deploy Updated Application**:

   * Commit the changes to the repository and trigger a deployment pipeline.

---

## **Best Practices**

1. **Secure Secrets**:

   * Never hardcode AWS credentials in code.
   * Use OpenShift secrets or a secret management tool like HashiCorp Vault.

2. **Access Control**:

   * Limit access to the project and secret to authorized users only.

3. **Monitoring**:

   * Use tools like OpenShift Monitoring and AWS CloudWatch to monitor the deployment and Redshift connections.

---

This document should guide developers to set up the required deployment configuration. If further clarification is needed, let me know!
