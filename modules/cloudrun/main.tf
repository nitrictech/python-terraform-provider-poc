
# Write the Dockerfile to the file system
resource "null_resource" "copy_dockerfile" {
  provisioner "local-exec" {
    command = <<EOF
mkdir -p ${path.module}/build-${var.name}
echo -e "${var.dockerfile}" > ${path.module}/build-${var.name}/Dockerfile
EOF
  }
}

// A Google CloudRun resource
resource "google_cloud_run_service" "nitric_compute" {
  name     = var.name
  location = var.region

  template {
    spec {
      containers {
        image = var.image_uri
        command = [var.cmd]
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}




# copyDockerfile := null.NewResource(stack, jsii.String(name+"-docker-copy"), &null.ResourceConfig{
# 		// TODO: Add triggers for redeployment/caching
# 	})
# 	buildContext := fmt.Sprintf("%s/build-%s", os.TempDir(), name)
# 	copyDockerfileCmd := fmt.Sprintf("mkdir -p %s && echo -e \"%s\" > %s/Dockerfile", buildContext, dockerfile, buildContext)
# 	// Write the docker file to the file system
# 	copyDockerfile.AddOverride(jsii.String("provisioner.local-exec.command"), jsii.String(copyDockerfileCmd))