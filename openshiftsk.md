**OpenShift Secrets Management for AWS Access Tokens**

**1. Purpose & Scope**
This guide provides step-by-step instructions for creating, storing, and controlling access to AWS access-key secrets in an OpenShift (OCP) cluster. It covers non-human service accounts that require programmatic access to AWS services.

---

**2. Secret Types & Management**
OpenShift supports several built-in secret types. Choose based on your workload requirements:

| Type                      | Description & Use Case                                       | Management & Rotation                                                      |
| ------------------------- | ------------------------------------------------------------ | -------------------------------------------------------------------------- |
| **Opaque**                | Generic key–value pairs (e.g., AWS tokens, config data).     | `oc create secret generic`; rotate via `oc set data` or CI/CD; static.     |
| **ssh-auth**              | SSH private key for Git or VM access.                        | `oc create secret ssh-auth`; rotate in source control or SSH config.       |
| **basic-auth**            | Username/password for HTTP basic authentication.             | `oc create secret basic-auth`; update via `oc set data` when creds change. |
| **service-account-token** | Token for a ServiceAccount to authenticate to API server.    | Auto-managed by OpenShift; rotate by recreating SA or token secret.        |
| **dockerconfigjson**      | JSON-formatted registry credentials for container runtime.   | Like docker-registry; update via CI/CD when creds rotate.                  |
| **external-secret**       | Secrets fetched from external stores (e.g., Vault).          | Managed by ExternalSecrets operator; rotates based on external config.     |

> **Management Best Practices**
>
> * Define rotation policies (e.g., Opaque tokens every 30 days, TLS certs every 90 days).
> * Use dynamic or short-lived credentials (e.g., IRSA, Vault).
> * Store secret definitions in GitOps repos, but avoid embedding values.
> * Regularly audit and remove unused secrets and bindings.
> * Automate rotation & rollout via CI/CD pipelines.

**3. Creating AWS Credentials Secret**

1. **Generate AWS Keys**: In AWS IAM console, create an Access Key ID + Secret Access Key under a dedicated service user.
2. **Create Secret in OpenShift**:

   ```bash
   oc create secret generic aws-credentials \
     --from-literal=aws_access_key_id=<ACCESS_KEY_ID> \
     --from-literal=aws_secret_access_key=<SECRET_ACCESS_KEY> \
     -n <namespace>
   ```
3. **Verify**:

   ```bash
   oc get secret aws-credentials -n <namespace>
   ```

---

**4. Access Control (RBAC)**
Restricting secret access using Roles and RoleBindings:

* **Role Definition** (`aws-secret-reader.yaml`):

  ```yaml
  kind: Role
  apiVersion: rbac.authorization.k8s.io/v1
  metadata:
    name: aws-credentials-reader
    namespace: <namespace>
  rules:
    - apiGroups: [""]
      resources: ["secrets"]
      resourceNames: ["aws-credentials"]
      verbs: ["get"]
  ```

* **Apply Role & Binding**:

  ```bash
  oc apply -f aws-secret-reader.yaml
  oc create rolebinding aws-creds-reader-binding \
    --role=aws-credentials-reader \
    --user=<username-or-sa> \
    -n <namespace>
  ```

---

**5. Injecting Secrets into Workloads**

* **Environment Variables**:

  ```yaml
  env:
    - name: AWS_ACCESS_KEY_ID
      valueFrom:
        secretKeyRef:
          name: aws-credentials
          key: aws_access_key_id
    - name: AWS_SECRET_ACCESS_KEY
      valueFrom:
        secretKeyRef:
          name: aws-credentials
          key: aws_secret_access_key
  ```

* **Volume Mount**:

  ```yaml
  volumes:
    - name: aws-creds-vol
      secret:
        secretName: aws-credentials
  volumeMounts:
    - name: aws-creds-vol
      mountPath: /etc/aws
      readOnly: true
  ```

* **ServiceAccount Annotation** (auto-inject):

  ```bash
  oc annotate serviceaccount <sa-name> secrets.openshift.io/inject="aws-credentials"
  ```

---

**6. Rotation & Updates**

1. **Rotate in AWS**: Delete old keys in IAM, create new ones.
2. **Update OpenShift**:

   ```bash
   oc set data secret/aws-credentials \
     --from-literal=aws_access_key_id=<NEW_ID> \
     --from-literal=aws_secret_access_key=<NEW_SECRET> \
     -n <namespace>
   ```
3. **Restart Workloads**:

   ```bash
   oc rollout restart deployment/<deploy-name> -n <namespace>
   ```

---

**7. Auditing & Logging**

* Enable OpenShift audit logs for `secrets` API calls.
* Filter events where `resource: "secrets"` and `name: "aws-credentials"`.
* Schedule reviews for `get`, `update`, `patch`, and `delete` operations.

---

