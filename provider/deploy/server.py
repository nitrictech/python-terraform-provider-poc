from typing import AsyncIterator

from cdktf import App
from .stack import TerraformGoogleCloudStack
from nitric.proto.deployments.v1 import (
    DeploymentBase,
    DeploymentUpRequest,
    DeploymentUpEvent,
    DeploymentDownRequest,
    DeploymentDownEvent,
)


class DeploymentService(DeploymentBase):
    """Deployment Service implementation"""

    async def up(
        self, deployment_up_request: DeploymentUpRequest
    ) -> AsyncIterator[DeploymentUpEvent]:
        # Start the tf cdk deployment
        # The end result will be the synthesis of a terraform application
        # This will be a json output, but HCL output is also possible if required
        yield DeploymentUpEvent(message="Starting TDCDK Deployment")

        yield DeploymentUpEvent(message="Outputting results")

        app = App(hcl_output=True)
        TerraformGoogleCloudStack(app, "stack", deployment_up_request)

        app.synth()

    async def down(
        self, deployment_down_request: DeploymentDownRequest
    ) -> AsyncIterator[DeploymentDownEvent]:
        # This is technically a no-op unless we want to interactively being tearing down the
        # stack based on the current tfstate
        # This can be done by simply spawning the terraform CLI against the current terraform project
        yield DeploymentDownEvent(message="Run terraform destroy to tear down the stack")


