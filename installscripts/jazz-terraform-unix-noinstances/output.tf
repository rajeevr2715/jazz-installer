#
# This resource will add necessary setting needed for the user into stack_details.json
#

resource "null_resource" "outputVariables" {
  provisioner "local-exec" {
    command = "touch stack_details.json"
  }
  provisioner "local-exec" {
       command = <<EOF
                 echo { > stack_details.json
                 EOF
   }
}

resource "null_resource" "outputVariables_jenkins" {
  depends_on = ["null_resource.outputVariables"]
  count = "${1 - var.dockerizedJenkins}"
  provisioner "local-exec" {
       command = <<EOF
                 echo \""Jenkins ELB\"" : \""http://${lookup(var.jenkinsservermap, "jenkins_elb")}\"", >> stack_details.json
                 EOF
   }
}
# For new vpc
resource "null_resource" "outputVariables_jenkins_container" {
  depends_on = ["null_resource.outputVariables"]
  count = "${var.autovpc * var.dockerizedJenkins}"
  provisioner "local-exec" {
       command = <<EOF
                 echo \""Jenkins ELB\"" : \""http://${aws_lb.alb_ecs.dns_name}\"", >> stack_details.json
                 EOF
   }
}
# For existing vpc
resource "null_resource" "outputVariables_jenkins_container_existing" {
  depends_on = ["null_resource.outputVariables"]
  count = "${var.dockerizedJenkins - var.autovpc}"
  provisioner "local-exec" {
       command = <<EOF
                 echo \""Jenkins ELB\"" : \""http://${aws_lb.alb_ecs_existing.dns_name}\"", >> stack_details.json
                 EOF
   }
}

resource "null_resource" "outputVariables_default" {
  depends_on = ["null_resource.outputVariables_jenkins", "null_resource.outputVariables_jenkins_container", "null_resource.outputVariables_jenkins_container_existing"]
  provisioner "local-exec" {
       command = <<EOF
                 echo \""Jenkins Username\"" : \""${lookup(var.jenkinsservermap, "jenkinsuser")}\"",  >> stack_details.json
                 echo \""Jenkins Password\"" : \""${lookup(var.jenkinsservermap, "jenkinspasswd")}\"",  >> stack_details.json
                 echo \""Jazz Home\"" : \""http://${aws_cloudfront_distribution.jazz.domain_name}\"",  >> stack_details.json
                 echo \""Jazz Admin Username\"" : \""${var.cognito_pool_username}\"",  >> stack_details.json
                 echo \""Jazz Admin Password\"" : \""${var.cognito_pool_password}\"",  >> stack_details.json
                 echo \""Region\"" : \""${var.region}\"",  >> stack_details.json
                 echo \""Jazz API Endpoint\"" : \""https://${aws_api_gateway_rest_api.jazz-prod.id}.execute-api.${var.region}.amazonaws.com/prod\"",  >> stack_details.json
                 EOF
   }
}

resource "null_resource" "outputVariablesSonar" {
  count = "${1 - var.dockerizedSonarqube}"
  depends_on = ["null_resource.outputVariables_default"]

  provisioner "local-exec" {
    command = <<EOF
              echo \""Sonar Home\"" : \""http://${lookup(var.codeqmap, "sonar_server_elb")}\"",  >> stack_details.json
              echo \""Sonar Username\"" : \""${lookup(var.codeqmap, "sonar_username")}\"",   >> stack_details.json
              echo \""Sonar Password\"" : \""${lookup(var.codeqmap, "sonar_passwd")}\"",  >> stack_details.json
              EOF
  }
}
# For new vpc
resource "null_resource" "outputVariablesSonar_dockerized" {
  count = "${var.autovpc * var.dockerizedSonarqube}"
  depends_on = ["null_resource.outputVariables_default"]

  provisioner "local-exec" {
    command = <<EOF
              echo \""Sonar Home\"" : \""http://${aws_lb.alb_ecs_codeq.dns_name}\"",  >> stack_details.json
              echo \""Sonar Username\"" : \""${lookup(var.codeqmap, "sonar_username")}\"",   >> stack_details.json
              echo \""Sonar Password\"" : \""${lookup(var.codeqmap, "sonar_passwd")}\"",  >> stack_details.json
              EOF
  }
}
# For existing vpc
resource "null_resource" "outputVariablesSonar_dockerized_existing" {
  count = "${var.dockerizedSonarqube - var.autovpc}"
  depends_on = ["null_resource.outputVariables_default"]

  provisioner "local-exec" {
    command = <<EOF
              echo \""Sonar Home\"" : \""http://${aws_lb.alb_ecs_codeq_existing.dns_name}\"",  >> stack_details.json
              echo \""Sonar Username\"" : \""${lookup(var.codeqmap, "sonar_username")}\"",   >> stack_details.json
              echo \""Sonar Password\"" : \""${lookup(var.codeqmap, "sonar_passwd")}\"",  >> stack_details.json
              EOF
  }
}

resource "null_resource" "outputVariablesBB" {
  depends_on = ["null_resource.outputVariables_default"]
  count = "${var.scmbb}"

  provisioner "local-exec" {
    command = <<EOF
              echo \""Bitbucket ELB\"" : \""http://${lookup(var.scmmap, "scm_elb")}\"",  >> stack_details.json
              echo \""Bitbucket Username\"" : \""${lookup(var.scmmap, "scm_username")}\"",   >> stack_details.json
              echo \""Bitbucket Password\"" : \""${lookup(var.scmmap, "scm_passwd")}\""  >> stack_details.json
              echo } >> stack_details.json
              EOF
  }
}
# For new vpc
resource "null_resource" "outputVariablesGitlab" {
  depends_on = ["null_resource.outputVariables_default", "null_resource.outputVariablesSonar_dockerized"]
  count = "${var.autovpc * var.scmgitlab}"

  provisioner "local-exec" {
    command = <<EOF
              echo \""Gitlab Home\"" : \""http://${aws_lb.alb_ecs_gitlab.dns_name}\"",  >> stack_details.json
              echo \""Gitlab Username\"" : \""${lookup(var.scmmap, "scm_username")}\"",   >> stack_details.json
              echo \""Gitlab Password\"" : \""${lookup(var.scmmap, "scm_passwd")}\""  >> stack_details.json
              echo } >> stack_details.json
              EOF
  }
}
# For existing vpc
resource "null_resource" "outputVariablesGitlab_existing" {
  depends_on = ["null_resource.outputVariables_default", "null_resource.outputVariablesSonar_dockerized_existing"]
  count = "${(var.dockerizedJenkins - var.autovpc ) * var.scmgitlab}"

  provisioner "local-exec" {
    command = <<EOF
              echo \""Gitlab Home\"" : \""http://${aws_lb.alb_ecs_gitlab_existing.dns_name}\"",  >> stack_details.json
              echo \""Gitlab Username\"" : \""${lookup(var.scmmap, "scm_username")}\"",   >> stack_details.json
              echo \""Gitlab Password\"" : \""${lookup(var.scmmap, "scm_passwd")}\""  >> stack_details.json
              echo } >> stack_details.json
              EOF
  }
}
