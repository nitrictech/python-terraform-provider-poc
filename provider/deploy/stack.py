import json
import os
import shutil
import betterproto
from cdktf import TerraformStack, TerraformVariable, LocalBackend
from constructs import Construct
from nitric.proto.deployments.v1 import (
    # DeploymentBase,
    DeploymentUpRequest,
    # DeploymentUpEvent,
    # DeploymentDownRequest,
    # DeploymentDownEvent
)
from nitric.proto.resources.v1 import ResourceType, Action
import docker
from docker.errors import APIError
from cdktf_cdktf_provider_google import provider

from imports.cloudrun import Cloudrun
from imports.queue import Queue
from imports.secret import Secret
from imports.storage import Storage
from imports.api import Api
from imports.roles import Roles
from imports.policy import Policy
from imports.stack import Stack
from provider.deploy.api import convert_openapi_to_swagger
from nitric.utils import dict_from_struct


def source_image_cmd(source_image):
    """Get a source images command ready for wrapping"""
    if not source_image:
        raise ValueError(f"source_image is required {source_image}")

    client = docker.from_env()

    try:
        image_inspect = client.images.get(source_image)
    except APIError as e:
        raise ValueError(f"Could not inspect image: {source_image}") from e

    config = image_inspect.attrs
    if config is None:
        raise ValueError(f"Could not inspect image config: {source_image}")

    entrypoint = config.get("Config", {}).get("Entrypoint")
    cmd = config.get("Config", {}).get("Cmd")

    cmd = entrypoint if entrypoint is not None else [] + cmd if cmd is not None else []

    if len(cmd) == 0:
        raise ValueError(
            f"Could not determine entrypoint or cmd for image: {source_image}"
        )

    return cmd


def create_provider_runtime_image(source_img: str, image_name: str):
    """Wrap the source image with with the provider runtime binary"""
    client = docker.from_env()

    if not os.path.isdir("/tmp/build"):
        os.makedirs("/tmp/build")

    shutil.copy("/app/runtime/Dockerfile", "/tmp/build/Dockerfile")
    shutil.copy("/app/runtime/runtime", "/tmp/build/runtime")

    try:
        # Run the docker build
        build = client.images.build(
            path="/tmp/build", tag=image_name, buildargs={"BASE_IMAGE": source_img}
        )

        # TODO: print status of the build
        # for line in build:
        #     print(line)

    except Exception as e:
        raise RuntimeError(f"Could not build image: {image_name}", e)


class TerraformGoogleCloudStack(TerraformStack):
    """Terraform Google Cloud Stack"""

    def __init__(self, scope: Construct, id: str, req: DeploymentUpRequest):
        super().__init__(scope, id)
        resources = req.spec.resources

        gcp_project_id = TerraformVariable(
            self,
            "gcpProjectId",
            type="string",
            description="GCP project to deploy into",
        )

        deployment_region = TerraformVariable(
            self,
            "region",
            type="string",
            description="What region should the stack be deployed to",
        )

        LocalBackend(self, path=f"./terraform.{id}.tfstate")

        # Create google provider
        provider.GoogleProvider(
            scope=self,
            id="google_provider",
            project=gcp_project_id.string_value,
            region=deployment_region.string_value,
        )

        stack = Stack(
            self, 
            "stack", 
            stack_name=id,
            region=deployment_region.string_value
        )

        # Normally this would be a separate stack
        # Adding this here for the sake of demo completeness
        nitric_roles = Roles(
            self, "nitric_roles", project_id=gcp_project_id.string_value
        )

        # Filter for all services in resources
        all_services = [
            res
            for res in resources
            if betterproto.which_one_of(res, "config")[0] == "service"
        ]
        all_apis = [
            res
            for res in resources
            if betterproto.which_one_of(res, "config")[0] == "api"
        ]
        all_buckets = [
            res
            for res in resources
            if betterproto.which_one_of(res, "config")[0] == "bucket"
        ]
        all_secrets = [
            res
            for res in resources
            if betterproto.which_one_of(res, "config")[0] == "secret"
        ]
        all_queues = [
            res
            for res in resources
            if betterproto.which_one_of(res, "config")[0] == "queue"
        ]
        all_policies = [
            res
            for res in resources
            if betterproto.which_one_of(res, "config")[0] == "policy"
        ]

        services: dict[str, Cloudrun] = {}
        # Deploy all services
        for service in all_services:
            # Wrap the source image with the runtime
            cmd = source_image_cmd(service.service.image.uri)

            create_provider_runtime_image(service.service.image.uri, service.id.name)

            svc_resource = Cloudrun(
                self,
                service.id.name,
                service_name=service.id.name,
                stack_id=stack.stack_id_output,
                cmd=cmd,
                image_uri=service.id.name,
                region=deployment_region.string_value,
                project_id=gcp_project_id.string_value,
                base_compute_role=nitric_roles.base_compute_role_output,
                artifact_registry_repository=stack.container_registry_uri_output,
            )

            services[service.id.name] = svc_resource

        buckets: dict[str, Storage] = {}
        # Deploy all buckets
        for bucket in all_buckets:
            buck_resource = Storage(
                self,
                bucket.id.name,
                stack_id=stack.stack_id_output,
                bucket_location=deployment_region.string_value,
                bucket_name=bucket.id.name,
                project_id=gcp_project_id.string_value,
            )

            buckets[bucket.id.name] = buck_resource

        secrets: dict[str, Secret] = {}

        # Deploy all secrets
        for secret in all_secrets:
            sec_resource = Secret(
                self,
                secret.id.name,
                stack_id=stack.stack_id_output,
                stack_name=stack.stack_name,
                secret_name=secret.id.name,
                project_id=gcp_project_id.string_value,
            )

            secrets[secret.id.name] = sec_resource

        queues: dict[str, Queue] = {}

        # Deploy all queues
        for queue in all_queues:
            queue_resource = Queue(
                self,
                id=queue.id.name, 
                queue_name=queue.id.name,
                project_id=gcp_project_id.string_value,
                stack_id=stack.stack_id_output  
            )

            queues[queue.id.name] = queue_resource

        # Deploy all APIs
        for api in all_apis:
            raw_spec = json.loads(convert_openapi_to_swagger(api.api.openapi))

            for path, methods in raw_spec["paths"].items():
                for method, details in methods.items():
                    if "x-nitric-target" in details:
                        target = details["x-nitric-target"]
                        target_service = services[target["name"]]

                        if target_service is None or target_service == "":
                            raise ValueError(
                                f"Could not find service: {target['name']} in API spec"
                            )

                        details["x-google-backend"] = {
                            # TODO: Translate
                            "address": f"{target_service.url_output}/x-nitric-api/{api.id.name}",
                            "path_translation": "APPEND_PATH_TO_ADDRESS",
                        }

            google_spec = json.dumps(raw_spec)

            Api(
                self,
                api.id.name,
                api_name=api.id.name,
                project_id=gcp_project_id.string_value,
                openapi_spec=google_spec,
                region=deployment_region.string_value,
                labels={"test": "test"},
            )

        # Deploy all policies
        for policy in all_policies:
            for principal in policy.policy.principals:
                if principal.id.type != ResourceType.Service:
                    raise ValueError(f"Principal type not supported: {principal.id.type}")
                
                service_account_email = services[principal.id.name].service_account_email_output
                
                for r in policy.policy.resources:
                    resource_name = ""
                    if r.id.type == ResourceType.Bucket:
                        resource_name = buckets[bucket.id.name].bucket_name_output
                    elif r.id.type == ResourceType.Secret:
                        resource_name = secrets[secret.id.name].secret_name_output
                    elif r.id.type == ResourceType.Queue:
                        resource_name = queues[queue.id.name].queue_name_output
                    elif r.id.type == ResourceType.KeyValueStore:
                        resource_name = r.id.name   
                    else:
                        raise ValueError(f"Resource type not supported: {r.id.type}-{r.id.name}")

                    named_actions = [Action(action).name for action in policy.policy.actions]

                    Policy(
                        self,
                        f"{principal.id.name}-{r.id.name}",
                        project_id=gcp_project_id.string_value,
                        resource_type=ResourceType(r.id.type).name,
                        resource_name=resource_name,
                        service_account_email=service_account_email,
                        actions=named_actions
                    )
