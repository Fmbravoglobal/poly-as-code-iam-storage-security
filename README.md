# policy-as-code-iam-storage-security

[![Security Pipeline](https://github.com/Fmbravoglobal/poly-as-code-iam-storage-security/actions/workflows/security-pipeline.yml/badge.svg)](https://github.com/Fmbravoglobal/poly-as-code-iam-storage-security/actions/workflows/security-pipeline.yml)

## Overview

A **Policy-as-Code DevSecOps framework** that implements secure IAM governance and encrypted cloud storage infrastructure using Terraform. Security controls are not applied manually — they are codified, version-controlled, and automatically validated through a multi-scanner CI/CD pipeline on every commit.

This project demonstrates how infrastructure policy can replace manual security review, ensuring every deployment is compliant by design.

---

## Architecture

```
  Developer Push / Pull Request
           │
           ▼
  ┌─────────────────────────────────────────┐
  │          GitHub Actions CI/CD           │
  │                                         │
  │  terraform fmt ──► terraform validate   │
  │         │                               │
  │         ▼                               │
  │   Checkov Scan ──► KICS Scan            │
  │         │                               │
  │         ▼                               │
  │   Policy Gate: block on violations      │
  └─────────────────┬───────────────────────┘
                    │ passes
                    ▼
  ┌─────────────────────────────────────────┐
  │         AWS Infrastructure              │
  │                                         │
  │  ┌────────────────────────────────────┐ │
  │  │  KMS Customer-Managed Key          │ │
  │  │  Key rotation enabled              │ │
  │  │  Least-privilege key policy        │ │
  │  └────────────────┬───────────────────┘ │
  │                   │ encrypts            │
  │  ┌────────────────▼───────────────────┐ │
  │  │  Secure S3 Bucket                  │ │
  │  │  ├── KMS encryption (aws:kms)      │ │
  │  │  ├── Public access: BLOCKED        │ │
  │  │  ├── Versioning: ENABLED           │ │
  │  │  ├── Lifecycle: configured         │ │
  │  │  └── Logging ──► Log Bucket        │ │
  │  └────────────────────────────────────┘ │
  │                                         │
  │  ┌────────────────────────────────────┐ │
  │  │  IAM Role (EC2 workload identity)  │ │
  │  │  ├── Least-privilege S3 policy     │ │
  │  │  └── Read-only scoped to bucket    │ │
  │  └────────────────────────────────────┘ │
  │                                         │
  │  ┌────────────────────────────────────┐ │
  │  │  SNS Topic (encrypted)             │ │
  │  │  S3 object events ──► subscribers  │ │
  │  └────────────────────────────────────┘ │
  └─────────────────────────────────────────┘
```

---

## Infrastructure Components

| Resource | Security Configuration |
|---|---|
| `aws_kms_key` | Customer-managed, rotation enabled, root-only key policy |
| `aws_s3_bucket` | Private, KMS-encrypted, versioned, lifecycle-managed |
| `aws_s3_bucket_public_access_block` | All 4 block settings enabled |
| `aws_s3_bucket_logging` | Access logs streamed to dedicated log bucket |
| `aws_s3_bucket_notification` | Object events published to encrypted SNS topic |
| `aws_iam_role` | EC2 assume-role, no inline policies |
| `aws_iam_policy` | Least-privilege: ListBucket + GetObject only |
| `aws_iam_role_policy_attachment` | Policy attached via ARN, not inline |

---

## Policy-as-Code Controls

Every resource in this repository was written to pass automated policy checks:

- **No public S3 access** — enforced by `aws_s3_bucket_public_access_block`
- **Encryption required** — KMS customer-managed key, bucket key enabled
- **No wildcard IAM actions** — policy scoped to `s3:ListBucket` and `s3:GetObject`
- **Versioning enabled** — supports data recovery and audit requirements
- **Logging enabled** — all S3 access requests logged
- **SNS encryption** — event notification topic uses same KMS key

---

## CI/CD Pipeline

```yaml
on: [push, pull_request]

jobs:
  security-scan:
    steps:
      - terraform fmt -check
      - terraform validate
      - checkov --directory terraform/
      - kics scan --path terraform/
```

The pipeline **blocks merges** if any critical policy violation is detected.

---

## Prerequisites

- Terraform >= 1.4.0
- AWS CLI configured with appropriate permissions
- AWS account with permissions to create IAM, S3, KMS, and SNS resources

## Deployment

```bash
cd terraform/
terraform init
terraform plan -var="bucket_name=my-secure-bucket" -var="aws_region=us-east-1"
terraform apply
```

---

## Compliance Alignment

| Framework | Controls Addressed |
|---|---|
| NIST 800-53 | AC-3, SC-28, AU-2, AU-9 |
| CIS AWS Benchmark | 1.x (IAM), 2.1.x (S3) |
| SOC 2 Type II | CC6.1, CC6.7 |
| PCI-DSS | Req. 3, 7, 10 |

---

## Repository Structure

```
poly-as-code-iam-storage-security/
├── terraform/
│   ├── main.tf          # KMS, S3, IAM, SNS resources
│   ├── variables.tf     # Input variables
│   └── outputs.tf       # Output values
└── .github/
    └── workflows/
        └── security-pipeline.yml
```

---

## Author

**Oluwafemi Alabi Okunlola** | Cloud Security Engineer | DevSecOps Specialist
[oluwafemiokunlola308@gmail.com](mailto:oluwafemiokunlola308@gmail.com)
