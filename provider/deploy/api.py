import subprocess


def convert_openapi_to_swagger(spec: str) -> str:
    """Assumes that the `api-spec-converter` (https://github.com/LucyBot-Inc/api-spec-converter) is installed."""

    temp_input = "/workspace/openapi.json"

    # Write the content to a file
    with open(temp_input, "w", encoding="utf8") as f:
        f.write(spec)

    # Run the command
    cmd = [
        "api-spec-converter",
        "--from=openapi_3",
        "--to=swagger_2",
        "--syntax=json",
        "--order=alpha",
        temp_input,
    ]
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate()

    if process.returncode != 0:
        raise ValueError(f"Failed to convert OpenAPI to Swagger: {str(stderr)}")

    return str(stdout, encoding="utf-8")
