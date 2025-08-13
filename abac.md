# UDAL Access Control Policies

---

## 1. Overview

The User Data Access Layer (UDAL) implements a multi-layered security architecture that provides comprehensive access control for applications within our ecosystem. This document outlines the access policies, enforcement mechanisms, and compliance requirements.

### 1.1 Security Architecture

UDAL employs a defense-in-depth approach with the following layers:
- **Authentication Layer**: JWT token validation
- **Authorization Layer**: Role-based and attribute-based access control
- **Compliance Layer**: Geographic and regulatory restrictions
- **Application Layer**: Module-specific access controls

---

## 2. Authentication Policies

### 2.1 JWT Token Requirements

**Policy ID**: AUTH-001  
**Scope**: Global

All API requests to protected resources must include a valid JWT token in the Authorization Bearer header.

**Requirements**:
- Token must be present in `Authorization: Bearer <token>` header
- Token must be cryptographically valid (RS512 algorithm)
- Token must not be expired
- Token must be signed with the authorized UDAL public key

**Enforcement**: Automatic rejection with `401 Unauthorized` if token is missing or invalid.

### 2.2 Token Validation Standards

**Policy ID**: AUTH-002  
**Scope**: Global

**Technical Requirements**:
- **Algorithm**: RS512 (RSA Signature with SHA-512)
- **Key Type**: Asymmetric public key validation
- **Expiration**: Strict enforcement - expired tokens are rejected
- **Key Rotation**: Supports dynamic public key updates

---

## 3. Authorization Policies

### 3.1 Role-Based Access Control (RBAC)

**Policy ID**: AUTHZ-001  
**Scope**: Global

Access to resources is controlled through role assignments at the application level.

**Policy Rules**:
- Users must possess ALL required roles for a specific application/module
- Role assignments are application-specific (no cross-application privilege inheritance)
- Partial role matches are not permitted
- Role validation occurs on every request

**Role Structure**:
```
user.roles = {
  "application1": ["role1", "role2", "role3"],
  "application2": ["role4", "role5"]
}
```

**Example Enforcement**:
- Required roles for App1: `["admin", "read"]`
- User roles for App1: `["admin", "read", "write"]` ✅ **ALLOWED**
- User roles for App1: `["admin", "write"]` ❌ **DENIED** (missing "read")

### 3.2 Attribute-Based Access Control (ABAC)

**Policy ID**: AUTHZ-002  
**Scope**: Global

Dynamic access control using JSON Logic expressions for complex business rules.

**Policy Rules**:
- JSON Logic expressions evaluate against complete user profile
- Rules can incorporate multiple user attributes simultaneously
- Failed evaluations result in detailed error messages
- Rules are configurable without code deployment

**User Attributes Available**:
- `sub`: User identifier
- `businessUnit`: Organizational unit
- `manager`: Management hierarchy
- `roles`: Role assignments per application
- `imageUrl`: User profile information
- `accountingDepartment`: Financial department
- `friendlyName`: Display name
- `company`: Company affiliation
- `type`: User classification
- `usPerson`: Citizenship/person status
- `email`: Contact information
- `boeingPerson`: Company-specific classification

### 3.3 User Requirements Validation

**Policy ID**: AUTHZ-003  
**Scope**: Application-Specific

Custom validation logic applied at the endpoint level using decorators.

**Policy Rules**:
- Validation functions are defined per endpoint using `@UdalUserRequirements()`
- Only applies when decorator is present
- Custom business logic can be implemented
- Validation occurs after successful authentication and role checks

---

## 4. Compliance Policies

### 4.1 US Person Access Control

**Policy ID**: COMP-001  
**Scope**: US-Restricted Resources

Certain resources are restricted to US persons only due to export control regulations (ITAR/EAR compliance).

#### 4.1.1 US Access Policy

**Applicable Users**: `user.usPerson === true`

**Allowed Actions**:
- ✅ Access to all public resources
- ✅ Access to US-restricted resources
- ✅ Access to sensitive technical data
- ✅ Export-controlled information
- ✅ Full application functionality


#### 4.1.2 Global/Non-US Access Policy

**Applicable Users**: `user.usPerson === false` or `user.usPerson === undefined`

**Allowed Actions**:
- ✅ Access to public resources
- ✅ General business applications
- ✅ Non-technical documentation
- ✅ Commercial product information

**Restricted Actions**:
- ❌ US-restricted resources (protected by `@UseGuards(UsGuard)`)
- ❌ Export-controlled technical data
- ❌ Sensitive manufacturing information
- ❌ Advanced technology specifications



### 4.2 Boeing Person Classification

**Boeing Personnel** (`user.boeingPerson === true`):
- Enhanced access to internal systems
- Company-specific applications and data
- Internal collaboration tools

**Non-Boeing Personnel** (`user.boeingPerson === false`):
- Limited to customer-facing applications
- Restricted internal system access

---

## 5. Application Segmentation Policies

### 5.1 Multi-Tenant Isolation


**Policy Rules**:
- User permissions are isolated by application identifier
- Role assignments are application-specific
- No cross-application privilege inheritance
- Each application maintains independent security context

**Implementation**:
```typescript
// Roles are segmented by application
user.roles["manufacturing"] = ["operator", "viewer"]
user.roles["finance"] = ["analyst", "approver"]
```

### 5.2 Module-Level Access Control


**Policy Rules**:
- Fine-grained permissions at the module/feature level
- Hierarchical permission inheritance within applications
- Feature flags controlled by role assignments
- Dynamic module loading based on user permissions

---

## 6. Error Handling and Audit Policies

### 6.1 Security Error Messages


**Standardized Responses**:
- `401 Unauthorized`: Authentication failures
- `403 Forbidden`: Authorization failures
- Generic error messages to prevent information disclosure
- Detailed logging for security monitoring

### 6.2 Audit and Monitoring

**Requirements**:
- All authentication attempts are logged
- Authorization failures are tracked
- User context is attached to all requests for traceability
- Compliance violations are immediately flagged

---

## 7. Implementation Guidelines

### 7.1 Developer Guidelines

**For API Endpoints**:
```typescript
// Basic authentication
@UseGuards(JwtAuthGuard)

// Role-based access
@UseGuards(JwtAuthGuard, UdalRolesGuard)
@UdalRoles(['admin', 'operator'])

// US person restriction
@UseGuards(JwtAuthGuard, UsGuard)

// Complex business rules
@UseGuards(JwtAuthGuard, UdalJwtJsonLogicGuard)

// Custom user validation
@UseGuards(JwtAuthGuard, UdalLogicGuard)
@UdalUserRequirements((user) => user.department === 'Engineering')
```
