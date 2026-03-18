# Use case: Lambda cannot list S3 and cannot reach external API

This folder contains a **broken** scenario for assessment or practice:

- **GitHub Actions** workflow deploys Terraform and invokes the Lambda to validate the fix.
- **Terraform** provisions a VPC, private subnet (no NAT), an S3 bucket, ECR repo, and a **container image** Lambda. The Lambda uses a **Dockerfile** that has an intentional error the candidate must fix.
- The Lambda (once the Dockerfile is fixed) tries to list S3 and call an external API; with the current infra both fail (no S3 permissions, no NAT).

## Problem (current state)

### 1. Dockerfile (candidate must fix)

The Lambda is built from `lambda/Dockerfile`. The Dockerfile **copies the handler to the wrong path**: `COPY main.py /tmp/`. The AWS Lambda runtime looks for the handler module in `LAMBDA_TASK_ROOT` (`/var/task`), so it cannot load `main.handler` and the function fails on invoke (e.g. "Unable to import module 'main'" or handler not found).

**Fix:** Copy the module into the Lambda task root, e.g. `COPY main.py ${LAMBDA_TASK_ROOT}/` or `COPY main.py /var/task/`.

### 2. Lambda cannot list S3 buckets

The Lambda IAM role has only `AWSLambdaBasicExecutionRole` and `AWSLambdaVPCAccessExecutionRole`; it has no `s3:ListBuckets` or `s3:ListBucket` policy → Access Denied when listing buckets/objects.

### 3. Lambda cannot reach external API

The Lambda runs in a **private** subnet with **no** NAT Gateway. Outbound traffic to `https://httpbin.org` never reaches the internet → timeout.

## How to run

### Prerequisites

- AWS account and credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`).
- Add them as **repo secrets** in GitHub (so the workflow can run `terraform apply` and invoke the Lambda).
- No local setup is required: the GitHub runner builds the Lambda Docker image and pushes it to ECR.

### Run from GitHub (no local testing)

1. Make any change in the repo (e.g. fix `lambda/Dockerfile`, Terraform IAM for S3, and/or NAT routing).
2. Push to `main` (or open a PR to `main`).
3. The workflow `Deploy + Invoke Lambda (assessment)` will run:
   - `terraform apply` (create ECR first)
   - build + push Lambda Docker image to ECR
   - `terraform apply` (create VPC + S3 + Lambda)
   - invoke the Lambda and check the response

If the Lambda still reports errors (`errors` array not empty), the workflow fails. The logs show exactly what failed (Dockerfile handler import, S3 Access Denied, and/or external API timeout).

Note: if you test from a fork, GitHub may not provide secrets to PRs from forks.

Note: each workflow run uses a unique environment name (based on `github.run_id`), so it creates fresh resources. Be mindful of AWS quotas/cost.

## Fix (for interviewer or candidate)

1. **Dockerfile:** The handler module is not where the Lambda runtime expects it. Update the Dockerfile so the function can import and run the handler.
2. **S3 access:** Add IAM permissions to allow the Lambda to list S3 buckets and list objects in the created bucket.
3. **External API:** Ensure the Lambda (in private subnets) has outbound internet access (typically via NAT Gateway + a default route).

## Structure

```
use-case/
├── .github/workflows/
│   └── terraform.yml    # deploy + invoke on push/PR
├── lambda/
│   ├── Dockerfile       # Broken: COPY to /tmp/ — candidate fixes to ${LAMBDA_TASK_ROOT}/
│   └── main.py          # Lambda: list S3 + call httpbin
├── terraform/
│   ├── main.tf          # VPC, subnets (no NAT), S3, ECR, Lambda (Image from ECR)
│   ├── variables.tf
│   └── outputs.tf
└── README.md
```
