# Use case (Candidate): Lambda cannot list S3 and cannot reach external API

## What you are given
You get a public GitHub repo that runs an assessment via GitHub Actions:

- GitHub Actions deploys AWS infrastructure with Terraform.
- It builds a **container image** for a Lambda function and deploys it.
- It invokes the Lambda and checks the returned result.

The repository is intentionally **broken**. Your job is to fix the issues so the workflow passes and the Lambda returns no errors.

## What is failing (current symptoms)
When the workflow runs, the Lambda invocation reports one or more of these problems:

- **S3-related errors** (e.g. AccessDenied when listing buckets or listing bucket objects).
- **External API errors** (e.g. timeouts / connection failures reaching an HTTPS endpoint).
- Potentially, **container/runtime errors** (e.g. handler/module import issues).

You will see the details in the GitHub Actions logs for the `Invoke Lambda` step and the Lambda output the workflow prints.

## Your task
Make the changes required so that, after your commit, the GitHub Actions workflow:

1. Successfully deploys the infrastructure.
2. Successfully invokes the Lambda.
3. Reports **no Lambda errors** (the workflow fails if an `errors` array is non-empty, or if the Lambda output shape is unexpected).

## Where to look in the repo
- `lambda/`:
  - `Dockerfile` (container build for Lambda)
  - `main.py` (the Lambda handler code)
- `terraform/`:
  - IAM for the Lambda execution role
  - VPC/subnets/routing affecting Lambda egress

## Hints (without giving away the full solution)
1. **If the workflow fails before printing “Lambda output” or shows a handler/import problem**
   - The container image likely does not place the handler where the Lambda runtime expects it.
2. **If you see S3 `AccessDenied`**
   - Check the Lambda execution role permissions needed by the code in `lambda/main.py`.
3. **If you see timeouts calling an external HTTPS URL**
   - The Lambda runs inside VPC subnets; confirm it has a valid path to the public internet for outbound HTTPS.

## Definition of Done
Your submission is successful when a new run of the workflow ends with:
- `Invoke Lambda and fail on errors` completing without failing (no “Lambda errors present” message),
- and the printed Lambda output shows S3 listing and external API call succeeding.

## How to run (from GitHub only)
1. Make commits/PRs in your fork.
2. Push to `main` in your fork to trigger the workflow.

## Required configuration
In your fork, set the repo secret:
- `AWS_ROLE_ARN` (used by GitHub OIDC to assume an AWS IAM role)

Do not hardcode AWS credentials in the repo.

