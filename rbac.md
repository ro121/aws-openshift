## OpenShift RBAC Implementation Guide

### Objective

This document outlines the standardized implementation of Role-Based Access Control (RBAC) within OpenShift environments across the organization. It serves as a centralized guide for defining, assigning, and managing user roles and permissions to ensure secure, auditable, and consistent access control. By aligning with this policy, teams can streamline access provisioning, minimize security risks, and comply with governance and audit requirements.

In OpenShift, Role-Based Access Control (RBAC) is a powerful framework used to control who can access what resources and perform which actions within a cluster or namespace. It works by assigning permissions (verbs) to roles, and binding those roles to users or groups.

| Concept                | Description                                                       |
| ---------------------- | ----------------------------------------------------------------- |
| **Role**               | A set of permissions (rules) scoped to a namespace                |
| **ClusterRole**        | Like Role, but cluster-scoped (can be used across all namespaces) |
| **RoleBinding**        | Grants a Role to a user/group within a specific namespace         |
| **ClusterRoleBinding** | Grants a ClusterRole to a user/group across the entire cluster    |


---

| Resource Type            | Explanation                             | Recommended Assignment         |
| ------------------------ | --------------------------------------- | ------------------------------ |
| `secrets`                | Sensitive credentials                   | DevOps Engineer, Security Team |
| `rolebindings`           | Security and access control             | Cluster Admin, Platform Admin  |
| `roles`                  | Security and access definitions         | Cluster Admin, Platform Admin  |
| `serviceaccounts`        | Service identity and access             | Cluster Admin, DevOps Engineer |
| `namespaces/projects`    | Project-level administration            | Cluster Admin                  |
| `configmaps`             | Non-sensitive config data               | Developer, DevOps Engineer     |
| `imagestreams`           | Container image handling                | Developer, DevOps Engineer     |
| `buildconfigs`           | Build pipeline management               | Developer, CI/CD Engineer      |
| `persistentvolumeclaims` | Storage requests (no data-level access) | Developer, Storage Admin       |
| `routes`                 | Application ingress management          | Developer, DevOps Engineer     |
| `services`               | Expose applications                     | Developer                      |
| `deployments`            | Application deployment management       | Developer                      |
| `pods`                   | Basic operational resource              | Developer                      |



### Roles and Access Levels

#### 1. Developer Access

**Scope:** Manage application-level resources.

**Resources:**

* Pods
* Deployments
* Services
* Routes
* ConfigMaps
* PersistentVolumeClaims
* ImageStreams
* BuildConfigs

**YAML Definition:** (`developer-role.yaml`)

```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: developer-role
  namespace: <namespace>
rules:
  - apiGroups: ["", "apps", "extensions"]
    resources: ["pods", "deployments", "services", "routes", "configmaps", "persistentvolumeclaims", "imagestreams", "buildconfigs"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

---

#### 2. View Access

**Scope:** Read-only access for auditing.

**Resources:**

* All namespace resources (read-only)

**YAML Definition:** (`view-role.yaml`)

```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: view-role
  namespace: <namespace>
rules:
  - apiGroups: ["", "apps", "extensions"]
    resources: ["pods", "deployments", "services", "routes", "configmaps", "persistentvolumeclaims", "imagestreams", "buildconfigs", "secrets", "roles", "rolebindings", "serviceaccounts"]
    verbs: ["get", "list", "watch"]
```

---

#### 3. Secret Access

**Scope:** Sensitive access for secret management.

**Resources:**

* Secrets

**YAML Definition:** (`secret-access-role.yaml`)

```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: secret-access-role
  namespace: <namespace>
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

---

#### 4. Admin Access

**Scope:** Full administrative control.

**Resources:**

* All namespace resources
* Roles and RoleBindings
* ServiceAccounts
* Namespaces/Projects

**Assign Built-in Roles:**

* **Namespace-level Admin:**

```bash
oc adm policy add-role-to-user admin <admin-username> -n <namespace>
```

* **Cluster-level Admin:**

```bash
oc adm policy add-cluster-role-to-user cluster-admin <cluster-admin-username>
```

---

### Role Assignment Strategy

| Role          | Assigned To                                     | Responsibility                         |
| ------------- | ----------------------------------------------- | -------------------------------------- |
| Developer     | Application Developers, DevOps Team             | Manage applications within namespaces  |
| View          | Auditors, QA Team, Observers                    | Read-only access for auditing purposes |
| Secret Access | DevOps Engineers, Security Team                 | Manage sensitive configuration data    |
| Admin         | Infrastructure, Platform/Cluster Administrators | Manage namespaces, policies, users     |

---

### Implementation Procedure

**Step 1: Define and Apply Roles**

```bash
oc apply -f <role-definition>.yaml
```

**Step 2: Assign Roles**

* **Developer Example:**

```bash
oc create rolebinding developer-binding --role=developer-role --user=<developer-username> -n <namespace>
```

* **View Example:**

```bash
oc create rolebinding view-binding --role=view-role --user=<view-user-username> -n <namespace>
```

* **Secret Access Example:**

```bash
oc create rolebinding secret-access-binding --role=secret-access-role --user=<secret-manager-username> -n <namespace>
```

* **Admin Example:**

```bash
oc adm policy add-role-to-user admin <admin-username> -n <namespace>
```

* **Cluster-wide Admin Example:**

```bash
oc adm policy add-cluster-role-to-user cluster-admin <cluster-admin-username>
```

---

### Validation Steps

**Verify roles and bindings:**

```bash
oc describe rolebindings -n <namespace>
oc get roles -n <namespace>
```

**Check permissions:**

```bash
oc auth can-i get secrets --as=<user> -n <namespace>
```

---

### Rules for Access Provisioning

1. All role provisioning must be documented and approved by respective team leads or administrators.
2. Prefer assigning roles to groups rather than individual users.
3. Conduct quarterly reviews of each role.
4. High-severity roles (Secret and Admin) require justification and dual approval.
5. Emergency provisioning must be documented within 24 hours and reviewed promptly.

---

### Auditing and Maintenance

Regular audits must be conducted:

```bash
oc get rolebindings,clusterrolebindings --all-namespaces
```

Permissions should be periodically reviewed and adjusted to maintain compliance and adherence to organizational policies.

---
