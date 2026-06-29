# State bootstrap

Creates the per-environment S3 buckets that hold Terraform/Terragrunt state, and the native S3 lockfile that serializes concurrent applies, for the rest of the platform. Run once per fork, before any other apply, and tear down after the platform itself is destroyed.

## Why a separate configuration

Terraform state lives in the S3 buckets created here. The bucket cannot store the state of its own creation (chicken-and-egg). Keeping this bootstrap as a small standalone Terraform configuration with **local** state side-steps the problem and keeps `terraform destroy` symmetric with `terraform apply`.

## Resources

For each environment in `var.environments` (default: `dev`, `prod`):

- **S3 bucket** `${aws_account_id}-${project}-${environment}-tfstate`, versioned, encrypted at rest with SSE-S3 (AES256), all four public-access blocks enabled, `force_destroy = true` for clean teardown.

State locking is handled by Terraform's S3-native lockfile mechanism (`use_lockfile = true` in the Terragrunt backend config). Concurrent applies are serialized by an S3 conditional-write lock object that lives next to the state file in the same bucket, so no separate DynamoDB table is required.

The bucket name embeds the AWS account ID so this configuration can be applied to any AWS account without manual renaming; the global-uniqueness requirement of S3 is satisfied automatically.

## Usage

Requires `AWS_ACCOUNT_ID` and standard AWS credentials in the shell. Run from inside this directory:

```sh
terraform init
terraform apply
```

A single apply provisions the state primitives for both environments. The local Terraform state file lives in this directory and is gitignored.

## Teardown

After running `terragrunt run-all destroy` for the platform itself:

```sh
terraform destroy
```

`force_destroy = true` on the buckets purges versioned state objects automatically during destroy.

## Design notes

### `for_each` over Terraform workspaces

Both environments are provisioned in a single `terraform apply` using `for_each`, rather than via separate workspaces. HashiCorp's own documentation explicitly recommends *against* using workspaces for environment separation; workspaces are intended for ephemeral parallel copies of the same infrastructure (feature branches, throwaway test stacks), not for dev/prod. Since this bootstrap targets a single AWS account, `for_each` is the simpler and more idiomatic choice, and a real multi-account deployment would restructure into per-account directories rather than adopting workspaces.

### `force_destroy = true` is portfolio-specific

The buckets are created with `force_destroy = true` so the build → screenshot → destroy lifecycle of this portfolio works cleanly. **In a real production deployment, the prod bucket should have `force_destroy = false`**: accidentally purging versioned state files in production is catastrophic and unrecoverable. Surfacing this distinction is more honest than hiding it.

### Encryption: SSE-S3 over SSE-KMS

The state buckets use SSE-S3 (AES256, AWS-managed keys). SSE-KMS with a customer-managed key was considered and not adopted: the operational overhead (key lifecycle, per-API-call cost, additional documentation) is not justified for the data classification of Terraform state, and the rest of the platform already carries the strong security signals (IRSA, network policies, OIDC federation, Secrets Manager rotation). Switching to SSE-KMS later is a single-resource configuration change in this directory.
