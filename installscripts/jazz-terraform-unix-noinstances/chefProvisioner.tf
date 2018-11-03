resource "null_resource" "preJenkinsConfiguration" {
  #TODO verify s3 dependency is valid
  depends_on = ["aws_s3_bucket.jazz-web", "null_resource.update_jenkins_configs"]

  # Update git branch and repo in jenkins cookbook
  provisioner "local-exec" {
    command = "sed -i 's|default\\['\\''git_branch'\\''\\].*.|default\\['\\''git_branch'\\''\\]='\\''${var.github_branch}'\\''|g' ${var.jenkinsattribsfile}"
  }

  provisioner "local-exec" {
    command = "sed -i 's|default\\['\\''git_repo'\\''\\].*.|default\\['\\''git_repo'\\''\\]='\\''${var.github_repo}'\\''|g' ${var.jenkinsattribsfile}"
  }

  # Update AWS credentials in Jenkins Chef cookbook attributes
  provisioner "local-exec" {
    command = "sed -i 's|default\\['\\''aws_access_key'\\''\\].*.|default\\['\\''aws_access_key'\\''\\]='\\''${aws_iam_access_key.operational_key.id}'\\''|g' ${var.jenkinsattribsfile}"
  }

  provisioner "local-exec" {
    command = "sed -i 's|default\\['\\''aws_secret_key'\\''\\].*.|default\\['\\''aws_secret_key'\\''\\]='\\''${aws_iam_access_key.operational_key.secret}'\\''|g' ${var.jenkinsattribsfile}"
  }

  # Update cognito attribs in Jenkins Chef cookbook attributes
  provisioner "local-exec" {
    command = "sed -i 's|default\\['\\''cognitouser'\\''\\].*.|default\\['\\''cognitouser'\\''\\]='\\''${var.cognito_pool_username}'\\''|g' ${var.jenkinsattribsfile}"
  }

  provisioner "local-exec" {
    command = "sed -i 's|default\\['\\''cognitopassword'\\''\\].*.|default\\['\\''cognitopassword'\\''\\]='\\''${var.cognito_pool_password}'\\''|g' ${var.jenkinsattribsfile}"
  }

  #Update Gitlab attribs in Jenkins Chef cookbook attributes
  provisioner "local-exec" {
    command = "sed -i 's|default\\['\\''gitlabuser'\\''\\].*.|default\\['\\''gitlabuser'\\''\\]='\\''${lookup(var.scmmap, "scm_username")}'\\''|g' ${var.jenkinsattribsfile}"
  }

  provisioner "local-exec" {
    command = "sed -i 's|default\\['\\''gitlabpassword'\\''\\].*.|default\\['\\''gitlabpassword'\\''\\]='\\''${lookup(var.scmmap, "scm_passwd")}'\\''|g' ${var.jenkinsattribsfile}"
  }

  #Update Jenkins attribs in Jenkins Chef cookbook attributes
  provisioner "local-exec" {
    command = "sed -i 's|default\\['\\''bbuser'\\''\\].*.|default\\['\\''bbuser'\\''\\]='\\''${lookup(var.scmmap, "scm_username")}'\\''|g' ${var.jenkinsattribsfile}"
  }

  provisioner "local-exec" {
    command = "sed -i 's|default\\['\\''bbpassword'\\''\\].*.|default\\['\\''bbpassword'\\''\\]='\\''${lookup(var.scmmap, "scm_passwd")}'\\''|g' ${var.jenkinsattribsfile}"
  }

  provisioner "local-exec" {
    command = "sed -i 's|default\\['\\''sonaruser'\\''\\].*.|default\\['\\''sonaruser'\\''\\]='\\''${lookup(var.codeqmap, "sonar_username")}'\\''|g' ${var.jenkinsattribsfile}"
  }

  provisioner "local-exec" {
    command = "sed -i 's|default\\['\\''sonarpassword'\\''\\].*.|default\\['\\''sonarpassword'\\''\\]='\\''${lookup(var.codeqmap, "sonar_passwd")}'\\''|g' ${var.jenkinsattribsfile}"
  }

  provisioner "local-exec" {
    command = "sed -i 's|jenkinsuser:jenkinspasswd|${lookup(var.jenkinsservermap, "jenkinsuser")}:${lookup(var.jenkinsservermap, "jenkinspasswd")}|g' ${var.cookbooksSourceDir}/jenkins/files/default/authfile"
  }

  #END chef cookbook edits
}

resource "null_resource" "configureJenkinsInstance" {
  count = "${1-var.dockerizedJenkins}"
  depends_on = ["null_resource.preJenkinsConfiguration", "aws_s3_bucket.jazz-web", "null_resource.update_jenkins_configs"]

  connection {
    host = "${lookup(var.jenkinsservermap, "jenkins_public_ip")}"
    user = "${lookup(var.jenkinsservermap, "jenkins_ssh_login")}"
    port = "${lookup(var.jenkinsservermap, "jenkins_ssh_port")}"
    type = "ssh"
    private_key = "${file("${lookup(var.jenkinsservermap, "jenkins_ssh_key")}")}"
  }

  #Note that because the Terraform SSH connector is weird, we must manually create this directory
  #on the remote machine here *before* we copy things to it.
  provisioner "remote-exec" {
    inline = "mkdir -p ${var.chefDestDir}"
  }

  #Copy the chef playbooks and jenkins binary plugin blobs over to the remote Jenkins server
  provisioner "file" {
    source      = "${var.jenkinsPluginsSourceDir}"
    destination = "${var.chefDestDir}/"
  }

  provisioner "file" {
    source      = "${var.cookbooksSourceDir}"
    destination = "${var.chefDestDir}/"
  }

  #TODO consider doing the export locally, so we only need to install `chef-client on the remote box`.
  provisioner "remote-exec" {
    inline = [
      "git clone ${var.contentRepo} --depth 1 ${var.chefDestDir}/jazz-content",
      "cp -r ${var.chefDestDir}/jazz-content/jenkins/files/. ${var.chefDestDir}/cookbooks/jenkins/files/default/",
      "sudo sh ${var.chefDestDir}/cookbooks/installChef.sh",
      "chef install ${var.chefDestDir}/cookbooks/Policyfile.rb",
      "chef export ${var.chefDestDir}/cookbooks/Policyfile.rb ${var.chefDestDir}/chef-export",
      "cd ${var.chefDestDir}/chef-export && sudo chef-client -z",
      "sudo rm -rf -f ${var.chefDestDir}"
    ]
  }
}
# For new vpc
data "external" "gitlabcontainer" {
  count = "${var.dockerizedJenkins * var.autovpc * var.scmgitlab}"
  program = ["bash", "${var.configureGitlab_cmd}"]

  query = {
    passwd = "${var.cognito_pool_password}"
    ip = "${aws_lb.alb_ecs_gitlab.dns_name}"
    gitlab_admin = "${lookup(var.scmmap, "scm_username")}"
  }
  depends_on = ["aws_ecs_service.ecs_service_gitlab"]
}
# For existing vpc
data "external" "gitlabcontainer_existing" {
  count = "${(var.dockerizedJenkins - var.autovpc) * var.scmgitlab}"
  program = ["bash", "${var.configureGitlab_cmd}"]

  query = {
    passwd = "${var.cognito_pool_password}"
    ip = "${aws_lb.alb_ecs_gitlab_existing.dns_name}"
    gitlab_admin = "${lookup(var.scmmap, "scm_username")}"
  }
  depends_on = ["aws_ecs_service.ecs_service_gitlab_existing"]
}
# For new vpc
resource "null_resource" "configureCodeqDocker" {
  count = "${var.dockerizedJenkins * var.autovpc * var.dockerizedSonarqube}"
  provisioner "local-exec" {
    command = "python ${var.configureCodeq_cmd} ${aws_lb.alb_ecs_codeq.dns_name} ${lookup(var.codeqmap, "sonar_passwd")}"
  }
  depends_on = ["aws_ecs_service.ecs_service_codeq"]
}
# For existing vpc
resource "null_resource" "configureCodeqDocker_existing" {
  count = "${(var.dockerizedJenkins - var.autovpc) * var.dockerizedSonarqube}"
  provisioner "local-exec" {
    command = "python ${var.configureCodeq_cmd} ${aws_lb.alb_ecs_codeq_existing.dns_name} ${lookup(var.codeqmap, "sonar_passwd")}"
  }
  depends_on = ["aws_ecs_service.ecs_service_codeq_existing"]
}

# For scenario1
resource "null_resource" "configureCliJenkins" {
  count = "${1 - var.dockerizedJenkins}"
  depends_on = ["null_resource.preJenkinsConfiguration", "null_resource.configureJenkinsInstance"]
  #Jenkins Cli process
  provisioner "local-exec" {
    command = "bash ${var.configureJenkinsCE_cmd} ${lookup(var.jenkinsservermap, "jenkins_elb")} ${var.cognito_pool_username} ${var.dockerizedJenkins} ${lookup(var.scmmap, "scm_elb")} ${lookup(var.scmmap, "scm_username")} ${lookup(var.scmmap, "scm_passwd")} ${lookup(var.scmmap, "scm_passwd")} ${lookup(var.jenkinsservermap, "jenkinspasswd")} ${lookup(var.scmmap, "scm_type")} ${lookup(var.codeqmap, "sonar_username")} ${lookup(var.codeqmap, "sonar_passwd")} ${aws_iam_access_key.operational_key.id} ${aws_iam_access_key.operational_key.secret} ${var.cognito_pool_password} ${lookup(var.jenkinsservermap, "jenkinsuser")}"
  }
}

# For scenario2 (Jenkins ALB)
# For new vpc
resource "null_resource" "configureCliJenkinsbb_dockerized" {
  count = "${var.autovpc * var.scmbb * var.dockerizedJenkins}"
  depends_on = ["null_resource.preJenkinsConfiguration"]
  #Jenkins Cli process
  provisioner "local-exec" {
    command = "bash ${var.configureJenkinsCE_cmd} ${aws_lb.alb_ecs.dns_name} ${var.cognito_pool_username} ${var.dockerizedJenkins} ${lookup(var.scmmap, "scm_elb")} ${lookup(var.scmmap, "scm_username")} ${lookup(var.scmmap, "scm_passwd")} ${lookup(var.scmmap, "scm_passwd")} ${lookup(var.jenkinsservermap, "jenkinspasswd")} ${lookup(var.scmmap, "scm_type")} ${lookup(var.codeqmap, "sonar_username")} ${lookup(var.codeqmap, "sonar_passwd")} ${aws_iam_access_key.operational_key.id} ${aws_iam_access_key.operational_key.secret} ${var.cognito_pool_password} ${lookup(var.jenkinsservermap, "jenkinsuser")}"
  }
}
# For existing vpc
resource "null_resource" "configureCliJenkinsbb_dockerized_existing" {
  count = "${(var.dockerizedJenkins - var.autovpc) * var.scmbb * var.dockerizedJenkins}"
  depends_on = ["null_resource.preJenkinsConfiguration"]
  #Jenkins Cli process
  provisioner "local-exec" {
    command = "bash ${var.configureJenkinsCE_cmd} ${aws_lb.alb_ecs_existing.dns_name} ${var.cognito_pool_username} ${var.dockerizedJenkins} ${lookup(var.scmmap, "scm_elb")} ${lookup(var.scmmap, "scm_username")} ${lookup(var.scmmap, "scm_passwd")} ${lookup(var.scmmap, "scm_passwd")} ${lookup(var.jenkinsservermap, "jenkinspasswd")} ${lookup(var.scmmap, "scm_type")} ${lookup(var.codeqmap, "sonar_username")} ${lookup(var.codeqmap, "sonar_passwd")} ${aws_iam_access_key.operational_key.id} ${aws_iam_access_key.operational_key.secret} ${var.cognito_pool_password} ${lookup(var.jenkinsservermap, "jenkinsuser")}"
  }
}

# For scenario3 (Jenkins and Gitlab ALB)
# For new vpc
resource "null_resource" "configureCliJenkins_dockerized" {
  count = "${var.autovpc * var.scmgitlab * var.dockerizedJenkins}"
  depends_on = ["null_resource.preJenkinsConfiguration"]
  #Jenkins Cli process
  provisioner "local-exec" {
    command = "bash ${var.configureJenkinsCE_cmd} ${aws_lb.alb_ecs.dns_name} ${var.cognito_pool_username} ${var.dockerizedJenkins} ${aws_lb.alb_ecs_gitlab.dns_name} ${lookup(var.scmmap, "scm_username")} ${lookup(var.scmmap, "scm_passwd")} ${data.external.gitlabcontainer.result.token} ${lookup(var.jenkinsservermap, "jenkinspasswd")} ${lookup(var.scmmap, "scm_type")} ${lookup(var.codeqmap, "sonar_username")} ${lookup(var.codeqmap, "sonar_passwd")} ${aws_iam_access_key.operational_key.id} ${aws_iam_access_key.operational_key.secret} ${var.cognito_pool_password} ${lookup(var.jenkinsservermap, "jenkinsuser")}"
  }
}
# For existing vpc
resource "null_resource" "configureCliJenkins_dockerized_existing" {
  count = "${(var.dockerizedJenkins - var.autovpc) * var.scmgitlab * var.dockerizedJenkins}"
  depends_on = ["null_resource.preJenkinsConfiguration"]
  #Jenkins Cli process
  provisioner "local-exec" {
    command = "bash ${var.configureJenkinsCE_cmd} ${aws_lb.alb_ecs_existing.dns_name} ${var.cognito_pool_username} ${var.dockerizedJenkins} ${aws_lb.alb_ecs_gitlab_existing.dns_name} ${lookup(var.scmmap, "scm_username")} ${lookup(var.scmmap, "scm_passwd")} ${data.external.gitlabcontainer_existing.result.token} ${lookup(var.jenkinsservermap, "jenkinspasswd")} ${lookup(var.scmmap, "scm_type")} ${lookup(var.codeqmap, "sonar_username")} ${lookup(var.codeqmap, "sonar_passwd")} ${aws_iam_access_key.operational_key.id} ${aws_iam_access_key.operational_key.secret} ${var.cognito_pool_password} ${lookup(var.jenkinsservermap, "jenkinsuser")}"
  }
}

resource "null_resource" "postJenkinsConfiguration" {
  depends_on = ["null_resource.configureCliJenkins", "null_resource.configureCliJenkinsbb_dockerized", "null_resource.configureCliJenkinsbb_dockerized_existing", "null_resource.configureCliJenkins_dockerized", "null_resource.configureCliJenkins_dockerized_existing"]
  provisioner "local-exec" {
    command = "${var.modifyCodebase_cmd}  ${lookup(var.jenkinsservermap, "jenkins_security_group")} ${lookup(var.jenkinsservermap, "jenkins_subnet")} ${aws_iam_role.lambda_role.arn} ${var.region} ${var.envPrefix} ${var.cognito_pool_username}"
  }
}

# For bitbucket
resource "null_resource" "injectingBootstrapToJenkins" {
  count = "${1-var.scmgitlab}"
  depends_on = ["null_resource.postJenkinsConfiguration"]
  // Injecting bootstrap variables into Jazz-core Jenkinsfiles*
  provisioner "local-exec" {
    command = "${var.injectingBootstrapToJenkinsfiles_cmd} ${lookup(var.scmmap, "scm_elb")} ${lookup(var.scmmap, "scm_type")}"
  }
}

# For Gitlab
# For new vpc
resource "null_resource" "injectingBootstrapToJenkins_gitlab" {
  count = "${var.autovpc * var.scmgitlab}"
  depends_on = ["null_resource.postJenkinsConfiguration"]
  // Injecting bootstrap variables into Jazz-core Jenkinsfiles*
  provisioner "local-exec" {
    command = "${var.injectingBootstrapToJenkinsfiles_cmd} ${aws_lb.alb_ecs_gitlab.dns_name} ${lookup(var.scmmap, "scm_type")}"
  }
}
# For existing vpc
resource "null_resource" "injectingBootstrapToJenkins_gitlab_existing" {
  count = "${(var.dockerizedJenkins - var.autovpc) * var.scmgitlab}"
  depends_on = ["null_resource.postJenkinsConfiguration"]
  // Injecting bootstrap variables into Jazz-core Jenkinsfiles*
  provisioner "local-exec" {
    command = "${var.injectingBootstrapToJenkinsfiles_cmd} ${aws_lb.alb_ecs_gitlab_existing.dns_name} ${lookup(var.scmmap, "scm_type")}"
  }
}
