import json
from typing import AsyncIterator
import os
from cdktf import App
from .stack import TerraformGoogleCloudStack
from nitric.utils import dict_from_struct
from betterproto.lib.google.protobuf import Struct, Value
from nitric.proto.deployments.v1 import (
    DeploymentBase,
    DeploymentUpRequest,
    DeploymentUpEvent,
    DeploymentDownRequest,
    DeploymentDownEvent,
)


# def value_to_pyvalue(value: Value):
#     if value.is_set("struct_value"):
#         return struct_to_pydict(value.struct_value)
#     elif value.is_set("list_value"):
#         return [value_to_pyvalue(v) for v in value.list_value.values]
#     elif value.is_set("string_value"):
#         return value.string_value
#     elif value.is_set("number_value"):
#         return value.number_value
#     elif value.is_set("bool_value"):
#         return value.bool_value
#     elif value.is_set("null_value"):
#         return None
#     else:
#         raise ValueError(f"Unknown value type: {value}")


# def struct_to_pydict(struct: Struct):
#     new_dict = {}

#     for key, value in struct.fields.items():
#         new_dict[key] = value_to_pyvalue(value)

#     return new_dict


workspace = os.getenv("WORKSPACE", ".")


class DeploymentService(DeploymentBase):
    """Deployment Service implementation"""

    async def up(
        self, deployment_up_request: DeploymentUpRequest
    ) -> AsyncIterator[DeploymentUpEvent]:
        # Start the tf cdk deployment
        # The end result will be the synthesis of a terraform application
        # This will be a json output, but HCL output is also possible if required
        yield DeploymentUpEvent(message="Starting CDKTF Deployment")

        attributes = dict_from_struct(deployment_up_request.attributes)

        enable_hcl = attributes.get("hcl", False)
        # output = attributes.get("output", 'output')

        # /workspace == nitric CWD
        app = App(
            hcl_output=enable_hcl,
            outdir="/workspace/output",
            context={"cdktfRelativeModules": ["./modules"]},
        )
        TerraformGoogleCloudStack(app, "stack", deployment_up_request)

        yield DeploymentUpEvent(message="Outputting results to {output}")

        app.synth()

    async def down(
        self, deployment_down_request: DeploymentDownRequest
    ) -> AsyncIterator[DeploymentDownEvent]:
        # This is technically a no-op unless we want to interactively being tearing down the
        # stack based on the current tfstate
        # This can be done by simply spawning the terraform CLI against the current terraform project
        yield DeploymentDownEvent(
            message="Run terraform destroy to tear down the stack"
        )
