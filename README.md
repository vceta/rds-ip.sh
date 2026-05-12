# rds-ip.sh

![version](https://img.shields.io/badge/version-1.2-blue) ![bash](https://img.shields.io/badge/language-bash-green?logo=gnubash&logoColor=white) ![aws](https://img.shields.io/badge/requires-AWS%20CLI%20v2-orange?logo=amazonaws&logoColor=white) ![tested](https://img.shields.io/badge/tested-passing-brightgreen?logo=checkmarx&logoColor=white) ![license](https://img.shields.io/badge/license-Apache%202.0-yellowgreen)

**AWS PrivateLink IP Helper** — resolves the private IP address(es) of an RDS instance's Elastic Network Interface (ENI) using the AWS CLI.

When setting up [AWS PrivateLink](https://docs.aws.amazon.com/vpc/latest/privatelink/what-is-privatelink.html), you need to register the RDS instance's private IP address(es) as targets in a Network Load Balancer (NLB) target group. This script automates that discovery step.

## Prerequisites

- **AWS CLI v2** — owned and maintained by Amazon Web Services, licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)
  - Installation guide: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
  - Must be installed and configured with valid credentials before running this script
- IAM permissions:
  - `rds:DescribeDBInstances`
  - `ec2:DescribeNetworkInterfaces`
  - `sts:GetCallerIdentity`

## AWS Credentials Setup

Before running the script, ensure AWS CLI is authenticated. Two common approaches:

**Static credentials / IAM user:**
```bash
aws configure
```

**AWS SSO:**
```bash
aws configure sso
aws sso login --profile <your-sso-profile>
export AWS_PROFILE=<your-sso-profile>
```

> You can set `AWS_PROFILE` to switch between configured profiles without modifying any files:
> ```bash
> export AWS_PROFILE=my-sso-profile
> ```

**Temporary credentials from AWS Console:**

You can also paste temporary environment variables directly from the AWS Management Console:
1. Open the [AWS Console](https://console.aws.amazon.com)
2. Click your username (top-right) → **Security credentials**
3. Under **Temporary credentials**, click **Get CLI access**  
   *(or use AWS SSO portal → **Access Keys** button next to the account)*
4. Copy and paste the exported variables into your terminal:

```bash
export AWS_ACCESS_KEY_ID=ASIAxxxxxxxxxxxxxxxx
export AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
export AWS_SESSION_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

> Temporary credentials expire (typically after 1–12 hours). Re-paste them from the Console when they expire.

## Usage

> **Note:** After downloading the script, make it executable first:
> ```bash
> chmod +x rds-ip.sh
> ```
> To make it available system-wide, copy it to `/usr/local/sbin`:
> ```bash
> sudo cp rds-ip.sh /usr/local/sbin/rds-ip
> ```
> Then run it from anywhere as `rds-ip <RDS_INSTANCE_IDENTIFIER>`.

```bash
./rds-ip.sh <RDS_INSTANCE_IDENTIFIER> [-q|--quiet]
```

| Flag | Description |
|------|-------------|
| `<RDS_INSTANCE_IDENTIFIER>` | The RDS instance identifier (DB instance ID) |
| `-q`, `--quiet` | Print only the private IP address(es), suppress all info/warn messages |

### Example — Normal mode

```bash
./rds-ip.sh my-production-db
```

**Output:**
```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│ NOTE: RDS security groups can be shared across multiple RDS instances or other AWS resources.   │
│ The script may return wrong IP addresses if the security group is associated with more than one.│
│ Ensure to verify uniqueness of the security group associated for your specific RDS instance.    │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘

[INFO] AWS Account ID: 123456789012
[INFO] Found security group 'sg-0abc1234ef567890' for RDS database 'my-production-db'
[INFO] VPC ID: vpc-0abc1234ef567890
  ───────────────────────────────────────
[INFO]  Subnet ID: subnet-0abc1234
        Private IP(s): 10.0.1.5
  ───────────────────────────────────────
[INFO]  Subnet ID: subnet-0def5678
        Private IP(s): 10.0.2.8
```

### Example — Quiet mode

```bash
./rds-ip.sh my-production-db --quiet
```

**Output:**
```
10.0.1.5
10.0.2.8
```

## How It Works

1. Verifies AWS CLI is installed and credentials are valid
2. Looks up the security group attached to the RDS instance
3. Queries all ENIs associated with that security group
4. Prints the VPC ID, Subnet ID, and private IP(s) for each interface

## Notes

> RDS security groups can be shared across multiple RDS instances or other AWS resources.
> The script may return IP addresses belonging to other resources if the security group is not unique to your RDS instance.
> Always verify the output matches your specific RDS instance.

## Exit Codes

| Code | Meaning |
|------|---------|
| `0`  | Success |
| `61` | AWS API error or missing input |
| `126`| AWS CLI not installed |

## License

This script is licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

```
Copyright 2026 Petro Sydor

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

### Third-party Dependencies

| Tool | Owner | License |
|------|-------|---------|
| [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | Amazon Web Services | [Apache 2.0](https://github.com/aws/aws-cli/blob/develop/LICENSE.txt) |

## Author

petro.sydor@akriviahealth.net

## Release Notes

| Version | Changes |
|---------|---------|
| **v1.2** | Added `-q` / `--quiet` flag for IP-only output |
| **v1.1** | Added same-VPC validation across multiple interfaces |
| **v1.0** | Initial release |

## Integrity Verification

Verify the script has not been tampered with using the SHA-256 checksum:

**Linux:**
```bash
echo "52e5d68ae052cee49f3b900e4958ffbf6f750f9c6b29485bb2e139e073b04290  rds-ip.sh" | sha256sum -c
```

**macOS:**
```bash
echo "52e5d68ae052cee49f3b900e4958ffbf6f750f9c6b29485bb2e139e073b04290  rds-ip.sh" | shasum -a 256 -c
```

Or using the provided checksum file:

**Linux:**
```bash
sha256sum -c rds-ip.sh.sha256
```

**macOS:**
```bash
shasum -a 256 -c rds-ip.sh.sha256
```

| File | SHA-256 |
|------|---------|
| `rds-ip.sh` | `52e5d68ae052cee49f3b900e4958ffbf6f750f9c6b29485bb2e139e073b04290` |
