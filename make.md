# Unified Data Access Layer (UDAL) – Integration and Policy Configuration Guide

## 1. Purpose

This document provides a detailed guide for integrating the Unified Data Access Layer (UDAL) with enterprise applications. It explains how UDAL controls access to users, how to create policies, and how to configure geographic access control for US and NON-US data segregation.

## 2. Overview of UDAL

The Unified Data Access Layer (UDAL) is a centralized Attribute-Based Access Control (ABAC) framework that enforces fine-grained access to datasets and APIs based on:

- **Who** is requesting access (user identity and role)
- **What** they are requesting (resource or dataset)
- **Under what conditions** (attributes, such as location or classification)

### Key Capabilities:
- Attribute-based access control (ABAC)
- Policy-driven enforcement
- Geographic attribute checks (US/NON-US)
- JWT-based identity and claims validation
- Centralized audit logging

## 3. Role of JWT in UDAL

JSON Web Token (JWT) is used to securely pass user identity, roles, and attributes (such as user_location) from the authentication provider (IdP) to both the application and UDAL.

### JWT contains:

**Header** – Algorithm & token type (alg, typ)

**Payload** – Claims such as:
- `sub` (User ID)
- `role` (e.g., Analyst, Manager)
- `user_location` (US or NON-US)
- `iss` (Issuer, IdP)
- `aud` (Audience, the application/UDAL)
- `exp` (Expiry)

**Signature** – Verifies integrity using IdP's private key

## 4. UDAL Access Control Workflow with JWT

### 1. User Authentication via IDP
- The user logs in using SSO/OAuth2/LDAP
- The Identity Provider (IdP) authenticates the user and issues a JWT containing identity and attributes

### 2. Application Receives JWT
- The application stores the JWT (usually in memory/session)
- On every request requiring UDAL authorization, it attaches:
```
Authorization: Bearer <JWT>
```

### 3. Application Sends Access Request to UDAL
The request includes:
- The JWT (as Authorization header)
- Resource being accessed
- Action requested (READ, WRITE, etc.)

### 4. UDAL Verifies JWT
- Signature verification using IdP's public key (JWK)
- Claims validation: exp, nbf, iss, aud
- Extracts role and user_location from claims

### 5. Policy Evaluation
- UDAL checks extracted attributes against configured policies
- For geographic compliance, it compares:
  - `user_location` from JWT
  - `data_location` from resource metadata

### 6. Access Decision
- If policies allow, returns ALLOW
- If denied, returns DENY with reason

### 7. Application Enforcement & Logging
- Application enforces UDAL's decision
- Both UDAL and application log the transaction

## 5. Policy Structure

| Field | Description |
|-------|-------------|
| Policy ID | Unique identifier |
| Description | Purpose of the policy |
| Subjects | Roles/groups to which policy applies |
| Attributes | Attribute conditions (from JWT & resource metadata) |
| Actions | Allowed actions (READ, WRITE, DELETE) |
| Effect | ALLOW or DENY |

## 6. US/NON-US Policy Configuration Examples

### 6.1 US User → US Data

```json
{
  "policyId": "US_TO_US_ACCESS",
  "description": "Allow US users to access US data",
  "subjects": ["role:Analyst", "role:Manager"],
  "attributes": {
    "user_location": "US",
    "data_location": "US"
  },
  "actions": ["READ", "WRITE"],
  "effect": "ALLOW"
}
```

- **JWT check**: user_location = US
- **Dataset check**: data_location = US

### 6.2 NON-US User → NON-US Data

```json
{
  "policyId": "NONUS_TO_NONUS_ACCESS",
  "description": "Allow NON-US users to access NON-US data",
  "subjects": ["role:Analyst", "role:Manager"],
  "attributes": {
    "user_location": "NON-US",
    "data_location": "NON-US"
  },
  "actions": ["READ", "WRITE"],
  "effect": "ALLOW"
}
```

- **JWT check**: user_location = NON-US
- **Dataset check**: data_location = NON-US

### 6.3 Deny Cross-Border Access

```json
{
  "policyId": "DENY_CROSS_BORDER",
  "description": "Deny access between US and NON-US users/data",
  "attributes": {
    "user_location": "US",
    "data_location": "NON-US"
  },
  "actions": ["READ", "WRITE"],
  "effect": "DENY"
}
```

- Blocks US → NON-US and vice versa
- Enforced by matching JWT claim (user_location) with dataset metadata

## 7. Integration Steps

### Configure IdP to Include Attributes in JWT
- Add role and user_location claims
- Set correct aud for application and UDAL

### Configure Application
- Accept JWT from IdP
- Attach JWT to requests made to UDAL

### Configure UDAL
- Import IdP's public JWK set for signature verification
- Define attribute mappings from JWT claims to UDAL attributes

### Create & Deploy Policies
- Define JSON/YAML policies
- Deploy via UDAL Admin Console or API

### Test and Validate
- Test multiple user/location combinations
- Review logs for expected policy enforcement

## 8. US and NON-US Account Permission Configuration

When accounts are classified as US or NON-US, UDAL enforces permissions by evaluating:
- The `user_location` claim from the JWT issued by the IdP
- The `data_location` attribute associated with the dataset or API resource

### 8.1 US Account Permissions

- **ALLOW**: READ and WRITE on datasets where data_location = US
- **DENY**: Access to datasets where data_location = NON-US, unless an exception policy explicitly grants access for approved cross-border operations
- May view and modify sensitive US-classified datasets if:
  - The JWT role claim matches approved roles (e.g., "role": "SecurityClearedAnalyst")
  - The clearance_level attribute in JWT meets the policy threshold
- Administrative actions permitted only for users in the UDAL_Admin group within the US region

#### Example – US Account Policy

```json
{
  "policyId": "US_USER_US_DATA",
  "description": "Allow US accounts to access US datasets",
  "subjects": ["group:US_Analysts", "group:US_Engineers"],
  "attributes": {
    "user_location": "US",
    "data_location": "US"
  },
  "actions": ["READ", "WRITE"],
  "effect": "ALLOW"
}
```

### 8.2 NON-US Account Permissions

- **ALLOW**: READ and WRITE on datasets where data_location = NON-US
- **DENY**: Access to datasets where data_location = US, unless approved via exception
- May view and modify sensitive NON-US datasets if:
  - The JWT role claim matches permitted roles (e.g., "role": "RegionalAnalyst")
  - The clearance_level attribute matches required levels
- Administrative actions limited to NON-US datasets and roles within NON-US regions

#### Example – NON-US Account Policy

```json
{
  "policyId": "NONUS_USER_NONUS_DATA",
  "description": "Allow NON-US accounts to access NON-US datasets",
  "subjects": ["group:EU_Analysts", "group:APAC_Engineers"],
  "attributes": {
    "user_location": "NON-US",
    "data_location": "NON-US"
  },
  "actions": ["READ", "WRITE"],
  "effect": "ALLOW"
}
```

## 9. UDAL Access Control and Roles

Access to UDAL's policy engine and administrative features should be limited to authorized personnel.

### 9.1 Roles with UDAL Access

**UDAL Administrators**
- Full control to create, update, delete policies, manage attributes, and review access logs
- Example: "group": "UDAL_Admins" in JWT

**Security Team Leads**
- Can review and approve high-impact policy changes, perform compliance audits, and investigate access logs

**Platform Team Leads**
- Manage integration between applications and UDAL, deploy new policies, and coordinate testing

### 9.2 Access Provisioning Process

1. **Request Submission**: User submits an access request via the corporate access management system, specifying role and justification
2. **Dual Approval Required**: Security Lead and Platform Lead must approve
3. **Time-Bound Access**: Granted access expires after a predefined period (e.g., 30 days) unless renewed
4. **Logging & Audit**:
   - All provisioning actions logged in change management
   - Quarterly audits to confirm alignment with compliance policies

#### Example – Admin Role Assignment Policy

```json
{
  "policyId": "UDAL_ADMIN_ACCESS",
  "description": "Allow UDAL Admins to manage policies and configurations",
  "subjects": ["group:UDAL_Admins"],
  "actions": ["CREATE_POLICY", "UPDATE_POLICY", "DELETE_POLICY", "VIEW_LOGS"],
  "effect": "ALLOW"
}
```

## 10. Managing Access to Multiple APIs in UDAL

When an application or user requires access to multiple APIs, UDAL should manage this through resource-based policies and attribute grouping rather than creating separate one-off rules for each API.

### 10.1 Recommended Approach

#### Tag Each API as a Resource
- Assign a resource_id (e.g., api:customer_data, api:order_management) in UDAL
- Tag with relevant attributes (e.g., data_location, classification, service_owner)

#### Group APIs by Function or Classification
- Example groups: Customer_APIs, Finance_APIs, Public_APIs
- Helps apply policies to a category instead of managing individual APIs

#### Use Attribute-Based Rules Instead of Explicit API Lists
- Avoid hardcoding API IDs in policies
- Example: Grant access to all APIs where classification = public for the given role

#### Create Role-Based Policies for API Groups

```json
{
  "policyId": "ACCESS_CUSTOMER_APIS",
  "description": "Allow US Analysts to access all Customer APIs in US region",
  "subjects": ["group:US_Analysts"],
  "attributes": {
    "user_location": "US",
    "data_location": "US",
    "service_group": "Customer_APIs"
  },
  "actions": ["READ", "WRITE"],
  "effect": "ALLOW"
}
```

#### Implement API Gateway Integration
- Ensure your API gateway (e.g., Kong, Apigee, AWS API Gateway) enforces UDAL's decision before routing requests

## 11. Onboarding a New Project with UDAL

When a new project is onboarded to UDAL, the following steps should be followed to ensure proper policy coverage, security, and compliance.

### 11.1 Onboarding Steps

#### Project Registration
- Record the project name, owner, and stakeholders in the UDAL registry
- Assign a project_id and service_owner attribute

#### Resource Discovery and Tagging
- Identify all datasets, APIs, and resources the project will expose or consume
- Tag them with:
  - project_id
  - data_location
  - classification (public, internal, restricted, sensitive)

#### User and Role Mapping
- Define which user groups (from IdP) will interact with the project
- Assign attributes like role, clearance_level, and user_location

#### Policy Definition
- Create policies that cover all allowed actions for the project
- Include geographic restrictions if applicable (US/NON-US)

```json
{
  "policyId": "PROJECT_X_API_ACCESS",
  "description": "Allow APAC Engineers to access Project X development APIs",
  "subjects": ["group:APAC_Engineers"],
  "attributes": {
    "project_id": "project_x",
    "environment": "dev"
  },
  "actions": ["READ", "WRITE"],
  "effect": "ALLOW"
}
```

#### Integration with Application Services
- Update applications or API gateways to query UDAL for every request
- Ensure JWT includes project_id or other project-specific claims

#### Testing and Validation
- Perform access tests with different user profiles
- Validate that only permitted actions and resources are accessible

#### Audit and Compliance Review
- Schedule a post-onboarding review to confirm logs, policies, and access align with corporate governance

## 12. Operational & Lifecycle Management

This section ensures UDAL remains effective, compliant, and up to date throughout its operational life.

### 12.1 Policy Lifecycle Management

Policies must follow a controlled creation, review, and retirement process to ensure they remain relevant and secure.

#### Best Practices:

**Policy Versioning**
- Store all policy definitions in a Git repository with semantic version tags (e.g., v1.0.0)
- Include change history, author, and approval details in commit messages

**Approval Workflow**
- New or updated policies require dual approval:
  - One approver from the Security Team
  - One approver from the Platform Team
- Emergency changes must be retroactively reviewed within 24 hours

**Review Frequency**
- Conduct quarterly policy reviews to:
  - Remove unused or outdated rules
  - Update attribute conditions for new compliance regulations
  - Validate policy alignment with business needs

**Policy Retirement**
- Mark policies as deprecated before removal
- Remove only after confirming no dependencies remain

### 12.2 Audit & Compliance Monitoring

To ensure transparency and compliance, UDAL must log all access decisions and make them available for audit.

#### Audit Data Fields:
- `timestamp` – When the request was evaluated
- `user_id` – Extracted from JWT claim sub
- `role` – From JWT claim role
- `user_location` – From JWT claim
- `resource_id` – Identifier of the requested resource
- `action` – Requested operation (READ, WRITE, DELETE)
- `decision` – ALLOW/DENY
- `policy_id` – Policy that made the decision
- `reason` – Optional descriptive text

#### Compliance Practices:
- Store logs in a secure, immutable storage (e.g., WORM-enabled S3 or SIEM like Splunk/ELK)
- Schedule monthly compliance exports for internal audits
- Trigger alert notifications for repeated access denials from the same user or IP

### 12.3 Incident Response for Access Violations

UDAL must support rapid response to suspicious activity.

#### Steps:
1. **Detection** – Security tooling flags repeated access denials or unusual resource requests
2. **Immediate Containment** – Suspend user account in IdP or disable role in UDAL
3. **Investigation** – Review UDAL logs and application request traces
4. **Resolution** – Apply policy corrections, retrain users, or escalate to legal/compliance teams
5. **Post-Mortem Review** – Document the incident, root cause, and preventive measures

## 13. Technical Architecture & Deployment

### 13.1 High-Level Architecture

```
[User] → [Application/API Gateway] → [UDAL] → [Data Source]
                     ↑                 ↓
                  JWT Auth          Policy Decision
```

#### Flow Explanation:
1. User authenticates with IdP → Receives JWT with attributes (role, user_location, etc.)
2. Application/API Gateway forwards the JWT + resource/action request to UDAL
3. UDAL verifies JWT signature, evaluates policies, returns ALLOW/DENY
4. Application enforces decision before granting access to the data source

### 13.2 Deployment Model
- **Cloud**: Deploy as containerized microservices (Kubernetes/OpenShift) with auto-scaling
- **Hybrid**: Use private link or VPN to connect cloud UDAL with on-prem datasets

### 13.3 Performance & Latency
- **Decision Time Target**: < 50ms average, < 200ms at peak
- **Caching**: Implement short-lived decision cache (e.g., 60 seconds) for repeat requests
- **Failover Mode**:
  - Fail-Closed for sensitive data (deny if UDAL is unavailable)
  - Fail-Open for public/unclassified resources (allow temporarily)

## 14. Advanced Use Cases & Examples

### 14.1 Nested Attribute Rules

**Scenario**: US users can only access US data during US business hours.

```json
{
  "policyId": "US_WORK_HOURS_ACCESS",
  "attributes": {
    "user_location": "US",
    "data_location": "US",
    "access_time": "09:00-17:00 EST"
  },
  "actions": ["READ", "WRITE"],
  "effect": "ALLOW"
}
```

### 14.2 Multi-Attribute Enforcement

**Scenario**: Only Project-X Managers with clearance level 5 can delete records.

```json
{
  "policyId": "PROJECTX_MANAGER_DELETE",
  "subjects": ["role:Manager"],
  "attributes": {
    "project_id": "project_x",
    "clearance_level": 5
  },
  "actions": ["DELETE"],
  "effect": "ALLOW"
}
```

### 14.3 Temporary/Escalated Access

**Scenario**: Developer gets write access for 48 hours to fix an urgent bug.

```json
{
  "policyId": "TEMP_DEV_WRITE",
  "subjects": ["user:dev123"],
  "attributes": {
    "project_id": "project_y",
    "valid_until": "2025-08-15T12:00:00Z"
  },
  "actions": ["WRITE"],
  "effect": "ALLOW"
}
```

### 14.4 Cross-Project Data Sharing

**Scenario**: Allow Project-A Analysts to read Project-B's public dataset.

```json
{
  "policyId": "CROSS_PROJECT_PUBLIC_ACCESS",
  "subjects": ["group:project_a_analysts"],
  "attributes": {
    "data_location": "US",
    "classification": "public",
    "project_id": "project_b"
  },
  "actions": ["READ"],
  "effect": "ALLOW"
}
```

## Conclusion

This guide provides a complete framework for integrating the Unified Data Access Layer (UDAL) into enterprise applications to ensure secure, attribute-driven access control. By leveraging JWT-based authentication, policy-driven decision-making, and attributes such as US and NON-US, organizations can enforce precise access rules that align with compliance and business needs.

The outlined policy structures, operational guidelines, architecture details, and advanced use cases equip engineering, security, and operations teams to adopt UDAL effectively. Following these steps helps maintain a consistent, auditable, and scalable access control model across all integrated applications and APIs.
