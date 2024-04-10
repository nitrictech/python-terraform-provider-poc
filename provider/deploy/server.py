from typing import AsyncIterator

import grpclib
from cdktf import TerraformStack, App
from constructs import Construct
from nitric.proto.deployments.v1 import DeploymentBase, DeploymentUpRequest, DeploymentUpEvent, DeploymentDownRequest, DeploymentDownEvent

class MyStack(TerraformStack):
    def __init__(self, scope: Construct, id: str):
        super().__init__(scope, id)

        # define resources here

class DeploymentService(DeploymentBase):
    async def up(
        self, deployment_up_request: DeploymentUpRequest
    ) -> AsyncIterator[DeploymentUpEvent]:
        # Start the tf cdk deployment
        # The end result will be the synthesis of a terraform application
        # This will be a json output, but templating HCL is also possible if required
        yield DeploymentDownEvent(message="Starting TDCDK Deployment")

        yield DeploymentDownEvent(message="Outputting results")

        app = App()
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
