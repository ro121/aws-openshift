# Splunk Alerts for Containerized API in OpenShift

## Overview

This document provides guidance on managing Splunk alerts for containerized APIs running in OpenShift. It covers access procedures, alert configurations, and notification channels.

---

## 1. Accessing Splunk

### Splunk URL
- **Production Environment**: `https://splunk.company.com`
- **Non-Production Environment**: `https://splunk-nonprod.company.com`

### Login Process
1. Navigate to the appropriate Splunk URL based on your environment
2. Authenticate using your corporate SSO credentials
3. Select the appropriate workspace/app for your team
4. Default landing page will show the Search & Reporting interface

### Initial Access
- All employees have **read-only** access by default
- To create or modify alerts, you need **power_user** role or higher

### Splunk Index and Namespace Configuration

The following table shows how Splunk indexes are mapped to OpenShift namespaces:

| Splunk Index | OpenShift Namespace(s) | Environment | Description |
|--------------|------------------------|-------------|-------------|
| **bdsdp-global** | `api-dev`<br>`api-pre`<br>`api-prod` | Development<br>Pre-Production<br>Production | Global index capturing logs from all environment namespaces. Use this index for cross-environment searches and dashboards. |
| **dev** | `api-dev` | Development | Development environment specific logs. Use for dev-only alerts and testing. |
| **pre** | `api-pre` | Pre-Production | Pre-production environment logs. Use for staging validation and pre-prod monitoring. |
| **prod** | `api-prod` | Production | Production environment logs. Use for production-only alerts and critical monitoring. |

**Usage Guidelines**:
- Use `index=bdsdp-global` when you need to search across all environments
- Use environment-specific indexes (`dev`, `pre`, `prod`) when creating environment-specific alerts
- For production alerts, consider using `index=prod` to avoid noise from dev/pre environments
- The `bdsdp-global` index is useful for comparative analysis across environments

**Example Search Queries**:
```
# Search across all environments
index=bdsdp-global namespace="api-*" status=500

# Search production only
index=prod namespace="api-prod" status=500

# Search specific environment
index=dev namespace="api-dev" error
```

---

## 2. Obtaining Power User Access

### Prerequisites
- Active employee account
- Manager approval
- Completion of Splunk training (available in Learning Portal)
- Valid business justification

### Request Process

1. **Submit ServiceNow Request**
   - Navigate to ServiceNow → IT Service Catalog
   - Search for "Splunk Access Request"
   - Select role: **power_user**
   - Provide business justification
   - Add manager for approval

2. **Approval Workflow**
   - Manager approval (1-2 business days)
   - Security team review (2-3 business days)
   - Identity Management provisioning (1 business day)

3. **Access Validation**
   - Log out and log back into Splunk
   - Verify "Create Alert" option is available in the Search interface
   - Check access to Alert Manager

### Estimated Timeline
- Total turnaround time: 3-5 business days

---

## 3. Alerting Platforms

### Email Distribution Lists

| Environment | Distribution List | Purpose |
|------------|------------------|----------|
| Production | api-prod-alerts@company.com | Critical production alerts |
| Non-Production | api-nonprod-alerts@company.com | Development/staging alerts |
| On-Call | api-oncall@company.com | 24/7 incident response |

**To Subscribe**: Send request to team lead or email list administrator

### Mattermost Integration

**Channel Information**:
- **Production Alerts**: `~api-prod-alerts`
- **Non-Production Alerts**: `~api-nonprod-alerts`
- **Team Channel**: `~platform-team`

**Joining Channels**:
1. Open Mattermost desktop/web application
2. Click on "+" next to "Channels"
3. Search for the channel name
4. Click "Join Channel"

**Webhook Configuration** (for Power Users):
- Webhook URL is stored in team password vault
- Contact DevOps team lead for webhook credentials
- Webhooks are configured per alert in Splunk

---

## 4. Alert Definitions

### 4.1 Critical Severity Alerts

#### Cluster Failure
**Condition Monitored**: Detects cluster-level failures and node issues

**Search Query**:
```
index=openshift sourcetype=kubernetes:* namespace="api-*" 
("cluster failure" OR "cluster unavailable" OR "node not ready" OR "NotReady")
| stats count by node, message
```

**Trigger Condition**: Any occurrence detected  
**Severity**: Critical  
**Notification**: Email DL + Mattermost + PagerDuty  
**Why It's Important**: Detects infrastructure-level issues at Kubernetes/cluster level. Must be acted upon immediately to avoid widespread outages.  
**Action Required**: Immediate escalation to infrastructure team, check node health, investigate cluster stability

---

#### 5XX Server Errors
**Condition Monitored**: Detects HTTP status codes 500-599

**Search Query**:
```
index=openshift sourcetype=api:access namespace="api-*" status>=500 status<600
| stats count as error_count by status, api_endpoint
| where error_count > 10
```

**Trigger Condition**: More than 10 5XX errors in 5 minutes  
**Severity**: Critical  
**Notification**: Email DL + Mattermost + PagerDuty  
**Why It's Important**: Captures backend failures (server crashes, database errors, timeouts). High severity since it directly impacts service availability.  
**Action Required**: Check application logs, verify database connectivity, review recent deployments, investigate backend services

---

#### Pods Down
**Condition Monitored**: Detects container or Kubernetes pod failures

**Search Query**:
```
index=openshift sourcetype=kubernetes:* namespace="api-*" 
("pod down" OR "pods unavailable" OR "CrashLoopBackOff" OR "ImagePullBackOff" OR "Error" OR "Failed")
| stats count by pod_name, status, reason
```

**Trigger Condition**: Any pod in failed state for more than 2 minutes  
**Severity**: Critical  
**Notification**: Email DL + Mattermost + PagerDuty  
**Why It's Important**: Essential for cluster stability and application uptime. Indicates container failures that prevent service from running.  
**Action Required**: Check pod logs (`oc logs`), describe pod for events (`oc describe pod`), verify resource limits, check image availability

---

#### Service Down
**Condition Monitored**: Detects microservice unavailability

**Search Query**:
```
index=openshift sourcetype=* namespace="api-*" 
("service down" OR "service unavailable" OR "service not responding" OR "connection refused")
| stats count by service_name, message
```

**Trigger Condition**: Service unavailable for more than 1 minute  
**Severity**: Critical  
**Notification**: Email DL + Mattermost + PagerDuty  
**Why It's Important**: Catches microservice failures. Ensures SREs know when dependent services are not responding.  
**Action Required**: Verify service endpoints, check pod health, review service configuration, test connectivity

---

#### Routes Unavailable
**Condition Monitored**: Detects ingress/network path issues

**Search Query**:
```
index=openshift sourcetype=kubernetes:* namespace="api-*" 
("route unavailable" OR "routes down" OR "route not found" OR "ingress error")
| stats count by route_name, namespace
```

**Trigger Condition**: Route unavailable for more than 1 minute  
**Severity**: Critical  
**Notification**: Email DL + Mattermost + PagerDuty  
**Why It's Important**: Critical for traffic routing and API availability. Without routes, external traffic cannot reach services.  
**Action Required**: Check route configuration (`oc get routes`), verify DNS resolution, review ingress controller logs, test endpoint accessibility

---

### 4.2 High Severity Alerts

#### 401 Unauthorized
**Condition Monitored**: Detects HTTP status code 401

**Search Query**:
```
index=openshift sourcetype=api:access namespace="api-*" status=401
| stats count as auth_failures by client_id, api_endpoint
| where auth_failures > 50
```

**Trigger Condition**: More than 50 401 errors in 10 minutes  
**Severity**: High  
**Notification**: Email DL + Mattermost  
**Why It's Important**: Indicates failed authentication attempts. Could mean expired tokens, incorrect credentials, or misconfigured IAM policies. Critical for security and user access issues.  
**Action Required**: Review authentication service logs, check token expiration settings, verify IAM policy configuration, investigate potential security incidents

---

#### 475 Error
**Condition Monitored**: Detects HTTP status code 475 (custom application error)

**Search Query**:
```
index=openshift sourcetype=api:access namespace="api-*" status=475
| stats count as error_count by api_endpoint, error_message
| where error_count > 20
```

**Trigger Condition**: More than 20 475 errors in 10 minutes  
**Severity**: High  
**Notification**: Email DL + Mattermost  
**Why It's Important**: Specific to application/business logic (e.g., custom security validation). Important for app-level monitoring where generic 4XX/5XX won't catch it.  
**Action Required**: Review application-specific validation logic, check business rule configuration, investigate custom security policies

---

### 4.3 Medium Severity Alerts

#### Variable Not Found
**Condition Monitored**: Detects missing configuration or environment variables

**Search Query**:
```
index=openshift sourcetype=* namespace="api-*" 
("variable not found" OR "undefined variable" OR "missing environment variable" OR "env var not set")
| stats count by pod_name, variable_name
```

**Trigger Condition**: More than 5 occurrences in 15 minutes  
**Severity**: Medium  
**Notification**: Email DL + Mattermost  
**Why It's Important**: Usually indicates configuration or environment issues. Prevents service failures due to missing variables.  
**Action Required**: Review ConfigMaps and Secrets, verify environment variable configuration, check deployment manifests, update missing variables

---

## 5. Alert Configuration Guidelines

### Creating Alerts in Splunk

1. **Navigate to Alerts**
   - Go to Settings → Searches, reports, and alerts
   - Click "New Alert"

2. **Configure Search**
   - Paste the search query from the alert definition
   - Set search time range (typically "real-time" or last 5/10 minutes)
   - Click "Next"

3. **Set Trigger Conditions**
   - Choose trigger type: "Number of Results" or custom condition
   - Set threshold based on alert definition
   - Configure throttle suppression if needed

4. **Configure Actions**
   - **Email**: Add distribution list email address
   - **Webhook**: Add Mattermost webhook URL for channel notifications
   - **Script**: (Optional) Add PagerDuty integration script for critical alerts

5. **Set Alert Priority**
   - High/Critical alerts: Every time condition is met
   - Medium alerts: Once per hour (with throttling)
   - Low alerts: Once per day (digest)

### Alert Naming Convention
Use this format: `[ENVIRONMENT]-[SEVERITY]-[ALERT_NAME]`

Examples:
- `PROD-CRITICAL-ClusterFailure`
- `PROD-HIGH-401Unauthorized`
- `NONPROD-MEDIUM-VariableNotFound`

---

## 6. Alert Response Procedures

### Critical Alert Response (5-10 minute SLA)
1. Acknowledge alert in PagerDuty
2. Check OpenShift console for immediate visibility
3. Execute relevant runbook procedure
4. Escalate to on-call engineer if needed
5. Update incident ticket with findings

### High Alert Response (15-30 minute SLA)
1. Acknowledge notification
2. Investigate logs and metrics in Splunk
3. Follow troubleshooting guide
4. Document findings in team channel
5. Implement fix or create remediation ticket

### Medium Alert Response (1-4 hour SLA)
1. Review alert during business hours
2. Analyze patterns and trends
3. Schedule fix in upcoming sprint if needed
4. Update configuration documentation

---

## 7. Alert Tuning and Maintenance

### Monthly Review Checklist
- [ ] Review false positive rate for each alert
- [ ] Adjust thresholds based on baseline metrics
- [ ] Update notification channels if team structure changed
- [ ] Verify all alerts are still relevant
- [ ] Remove or archive unused alerts
- [ ] Document any threshold changes in this page

### Suppression During Maintenance
When performing planned maintenance:
1. Create maintenance window in Splunk
2. Suppress relevant alerts for the duration
3. Document suppression in team chat
4. Re-enable alerts after maintenance completion
5. Verify alerts are functioning post-maintenance

---

## 8. Troubleshooting

### Common Issues

**Issue**: Alert not triggering when expected  
**Resolution**: 
- Verify search query returns results manually
- Check alert is enabled (not disabled)
- Review cron schedule if scheduled alert
- Confirm trigger threshold is correctly set

**Issue**: Too many false positives  
**Resolution**:
- Increase threshold values
- Add additional filters to search query
- Implement alert throttling
- Review baseline metrics to adjust trigger conditions

**Issue**: Missing alert notifications  
**Resolution**: 
- Verify email address is subscribed to distribution list
- Check Mattermost webhook configuration
- Review Splunk alert action logs
- Confirm notification channels are not muted

**Issue**: Alert fatigue from duplicate notifications  
**Resolution**:
- Enable alert throttling (suppress for X minutes after triggering)
- Consolidate related alerts
- Implement digest-style notifications for non-critical alerts

---

## 9. OpenShift Troubleshooting Commands

Quick reference for investigating alerts:

```bash
# Check pod status
oc get pods -n <namespace>

# View pod logs
oc logs <pod-name> -n <namespace> --tail=100

# Describe pod for events
oc describe pod <pod-name> -n <namespace>

# Check service endpoints
oc get svc -n <namespace>
oc describe svc <service-name> -n <namespace>

# Check routes
oc get routes -n <namespace>
oc describe route <route-name> -n <namespace>

# Check node status
oc get nodes

# View recent events
oc get events -n <namespace> --sort-by='.lastTimestamp'

# Check resource usage
oc adm top pods -n <namespace>
oc adm top nodes
```

---

## 10. Contacts and Support

| Role | Contact | Purpose |
|------|---------|---------|
| Splunk Admin Team | splunk-admins@company.com | Access issues, platform problems |
| DevOps Lead | devops-lead@company.com | Alert configuration guidance |
| On-Call Engineer | Use PagerDuty escalation | Critical incident response |
| OpenShift Platform Team | openshift-support@company.com | Infrastructure and cluster issues |
| Security Team | security@company.com | Security-related alerts (401 errors) |

---

## 11. Additional Resources

- **Splunk Documentation**: [Splunk Alert Reference](https://docs.splunk.com/Documentation/Splunk/latest/Alert/Aboutalerts)
- **OpenShift Logging**: Internal wiki page on OpenShift logging architecture
- **Alert Runbooks**: Team Confluence space → Runbooks section
- **Training Materials**: 
  - Splunk Power User Course (Learning Portal)
  - OpenShift Operations Training
  - Incident Response Procedures

---

## 12. Appendix: Alert Summary Table

| Alert Name | Severity | Threshold | Notification Channels | SLA |
|------------|----------|-----------|----------------------|-----|
| Cluster Failure | Critical | Any occurrence | Email + Mattermost + PagerDuty | 5 min |
| 5XX Server Errors | Critical | >10 in 5 min | Email + Mattermost + PagerDuty | 5 min |
| Pods Down | Critical | >2 min down | Email + Mattermost + PagerDuty | 5 min |
| Service Down | Critical | >1 min down | Email + Mattermost + PagerDuty | 5 min |
| Routes Unavailable | Critical | >1 min down | Email + Mattermost + PagerDuty | 5 min |
| 401 Unauthorized | High | >50 in 10 min | Email + Mattermost | 15 min |
| 475 Error | High | >20 in 10 min | Email + Mattermost | 15 min |
| Variable Not Found | Medium | >5 in 15 min | Email + Mattermost | 1 hour |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-05 | Platform Team | Initial document creation |
| 1.1 | 2025-10-05 | Platform Team | Updated with specific alert definitions |

---

**Last Updated**: October 5, 2025  
**Document Owner**: Platform Engineering Team  
**Review Cycle**: Monthly
