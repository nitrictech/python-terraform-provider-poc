from typing import AsyncIterator

from cdktf import TerraformStack, App, TerraformVariable
from constructs import Construct
from nitric.proto.deployments.v1 import (
    # DeploymentBase,
    DeploymentUpRequest,
    # DeploymentUpEvent,
    # DeploymentDownRequest,
    # DeploymentDownEvent
)
import docker
from docker.errors import APIError

from imports.cloudrun import Cloudrun
from imports.storage import Storage
from imports.api import Api


def source_image_cmd(source_image):
    """Get a source images command ready for wrapping"""
    if not source_image:
        raise ValueError(f"Could not inspect image: {source_image}")

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

    if entrypoint is None or cmd is None:
        raise ValueError(
            "Could not retrieve entrypoint or cmd from image config:" f" {source_image}"
        )

    cmd = entrypoint + cmd

    return cmd


class TerraformGoogleCloudStack(TerraformStack):
    """Terraform Google Cloud Stack"""

    def __init__(self, scope: Construct, id: str, req: DeploymentUpRequest):
        super().__init__(scope, id)

        # region: str = req.attributes.to_dict().get("region", "us-central1")
        # project_id: str = req.attributes.to_dict().get("gcp-project-id", None)
        resources = req.spec.resources

        services: dict[str, Cloudrun] = {}

        gcp_project_id = TerraformVariable(
            self,
            "gcpProjectId",
            type="string",
            description="Location of runtime to wrap images with",
        )

        runtime_uri = TerraformVariable(
            self,
            "runtimeUri",
            type="string",
            description="Location of runtime to wrap images with",
        )

        deployment_region = TerraformVariable(
            self,
            "region",
            type="string",
            description="What region should the stack be deployed to",
        )

        for resource in [r for r in resources if r.service is not None]:
            # Wrap the source image with the runtime
            cmd = source_image_cmd(resource.service.image.uri)
            svc_resource = Cloudrun(
                self,
                resource.id.name,
                service_name=resource.id.name,
                cmd=cmd,
                # FIXME: Need to make our own image and wrap with the runtime we want to use
                image_uri=resource.service.image.uri,
                region=deployment_region.string_value,
            )

            services[resource.id.name] = svc_resource

        for resource in [r for r in resources if r.bucket is not None]:
            Storage(
                self,
                resource.id.name,
                bucket_name=resource.id.name,
                bucket_location=deployment_region.string_value,
                project_id=gcp_project_id.string_value,
            )

        for resource in [r for r in resources if r.api is not None]:
            # Edit the API Spec to targer the deployed services
            Api(
                self,
                resource.id.name,
                api_name=resource.id.name,
                project_id=gcp_project_id.string_value,
                openapi_spec=resource.api.openapi,
                region=deployment_region.string_value,
                labels={"test": "test"},
            )
