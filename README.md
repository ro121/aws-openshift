## Resource Quota Increase Request Report

### Project: `bds-compliance`

**Date:** 17th June 2025

#### Overview

This report highlights the current resource utilization in the `bds-compliance` project on our OpenShift cluster and proposes an increase in resource quotas to ensure continuous and uninterrupted operations.

#### Current Resource Utilization Summary

| Resource Type          | Allocated Quota | Current Usage | Usage Percentage |
| ---------------------- | --------------- | ------------- | ---------------- |
| CPU                    | 25 cores        | 14 cores      | 56%              |
| Memory                 | 25Gi            | 15.2Gi        | 61%              |
| Limits.CPU             | 50 cores        | 29 cores      | 58%              |
| Limits.Memory          | 50Gi            | 31.2Gi        | 61%              |
| Pods                   | 50              | 24            | 48%              |
| PersistentVolumeClaims | 20              | 4             | 20%              |
| Requests.Storage       | 50Gi            | 4Gi           | 8%               |

#### Observations

* Memory and CPU utilization have consistently remained above the 55-60% mark, indicating limited capacity for growth and scalability.
* Pod utilization, while currently moderate, could quickly increase with future service expansion or scaling demands.
* Current storage and PersistentVolumeClaims usage is low, but anticipated application growth, especially for database and logging services, is expected.
* Due to resource constraints, replicas are maintained at a minimum level, limiting redundancy and increasing the risk of downtime.
* There is currently no autoscaler implemented for services, causing manual intervention and delayed response to demand spikes.
* The UI service runs with only one replica because it is resource-intensive. Observed impacts during resource usage spikes include degraded user experience, slower response times, and increased likelihood of service outages. Increasing replicas even slightly causes total resource consumption to exceed 96%, critically limiting overall cluster health.

#### Upcoming Changes

* Databases will be transitioned to StatefulSets, requiring more robust and persistent storage solutions.
* New resource-intensive services will be added to the application, significantly increasing resource demand.
* Pagination will be implemented, expected to increase database and API processing loads.

#### Risks if Resources are Not Increased

* Potential for throttling and performance degradation, particularly for CPU and memory-intensive operations.
* Increased risk of pod eviction due to insufficient memory during peak workloads or deployments.
* Limited ability to scale new or existing services, affecting business continuity.

#### Recommended New Resource Quotas

| Resource Type          | Current Quota | Proposed Quota |
| ---------------------- | ------------- | -------------- |
| CPU                    | 25 cores      | 40 cores       |
| Memory                 | 25Gi          | 40Gi           |
| Limits.CPU             | 50 cores      | 75 cores       |
| Limits.Memory          | 50Gi          | 75Gi           |
| Pods                   | 50            | 75             |
| PersistentVolumeClaims | 20            | 30             |
| Requests.Storage       | 50Gi          | 75Gi           |
| Services               | 50            | 60             |

#### Justification

Increasing the quotas as proposed will provide sufficient headroom to accommodate projected service expansions, prevent resource bottlenecks, and maintain optimal system performance and reliability.

#### Next Steps

* Obtain approval from OpenShift cluster administrators.
* Implement quota adjustments and monitor utilization.
* Schedule quarterly reviews to proactively manage resource capacity and demand.

---

Prepared by:

\[Your Name]
\[Your Job Title]
\[Date]
