import os
import shutil
import betterproto
from cdktf import TerraformStack, TerraformVariable
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

        # region: str = req.attributes.to_dict().get("region", "us-central1")
        # project_id: str = req.attributes.to_dict().get("gcp-project-id", None)
        resources = req.spec.resources

        services: dict[str, Cloudrun] = {}
        buckets: dict[str, Storage] = {}

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

        for resource in resources:
            resource_type, _ = betterproto.which_one_of(resource, "config")

            # print(f">Creating resource: {resource_type}<")

            if resource_type == "service":
                # Wrap the source image with the runtime
                cmd = source_image_cmd(resource.service.image.uri)

                create_provider_runtime_image(
                    resource.service.image.uri, resource.id.name
                )

                svc_resource = Cloudrun(
                    self,
                    resource.id.name,
                    service_name=resource.id.name,
                    cmd=" ".join(cmd),
                    image_uri=resource.id.name,
                    region=deployment_region.string_value,
                    project_id=gcp_project_id.string_value,
                )

                services[resource.id.name] = svc_resource

            if resource_type == "bucket":
                buck_resource = Storage(
                    self,
                    resource.id.name,
                    bucket_location=deployment_region.string_value,
                    bucket_name=resource.id.name,
                    project_id=gcp_project_id.string_value,
                )

                buckets[resource.id.name] = buck_resource

            if resource_type == "api":
                pass

        # for resource in [r for r in resources if r.bucket is not None]:
        #     Storage(
        #         self,
        #         resource.id.name,
        #         bucket_name=resource.id.name,
        #         bucket_location=deployment_region.string_value,
        #         project_id=gcp_project_id.string_value,
        #     )

        # for resource in [r for r in resources if r.api is not None]:
        #     # Edit the API Spec to targer the deployed services
        #     Api(
        #         self,
        #         resource.id.name,
        #         api_name=resource.id.name,
        #         project_id=gcp_project_id.string_value,
        #         openapi_spec=resource.api.openapi,
        #         region=deployment_region.string_value,
        #         labels={"test": "test"},
        #     )
