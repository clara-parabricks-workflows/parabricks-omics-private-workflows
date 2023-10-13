# Private Parabricks Workflows for Amazon Omics

This folder contains example WDL based workflows that use Parabricks to run on Amazon Omics.

These are provided AS-IS and are intended to demonstrate conventions, patterns, and best practices for writing workflows for scale. They are intended as starting points that you can customize to fit your specific requirements.

The software pre-requisites needed to build a private workflow for Amazon Omics are packaged as a Dockerfile in this repo. We will first build this Dockerfile, run it, log into the AWS CLI, and then submit jobs to Omics. 

## Step 1/3: Creating the environment to submit jobs to Omics

First we will build and run a Docker container on our local machine. To build the Docker container, run the following commands

```
cd dockerfiles
docker build -t omics-private-workflows . 
```

Now we can run the container: 

```
cd .. 
docker run --rm -it -v `pwd`:`pwd` -w `pwd` omics-private-workflows /bin/bash 
```

## Step 2/3: Logging into the AWS CLI 

To submit jobs to Omics, we must login to the AWS CLI with our preferred credentials. Use the following command to set that up: 

```
aws configure # Make sure to provide AWS Access Key ID, AWS Secret Access Key, and region
```

Now we are ready to build and submit the private workflows 

## Step 3/3: Building and submitting jobs to Omics

Use the following commands to first build this repo, and then to build a workflow. The workflow names can be found in the `parabricks/workflows` folder: 

```bash
cd parabricks
make
make run-{workflow_name}  # substitute "{workflow_name}" accordingly
```

If this is the first time running any workflow, `make` will perform the following build steps: 

1. Configure and deploy the `omx-ecr-helper` CDK app

   Workflows that run in AWS HealthOmics must have containerized tooling sourced from ECR private image repositories. These workflows use 4 unique container images. The `omx-ecr-helper` is a CDK application that automates converting container images from public repositories like Quay.io, ECR-Public, and DockerHub to ECR private image repositories.

2. Run a Step functions state machine from `omx-ecr-helper` to pull container images used by these workflows into ECR Private Repositories
3. Create AWS IAM roles and permissions policies required for workflow runs
4. Create an Amazon S3 bucket for staging workflow definition bundles and workflow execution outputs
5. Create a zip bundle for the workflow that is registered with AWS HealthOmics
6. Start an AWS HealthOmics Workflow run for the workflow with test parameters

Additional artifacts produced by the build process will be generated in `build/`.

You can customize the build process by modifying `conf/default.ini`.

## Cleanup
To remove local build assets run:

```bash
make clean
```

**Note**: this command does not delete any deployed AWS resources. You are expected to manage these as needed. Resources of note:

- No cost resources:
    - The `omx-ecr-helper` CDK app is serverless and does not incur costs when idle.
    - HealthOmics Workflows do not incur costs when not running

- Resources with costs
    - Amazon ECR Private repositories for container images have a storage cost - see [Amazon ECR pricing](https://aws.amazon.com/ecr/pricing/) for more details
    - Data generated and stored in S3 have a storage cost - see [Amazon S3 pricing](https://aws.amazon.com/s3/pricing/) for more details

## Further reading
Each workflow defintion and any supporting files are in its own folder with the following structure:

```text
workflows
├── {workflow_name}
│   ├── cli-input.yaml
│   ├── (main | named-entrypoint).wdl
│   ├── parameter-template.json
│   ├── test.parameters.json
│   └── ... additional supporting files ...
...
```

### Parameter details

The `parameter-template.json` file for each workflow should match `inputs{}` defined in the `workflow{}` stanza of the main entrypoint WDL.

The `test.parameters.json` file is a subset of the parameters used. Additional parameters:

- `ecr_registry`
- `aws_region`

are added and populated based on the AWS profile used during the build process (when you execute `make run-{workflow-name}`).
