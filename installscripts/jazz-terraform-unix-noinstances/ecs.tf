resource "aws_iam_role_policy" "ecs_execution_policy" {
  count = "${var.dockerizedJenkins}"
  name = "${var.envPrefix}_ecs_execution_policy"
  role = "${aws_iam_role.ecs_execution_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "ecs_execution_role" {
  count = "${var.dockerizedJenkins}"
  name = "${var.envPrefix}_ecs_execution_role"

 assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_cloudwatch_log_group" "ecs_fargates_cwlogs" {
  count = "${var.dockerizedJenkins}"
  name = "${var.envPrefix}_ecs_log"
  retention_in_days = 7
}

# For new vpc, seucirty groups
resource "aws_security_group_rule" "codeq_sg" {
  count = "${var.dockerizedJenkins * var.autovpc}"
  type            = "ingress"
  from_port       = 9000
  to_port         = 9000
  protocol        = "tcp"
  self            = true
  security_group_id = "${aws_vpc.vpc_for_ecs.default_security_group_id}"
}
resource "aws_security_group_rule" "codeq_public" {
  count = "${var.dockerizedJenkins * var.autovpc}"
  type            = "ingress"
  from_port       = 9000
  to_port         = 9000
  protocol        = "tcp"
  cidr_blocks     = ["0.0.0.0/0"]
  security_group_id = "${aws_vpc.vpc_for_ecs.default_security_group_id}"
}
resource "aws_security_group_rule" "gitlab_sg" {
  count = "${var.dockerizedJenkins * var.autovpc}"
  type            = "ingress"
  from_port       = 80
  to_port         = 80
  protocol        = "tcp"
  self            = true
  security_group_id = "${aws_vpc.vpc_for_ecs.default_security_group_id}"
}
resource "aws_security_group_rule" "gitlab_public" {
  count = "${var.dockerizedJenkins * var.autovpc}"
  type            = "ingress"
  from_port       = 80
  to_port         = 80
  protocol        = "tcp"
  cidr_blocks     = ["0.0.0.0/0"]
  security_group_id = "${aws_vpc.vpc_for_ecs.default_security_group_id}"
}
resource "aws_security_group_rule" "jenkins_sg" {
  count = "${var.dockerizedJenkins * var.autovpc}"
  type            = "ingress"
  from_port       = 8080
  to_port         = 8080
  protocol        = "tcp"
  self            = true
  security_group_id = "${aws_vpc.vpc_for_ecs.default_security_group_id}"
}
resource "aws_security_group_rule" "jenkins_public" {
  count = "${var.dockerizedJenkins * var.autovpc}"
  type            = "ingress"
  from_port       = 8080
  to_port         = 8080
  protocol        = "tcp"
  cidr_blocks     = ["0.0.0.0/0"]
  security_group_id = "${aws_vpc.vpc_for_ecs.default_security_group_id}"
}


# For Existing VPC, update existing SG
resource "null_resource" "ecs_securitygroups" {
  count = "${var.dockerizedJenkins - var.autovpc}"
  provisioner "local-exec" {
    command    = "aws ec2 authorize-security-group-ingress --group-id ${var.existing_vpc_sg} --protocol tcp --port 80 --cidr '0.0.0.0/0' --region ${var.region}"
    on_failure = "continue"
  }
  provisioner "local-exec" {
    command    = "aws ec2 authorize-security-group-ingress --group-id ${var.existing_vpc_sg} --protocol tcp --port 80 --source-group ${var.existing_vpc_sg} --region ${var.region}"
    on_failure = "continue"
  }
  provisioner "local-exec" {
    command    = "aws ec2 authorize-security-group-ingress --group-id ${var.existing_vpc_sg} --protocol tcp --port 8080 --cidr '0.0.0.0/0' --region ${var.region}"
    on_failure = "continue"
  }
  provisioner "local-exec" {
    command    = "aws ec2 authorize-security-group-ingress --group-id ${var.existing_vpc_sg} --protocol tcp --port 8080 --source-group ${var.existing_vpc_sg} --region ${var.region}"
    on_failure = "continue"
  }
  provisioner "local-exec" {
    command    = "aws ec2 authorize-security-group-ingress --group-id ${var.existing_vpc_sg} --protocol tcp --port 9000 --cidr '0.0.0.0/0' --region ${var.region}"
    on_failure = "continue"
  }
  provisioner "local-exec" {
    command    = "aws ec2 authorize-security-group-ingress --group-id ${var.existing_vpc_sg} --protocol tcp --port 9000 --source-group ${var.existing_vpc_sg} --region ${var.region}"
    on_failure = "continue"
  }
}

resource "aws_ecs_cluster" "ecs_cluster" {
  count = "${var.dockerizedJenkins}"
  name = "${var.envPrefix}_ecs_cluster"
}

resource "aws_ecs_cluster" "ecs_cluster_gitlab" {
  count = "${var.scmgitlab}"
  name = "${var.envPrefix}_ecs_cluster_gitlab"
}

resource "aws_ecs_cluster" "ecs_cluster_codeq" {
  count = "${var.dockerizedSonarqube}"
  name = "${var.envPrefix}_ecs_cluster_codeq"
}

data "template_file" "ecs_task" {
  template = "${file("${path.module}/ecs_jenkins_task_definition.json")}"

  vars {
    image           = "${var.jenkins_docker_image}"
    ecs_container_name = "${var.envPrefix}_ecs_container"
    log_group       = "${aws_cloudwatch_log_group.ecs_fargates_cwlogs.name}"
    prefix_name     = "${var.envPrefix}_ecs_task_definition"
    region          = "${var.region}"
    jenkins_user    = "${lookup(var.jenkinsservermap, "jenkinsuser")}"
    jenkins_passwd    = "${lookup(var.jenkinsservermap, "jenkinspasswd")}"
  }
}

data "template_file" "ecs_task_gitlab" {
  template = "${file("${path.module}/ecs_gitlab_task_definition.json")}"

  vars {
    image           = "${var.gitlab_docker_image}"
    ecs_container_name = "${var.envPrefix}_ecs_container_gitlab"
    log_group       = "${aws_cloudwatch_log_group.ecs_fargates_cwlogs.name}"
    prefix_name     = "${var.envPrefix}_ecs_task_definition_gitlab"
    region          = "${var.region}"
    gitlab_passwd    = "${var.cognito_pool_password}"
  }
}

data "template_file" "ecs_task_codeq" {
  template = "${file("${path.module}/ecs_codeq_task_definition.json")}"

  vars {
    image           = "${var.codeq_docker_image}"
    ecs_container_name = "${var.envPrefix}_ecs_container_codeq"
    log_group       = "${aws_cloudwatch_log_group.ecs_fargates_cwlogs.name}"
    prefix_name     = "${var.envPrefix}_ecs_task_definition_codeq"
    region          = "${var.region}"
    gitlab_passwd    = "${var.cognito_pool_password}"
  }
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  count = "${var.dockerizedJenkins}"
  family                   = "${var.envPrefix}_ecs_task_definition"
  container_definitions    = "${data.template_file.ecs_task.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "${var.ecsJenkinscpu}"
  memory                   = "${var.ecsJenkinsmemory}"
  execution_role_arn       = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn            = "${aws_iam_role.ecs_execution_role.arn}"
}

resource "aws_ecs_task_definition" "ecs_task_definition_gitlab" {
  count = "${var.scmgitlab}"
  family                   = "${var.envPrefix}_ecs_task_definition_gitlab"
  container_definitions    = "${data.template_file.ecs_task_gitlab.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "${var.ecsGitlabcpu}"
  memory                   = "${var.ecsGitlabmemory}"
  execution_role_arn       = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn            = "${aws_iam_role.ecs_execution_role.arn}"
}

resource "aws_ecs_task_definition" "ecs_task_definition_codeq" {
  count = "${var.dockerizedSonarqube}"
  family                   = "${var.envPrefix}_ecs_task_definition_codeq"
  container_definitions    = "${data.template_file.ecs_task_codeq.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      =  "${var.ecsSonarqubecpu}"
  memory                   =  "${var.ecsSonarqubememory}"
  execution_role_arn       = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn            = "${aws_iam_role.ecs_execution_role.arn}"
}
# For new VPC
resource "aws_alb_target_group" "alb_target_group" {
  count = "${var.dockerizedJenkins * var.autovpc}"
  name     = "${var.envPrefix}-ecs-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.vpc_for_ecs.id}"
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path             = "/login"
    matcher          = "200"
    interval         = "60"
    timeout          = "59"
  }
}
# For existing VPC
resource "aws_alb_target_group" "alb_target_group_existing" {
  count = "${var.dockerizedJenkins - var.autovpc}"
  name     = "${var.envPrefix}-ecs-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.aws_vpc.existing_vpc.id}"
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path             = "/login"
    matcher          = "200"
    interval         = "60"
    timeout          = "59"
  }
}
# For new vpc
resource "aws_alb_target_group" "alb_target_group_gitlab" {
 count = "${var.dockerizedJenkins * var.autovpc * var.scmgitlab}"
  name     = "${var.envPrefix}-ecs-gitlab-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.vpc_for_ecs.id}"
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path             = "/users/sign_in"
    matcher          = "200"
    interval         = "60"
    timeout          = "59"
  }
}

# For existing vpc
resource "aws_alb_target_group" "alb_target_group_gitlab_existing" {
 count = "${(var.dockerizedJenkins - var.autovpc) * var.scmgitlab}"
  name     = "${var.envPrefix}-ecs-gitlab-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.aws_vpc.existing_vpc.id}"
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path             = "/users/sign_in"
    matcher          = "200"
    interval         = "60"
    timeout          = "59"
  }
}

# For new vpc
resource "aws_alb_target_group" "alb_target_group_codeq" {
  count = "${var.dockerizedJenkins * var.autovpc * var.dockerizedSonarqube}"
  name     = "${var.envPrefix}-ecs-codeq-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.vpc_for_ecs.id}"
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path             = "/sessions/new"
    matcher          = "200"
    interval         = "60"
    timeout          = "59"
  }
}

# For existing vpc
resource "aws_alb_target_group" "alb_target_group_codeq_existing" {
  count = "${(var.dockerizedJenkins - var.autovpc) * var.dockerizedSonarqube}"
  name     = "${var.envPrefix}-ecs-codeq-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.aws_vpc.existing_vpc.id}"
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path             = "/sessions/new"
    matcher          = "200"
    interval         = "60"
    timeout          = "59"
  }
}
# For new vpc
resource "aws_lb" "alb_ecs" {
  count = "${var.autovpc * var.dockerizedJenkins}"
  name            = "${var.envPrefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_vpc.vpc_for_ecs.default_security_group_id}"]
  subnets            = ["${aws_subnet.subnet_for_ecs.*.id}"]

  tags {
    Name        = "${var.envPrefix}_alb"
  }
}
# For existing vpc
resource "aws_lb" "alb_ecs_existing" {
  count = "${var.dockerizedJenkins - var.autovpc}"
  name            = "${var.envPrefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${var.existing_vpc_sg}"]
  subnets            = ["${aws_subnet.subnet_for_ecs_existing.*.id}"]

  tags {
    Name        = "${var.envPrefix}_alb"
  }
}
# For new vpc
resource "aws_lb" "alb_ecs_gitlab" {
  count = "${var.autovpc * var.dockerizedJenkins * var.scmgitlab}"
  name            = "${var.envPrefix}-gitlab-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_vpc.vpc_for_ecs.default_security_group_id}"]
  subnets            = ["${aws_subnet.subnet_for_ecs.*.id}"]

  tags {
    Name        = "${var.envPrefix}_gitlab_alb"
  }
}
# For existing vpc
resource "aws_lb" "alb_ecs_gitlab_existing" {
  count = "${(var.dockerizedJenkins - var.autovpc) * var.scmgitlab}"
  name            = "${var.envPrefix}-gitlab-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${var.existing_vpc_sg}"]
  subnets            = ["${aws_subnet.subnet_for_ecs_existing.*.id}"]

  tags {
    Name        = "${var.envPrefix}_gitlab_alb"
  }
}
# For new vpc
resource "aws_lb" "alb_ecs_codeq" {
  count = "${var.autovpc * var.dockerizedJenkins * var.dockerizedSonarqube}"
  name            = "${var.envPrefix}-codeq-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_vpc.vpc_for_ecs.default_security_group_id}"]
  subnets            = ["${aws_subnet.subnet_for_ecs.*.id}"]

  tags {
    Name        = "${var.envPrefix}_codeq_alb"
  }
}
# For existing vpc
resource "aws_lb" "alb_ecs_codeq_existing" {
  count = "${(var.dockerizedJenkins - var.autovpc) * var.dockerizedSonarqube}"
  name            = "${var.envPrefix}-codeq-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${var.existing_vpc_sg}"]
  subnets            = ["${aws_subnet.subnet_for_ecs_existing.*.id}"]

  tags {
    Name        = "${var.envPrefix}_codeq_alb"
  }
}
# For new vpc
resource "aws_alb_listener" "ecs_alb_listener" {
  count = "${var.dockerizedJenkins * var.autovpc}"
  load_balancer_arn = "${aws_lb.alb_ecs.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
    type             = "forward"
  }
}
# For existing vpc
resource "aws_alb_listener" "ecs_alb_listener_existing" {
  count = "${var.dockerizedJenkins - var.autovpc}"
  load_balancer_arn = "${aws_lb.alb_ecs_existing.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group_existing.arn}"
    type             = "forward"
  }
}
# For new vpc
resource "aws_alb_listener" "ecs_alb_listener_gitlab" {
  count = "${var.dockerizedJenkins * var.autovpc * var.scmgitlab}"
  load_balancer_arn = "${aws_lb.alb_ecs_gitlab.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group_gitlab.arn}"
    type             = "forward"
  }
}
# For existing vpc
resource "aws_alb_listener" "ecs_alb_listener_gitlab_existing" {
  count = "${(var.dockerizedJenkins - var.autovpc) * var.scmgitlab}"
  load_balancer_arn = "${aws_lb.alb_ecs_gitlab_existing.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group_gitlab_existing.arn}"
    type             = "forward"
  }
}
# For new vpc
resource "aws_alb_listener" "ecs_alb_listener_codeq" {
  count = "${var.autovpc * var.dockerizedJenkins * var.dockerizedSonarqube}"
  load_balancer_arn = "${aws_lb.alb_ecs_codeq.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group_codeq.arn}"
    type             = "forward"
  }
}
# For existing vpc
resource "aws_alb_listener" "ecs_alb_listener_codeq_existing" {
  count = "${(var.dockerizedJenkins - var.autovpc) * var.dockerizedSonarqube}"
  load_balancer_arn = "${aws_lb.alb_ecs_codeq_existing.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group_codeq_existing.arn}"
    type             = "forward"
  }
}

data "aws_ecs_task_definition" "ecs_task_definition" {
  count = "${var.dockerizedJenkins}"
  task_definition = "${aws_ecs_task_definition.ecs_task_definition.family}"
}

data "aws_ecs_task_definition" "ecs_task_definition_gitlab" {
  count = "${var.scmgitlab}"
  task_definition = "${aws_ecs_task_definition.ecs_task_definition_gitlab.family}"
}

data "aws_ecs_task_definition" "ecs_task_definition_codeq" {
  count = "${var.dockerizedSonarqube}"
  task_definition = "${aws_ecs_task_definition.ecs_task_definition_codeq.family}"
}
# For new vpc
resource "aws_ecs_service" "ecs_service" {
  count = "${var.autovpc * var.dockerizedJenkins}"
  provisioner "local-exec" {
      command = "sleep 1m"
  }
  name            = "${var.envPrefix}_ecs_service"
  task_definition = "${aws_ecs_task_definition.ecs_task_definition.family}:${max("${aws_ecs_task_definition.ecs_task_definition.revision}", "${data.aws_ecs_task_definition.ecs_task_definition.revision}")}"
  desired_count   = 1
  launch_type     = "FARGATE"
  health_check_grace_period_seconds  = 3000
  cluster =       "${aws_ecs_cluster.ecs_cluster.id}"

  network_configuration {
    security_groups    = ["${aws_vpc.vpc_for_ecs.default_security_group_id}"]
    subnets            = ["${aws_subnet.subnet_for_ecs.*.id}"]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
    container_name   = "${var.envPrefix}_ecs_container"
    container_port   = "8080"
  }
  provisioner "local-exec" {
      command = "sleep 1m"
  }
  depends_on = ["aws_alb_target_group.alb_target_group", "aws_lb.alb_ecs"]
}
# For existing vpc
resource "aws_ecs_service" "ecs_service_existing" {
  count = "${var.dockerizedJenkins - var.autovpc}"
  provisioner "local-exec" {
      command = "sleep 1m"
  }
  name            = "${var.envPrefix}_ecs_service"
  task_definition = "${aws_ecs_task_definition.ecs_task_definition.family}:${max("${aws_ecs_task_definition.ecs_task_definition.revision}", "${data.aws_ecs_task_definition.ecs_task_definition.revision}")}"
  desired_count   = 1
  launch_type     = "FARGATE"
  health_check_grace_period_seconds  = 3000
  cluster =       "${aws_ecs_cluster.ecs_cluster.id}"

  network_configuration {
    security_groups    = ["${var.existing_vpc_sg}"]
    subnets            = ["${aws_subnet.subnet_for_ecs_existing.*.id}"]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group_existing.arn}"
    container_name   = "${var.envPrefix}_ecs_container"
    container_port   = "8080"
  }
  provisioner "local-exec" {
      command = "sleep 1m"
  }
  depends_on = ["aws_alb_target_group.alb_target_group_existing", "aws_lb.alb_ecs_existing"]
}
# For new vpc
resource "aws_ecs_service" "ecs_service_gitlab" {
  count = "${var.autovpc * var.dockerizedJenkins * var.scmgitlab}"
  provisioner "local-exec" {
      command = "sleep 1m"
  }
  name            = "${var.envPrefix}_ecs_service_gitlab"
  task_definition = "${aws_ecs_task_definition.ecs_task_definition_gitlab.family}:${max("${aws_ecs_task_definition.ecs_task_definition_gitlab.revision}", "${data.aws_ecs_task_definition.ecs_task_definition_gitlab.revision}")}"
  desired_count   = 1
  launch_type     = "FARGATE"
  health_check_grace_period_seconds  = 3000
  cluster =       "${aws_ecs_cluster.ecs_cluster_gitlab.id}"

  network_configuration {
    security_groups    = ["${aws_vpc.vpc_for_ecs.default_security_group_id}"]
    subnets            = ["${aws_subnet.subnet_for_ecs.*.id}"]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group_gitlab.arn}"
    container_name   = "${var.envPrefix}_ecs_container_gitlab"
    container_port   = "80"
  }
  provisioner "local-exec" {
      command = "sleep 4m"
  }
  depends_on = ["aws_alb_target_group.alb_target_group_gitlab", "aws_lb.alb_ecs_gitlab"]
}
# For existing vpc
resource "aws_ecs_service" "ecs_service_gitlab_existing" {
  count = "${(var.dockerizedJenkins - var.autovpc) * var.scmgitlab}"
  provisioner "local-exec" {
      command = "sleep 1m"
  }
  name            = "${var.envPrefix}_ecs_service_gitlab"
  task_definition = "${aws_ecs_task_definition.ecs_task_definition_gitlab.family}:${max("${aws_ecs_task_definition.ecs_task_definition_gitlab.revision}", "${data.aws_ecs_task_definition.ecs_task_definition_gitlab.revision}")}"
  desired_count   = 1
  launch_type     = "FARGATE"
  health_check_grace_period_seconds  = 3000
  cluster =       "${aws_ecs_cluster.ecs_cluster_gitlab.id}"

  network_configuration {
    security_groups    = ["${var.existing_vpc_sg}"]
    subnets            = ["${aws_subnet.subnet_for_ecs_existing.*.id}"]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group_gitlab_existing.arn}"
    container_name   = "${var.envPrefix}_ecs_container_gitlab"
    container_port   = "80"
  }
  provisioner "local-exec" {
      command = "sleep 4m"
  }
  depends_on = ["aws_alb_target_group.alb_target_group_gitlab_existing", "aws_lb.alb_ecs_gitlab_existing"]
}
# For new vpc
resource "aws_ecs_service" "ecs_service_codeq" {
  count = "${var.dockerizedJenkins * var.autovpc * var.dockerizedSonarqube}"
  provisioner "local-exec" {
      command = "sleep 1m"
  }
  name            = "${var.envPrefix}_ecs_service_codeq"
  task_definition = "${aws_ecs_task_definition.ecs_task_definition_codeq.family}:${max("${aws_ecs_task_definition.ecs_task_definition_codeq.revision}", "${data.aws_ecs_task_definition.ecs_task_definition_codeq.revision}")}"
  desired_count   = 1
  launch_type     = "FARGATE"
  health_check_grace_period_seconds  = 3000
  cluster =       "${aws_ecs_cluster.ecs_cluster_codeq.id}"

  network_configuration {
    security_groups    = ["${aws_vpc.vpc_for_ecs.default_security_group_id}"]
    subnets            = ["${aws_subnet.subnet_for_ecs.*.id}"]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group_codeq.arn}"
    container_name   = "${var.envPrefix}_ecs_container_codeq"
    container_port   = "9000"
  }
  provisioner "local-exec" {
      command = "sleep 4m"
  }
  depends_on = ["aws_alb_target_group.alb_target_group_codeq", "aws_lb.alb_ecs_codeq"]
}
# For existing vpc
resource "aws_ecs_service" "ecs_service_codeq_existing" {
  count = "${(var.dockerizedJenkins - var.autovpc) * var.dockerizedSonarqube}"
  provisioner "local-exec" {
      command = "sleep 1m"
  }
  name            = "${var.envPrefix}_ecs_service_codeq"
  task_definition = "${aws_ecs_task_definition.ecs_task_definition_codeq.family}:${max("${aws_ecs_task_definition.ecs_task_definition_codeq.revision}", "${data.aws_ecs_task_definition.ecs_task_definition_codeq.revision}")}"
  desired_count   = 1
  launch_type     = "FARGATE"
  health_check_grace_period_seconds  = 3000
  cluster =       "${aws_ecs_cluster.ecs_cluster_codeq.id}"

  network_configuration {
    security_groups    = ["${var.existing_vpc_sg}"]
    subnets            = ["${aws_subnet.subnet_for_ecs_existing.*.id}"]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group_codeq_existing.arn}"
    container_name   = "${var.envPrefix}_ecs_container_codeq"
    container_port   = "9000"
  }
  provisioner "local-exec" {
      command = "sleep 4m"
  }
  depends_on = ["aws_alb_target_group.alb_target_group_codeq_existing", "aws_lb.alb_ecs_codeq_existing"]
}
