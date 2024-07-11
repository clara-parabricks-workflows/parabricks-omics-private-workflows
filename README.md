# Private Parabricks Workflows for AWS HealthOmics

This folder contains example WDL based workflows that use Parabricks to run on AWS HealthOmics.

These are provided AS-IS and are intended to demonstrate conventions, patterns, and best practices for writing workflows for scale. They are intended as starting points that you can customize to fit your specific requirements.

The software pre-requisites needed to build a private workflow for AWS HealthOmics are packaged as a Dockerfile in this repo. We will first build this Dockerfile, run it, log into the AWS CLI, and then submit jobs to Omics. 

## Step 0/4: Creating private ECR repos for our workflow containers

AWS HealthOmics requires that any Docker containers that we use are inside of a private Elastic Container Repository (ECR). For this example we will be using a public Parabricks container, so we must move it into a private ECR repo. 

Create a private ECR repo and name it "parabricks". This is easiest to do in the AWS console using [these instructions](https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-create.html).  

Make sure that Omics has permissions to access this ECR repo by editing the Policy JSON according to instructions in the [AWS Docs](https://docs.aws.amazon.com/omics/latest/dev/permissions-resource.html#permissions-resource-ecr). 

Then on the command line, log in to ECR using: 

```
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.<region>.amazonaws.com
```

Pull the latest Parabricks Amazon Linux image using: 

``` 
docker pull nvcr.io/nvidia/clara/nvidia_clara_parabricks_amazon_linux:<version>
```

Tag the image to get it ready for ECR: 

```
docker tag nvcr.io/nvidia/clara/nvidia_clara_parabricks_amazon_linux:<version> <aws_account_id>.dkr.ecr.<region>.amazonaws.com/parabricks:<version>
```

Finally, push this image to your private ECR repo: 

```
docker push <aws_account_id>.dkr.ecr.<region>.amazonaws.com/parabricks:<version>
```

Now we have our Parabricks docker image in a place where AWS HealthOmics can see it. 

For troubleshoot help, please see the [Amazon docs on pushing to ECR repos](https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html). 

## Step 1/4: Creating the environment to submit jobs to Omics

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

## Step 2/4: Logging into the AWS CLI 

To submit jobs to Omics, we must login to the AWS CLI with our preferred credentials. Use the following command to set that up: 

```
aws configure # Make sure to provide AWS Access Key ID, AWS Secret Access Key, and region
```

Now we are ready to build and submit the private workflows 

## Step 3/4: Updating paths to data and the Parabricks version

Update the `test.parameters.json` file for the workflow that you plan to run. Each workflow has its own copy of this file at: 

```
parabricks/workflows/<workflow-name>/test.parameters.json
```


In this file, make sure that the paths to the data point to S3 buckets that you have access to, and update the `pb_version` to match the docker image tag for the Parabricks image you loaded into ECR. 

## Step 4/4: Building and submitting jobs to Omics

Now we are ready to build any Parabricks workflow!

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
