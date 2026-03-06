# Policy-as-Code IAM and Storage Security

## Overview

This repository demonstrates a policy-as-code DevSecOps implementation for secure IAM governance and encrypted cloud storage using Terraform and GitHub Actions.

## What the Project Includes

- Secure Amazon S3 bucket with public access blocking
- KMS-based encryption
- S3 bucket versioning
- Least-privilege IAM role and policy
- Automated CI/CD validation pipeline

## Security Validation Pipeline

The GitHub Actions pipeline automatically runs:

- Terraform format and validation
- TFLint static analysis
- Checkov infrastructure security scanning

## Purpose

This project demonstrates how Infrastructure-as-Code and policy-as-code can be combined to improve IAM governance and storage security in cloud environments.
