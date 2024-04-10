from typing import AsyncIterator

import grpclib
from cdktf import TerraformStack, App
from .stack import MyStack
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
        MyStack(app, "learn-cdktf")

        app.synth()

        raise grpclib.GRPCError(grpclib.const.Status.UNIMPLEMENTED)
        yield DeploymentUpEvent()

    async def down(
        self, deployment_down_request: DeploymentDownRequest
    ) -> AsyncIterator[DeploymentDownEvent]:
        # This is technically a no-op unless we want to interactively being tearing down the
        # stack based on the current tfstate
        # This can be done by simply spawning the terraform CLI against the current terraform project
        raise grpclib.GRPCError(grpclib.const.Status.UNIMPLEMENTED)
        yield DeploymentDownEvent()
