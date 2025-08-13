Based on the code snippets provided, here are the specific access policies that are defined:

## 1. **JWT Token Authentication Policy**
```typescript
// In JwtAuthGuard
if (!token) {
  throw new UnauthorizedException('No UDAL JWT provided in the Authorization Bearer.');
}
```
- **Policy**: All protected routes require a valid JWT token in Authorization Bearer header
- **Enforcement**: Automatic rejection if token is missing or invalid

## 2. **Role-Based Access Control Policies**
```typescript
// In UdalRolesGuard
const requiredRolesForApp = roles[app];
const userRolesForApp = user.roles[app];

// all required roles must be found in current user roles to pass
if (!requiredRolesForApp.every((x) => userRolesForApp.includes(x))) {
  return false;
}
```
- **Policy**: User must have ALL required roles for a specific application/module
- **Granular**: Role requirements are defined per application (`roles[app]`)
- **Strict Matching**: No partial role matches - all specified roles must be present

## 3. **JSON Logic-Based Dynamic Policies**
```typescript
// In UdalJwtJsonLogicGuard
const jsonLogicResult = jsonLogic.apply(jsonLogicObj, udalUser);

if (jsonLogicResult) {
  return true;
} else {
  throw new UnauthorizedException(
    'You do not have the appropriate access required for this request path',
    // Complex error message with requirements
  );
}
```
- **Policy**: Complex business rules using JSON Logic expressions
- **Dynamic**: Rules can be configured without code changes
- **Context-Aware**: Evaluates against full user object (udalUser)

## 4. **User Requirements Validation Policy**
```typescript
// In UdalLogicGuard
const userRequirements = this.reflector.get(UdalUserRequirements, context.getHandler());
if (!userRequirements) {
  return true; // if not using this guard, pass.
}

return userRequirements(user);
```
- **Policy**: Custom validation functions applied to user objects
- **Flexible**: Uses decorators to define specific requirements per endpoint
- **Optional**: Only applies when `@UdalUserRequirements()` decorator is present

## 5. **Geographic/Regulatory Compliance Policy**
```typescript
// In UsGuard
return user.usPerson;
```
- **Policy**: Only US persons can access certain resources
- **Compliance**: Likely implements ITAR or EAR export control regulations
- **Binary**: Simple boolean check on user attribute

## 6. **Application Module Segmentation Policy**
```typescript
// Implicit in role structure
user.roles[app] // roles are segmented by application
```
- **Policy**: User permissions are isolated by application/module
- **Multi-tenant**: Each application has independent role assignments
- **Isolation**: Prevents privilege escalation across applications

## 7. **Token Validation Policies**
```typescript
// In UdalJwtService
return this.jwtService.verifyAsync(jwt, {
  ignoreExpiration: false,
  algorithms: ['RS512'],
  publicKey: `-----BEGIN PUBLIC KEY-----\n${UdalJwtService.udalPublicKey}\n-----END PUBLIC KEY-----`,
  allowInvalidAsymmetricKeyTypes: true,
});
```
- **Policy**: Tokens must use RS512 algorithm
- **Expiration**: Tokens must not be expired
- **Cryptographic**: Public key validation required
- **Security**: Asymmetric key validation enforced

## 8. **Request Context Policies**
```typescript
// User attachment to request
request.user = payload;
```
- **Policy**: Authenticated user context is attached to all requests
- **Traceability**: User identity is available throughout request lifecycle
- **Audit**: Enables logging and tracking of user actions

These policies work together to create a comprehensive security model that can handle simple authentication through complex business rule enforcement, with particular attention to regulatory compliance requirements.
