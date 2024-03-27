locals {
  # Healthchecks
  healthchecks_url = "https://${try(coalesce(
    try(var.healthchecks.fqdn, module.alb.route53_records["A"].fqdn, null),
    module.alb.dns_name,
  ), "")}"

  healthchecks_port = try(var.healthchecks.port, 8000)
}

################################################################################
# ALB
################################################################################

locals {
  route53_records = {
    A = {
      name    = try(coalesce(var.route53_record_name, var.name), "")
      type    = "A"
      zone_id = var.route53_zone_id
    }
    AAAA = {
      name    = try(coalesce(var.route53_record_name, var.name), "")
      type    = "AAAA"
      zone_id = var.route53_zone_id
    }
  }
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.1.0"

  create = var.create && var.create_alb

  # Load balancer
  access_logs                                 = lookup(var.alb, "access_logs", {})
  customer_owned_ipv4_pool                    = try(var.alb.customer_owned_ipv4_pool, null)
  desync_mitigation_mode                      = try(var.alb.desync_mitigation_mode, null)
  dns_record_client_routing_policy            = try(var.alb.dns_record_client_routing_policy, null)
  drop_invalid_header_fields                  = try(var.alb.drop_invalid_header_fields, true)
  enable_cross_zone_load_balancing            = try(var.alb.enable_cross_zone_load_balancing, true)
  enable_deletion_protection                  = try(var.alb.enable_deletion_protection, true)
  enable_http2                                = try(var.alb.enable_http2, null)
  enable_tls_version_and_cipher_suite_headers = try(var.alb.enable_tls_version_and_cipher_suite_headers, null)
  enable_waf_fail_open                        = try(var.alb.enable_waf_fail_open, null)
  enable_xff_client_port                      = try(var.alb.enable_xff_client_port, null)
  idle_timeout                                = try(var.alb.idle_timeout, null)
  internal                                    = try(var.alb.internal, var.alb_internal)
  ip_address_type                             = try(var.alb.ip_address_type, null)
  load_balancer_type                          = try(var.alb.load_balancer_type, "application")
  name                                        = try(var.alb.name, var.name)
  preserve_host_header                        = try(var.alb.preserve_host_header, null)
  security_groups                             = try(var.alb.security_groups, [])
  subnets                                     = try(var.alb.subnets, var.alb_subnets)
  xff_header_processing_mode                  = try(var.alb.xff_header_processing_mode, null)
  timeouts                                    = try(var.alb.timeouts, {})

  # Listener(s)
  default_port     = try(var.alb.default_port, 80)
  default_protocol = try(var.alb.default_protocol, "HTTP")
  listeners = merge(
    {
      http-https-redirect = {
        port     = 80
        protocol = "HTTP"

        redirect = {
          port        = "443"
          protocol    = "HTTPS"
          status_code = "HTTP_301"
        }
      }

      https = merge(
        {
          port            = 443
          protocol        = "HTTPS"
          ssl_policy      = try(var.alb.https_listener_ssl_policy, "ELBSecurityPolicy-TLS13-1-2-Res-2021-06")
          certificate_arn = var.create_certificate ? module.acm.acm_certificate_arn : var.certificate_arn
        },
        var.alb_https_default_action,
        lookup(var.alb, "https_listener", {})
      )
    },
    lookup(var.alb, "listeners", {})
  )

  # Target group(s)
  target_groups = merge(
    {
      healthchecks = {
        name                              = var.name
        protocol                          = "HTTP"
        port                              = local.healthchecks_port
        create_attachment                 = false
        target_type                       = "ip"
        deregistration_delay              = 10
        load_balancing_cross_zone_enabled = true

        health_check = {
          enabled             = true
          healthy_threshold   = 5
          interval            = 30
          matcher             = "200"
          path                = "/api/v3/status/"
          port                = local.healthchecks_port
          protocol            = "HTTP"
          timeout             = 5
          unhealthy_threshold = 2
        }
      }
    },
    lookup(var.alb, "target_groups", {})
  )

  # Security group
  create_security_group          = try(var.alb.create_security_group, true)
  security_group_name            = try(var.alb.security_group_name, var.name)
  security_group_use_name_prefix = try(var.alb.security_group_use_name_prefix, true)
  security_group_description     = try(var.alb.security_group_description, null)
  vpc_id                         = var.vpc_id
  security_group_ingress_rules = coalesce(var.alb_security_group_ingress_rules, lookup(var.alb, "security_group_ingress_rules",
    {
      http = {
        from_port   = 80
        to_port     = 80
        ip_protocol = "tcp"
        cidr_ipv4   = "0.0.0.0/0"
      }
      https = {
        from_port   = 443
        to_port     = 443
        ip_protocol = "tcp"
        cidr_ipv4   = "0.0.0.0/0"
      }
    }
  ))

  security_group_egress_rules = lookup(var.alb, "security_group_egress_rules",
    {
      all = {
        ip_protocol = "-1"
        cidr_ipv4   = "0.0.0.0/0"
      }
    }
  )
  security_group_tags = try(var.alb.security_group_tags, {})

  # Route53 record(s)
  route53_records = merge(
    { for k, v in local.route53_records : k => v if var.create_route53_records },
    lookup(var.alb, "route53_records", {})
  )

  # WAF
  associate_web_acl = try(var.alb.associate_web_acl, false)
  web_acl_arn       = try(var.alb.web_acl_arn, null)

  tags = var.tags
}

################################################################################
# ACM
################################################################################

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "5.0.0"

  create_certificate = var.create && var.create_certificate && var.create_alb

  domain_name          = var.certificate_domain_name
  validate_certificate = var.validate_certificate
  validation_method    = "DNS"
  zone_id              = var.route53_zone_id

  tags = var.tags
}

################################################################################
# ECS
################################################################################

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "5.6.0"

  create = var.create && var.create_cluster

  # Cluster
  cluster_name          = try(var.cluster.name, var.name)
  cluster_configuration = try(var.cluster.configuration, {})
  cluster_settings = try(var.cluster.settings, {
    name  = "containerInsights"
    value = "enabled"
    }
  )

  # Cloudwatch log group
  create_cloudwatch_log_group            = try(var.cluster.create_cloudwatch_log_group, true)
  cloudwatch_log_group_retention_in_days = try(var.cluster.cloudwatch_log_group_retention_in_days, 90)
  cloudwatch_log_group_kms_key_id        = try(var.cluster.cloudwatch_log_group_kms_key_id, null)
  cloudwatch_log_group_tags              = try(var.cluster.cloudwatch_log_group_tags, {})

  # Capacity providers
  fargate_capacity_providers = try(var.cluster.fargate_capacity_providers, {})

  tags = var.tags
}

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "5.6.0"

  create = var.create

  # Service
  ignore_task_definition_changes    = try(var.service.ignore_task_definition_changes, false)
  alarms                            = try(var.service.alarms, {})
  capacity_provider_strategy        = try(var.service.capacity_provider_strategy, {})
  cluster_arn                       = var.create_cluster && var.create ? module.ecs_cluster.arn : var.cluster_arn
  deployment_controller             = try(var.service.deployment_controller, {})
  desired_count                     = try(var.service.desired_count, 1)
  enable_ecs_managed_tags           = try(var.service.enable_ecs_managed_tags, true)
  enable_execute_command            = try(var.service.enable_execute_command, false)
  force_new_deployment              = try(var.service.force_new_deployment, true)
  health_check_grace_period_seconds = try(var.service.health_check_grace_period_seconds, null)
  launch_type                       = try(var.service.launch_type, "FARGATE")
  load_balancer = merge(
    {
      service = {
        target_group_arn = var.create_alb && var.create ? module.alb.target_groups["healthchecks"].arn : var.alb_target_group_arn
        container_name   = "healthchecks"
        container_port   = local.healthchecks_port
      }
    },
    lookup(var.service, "load_balancer", {})
  )
  name                          = try(var.service.name, var.name)
  assign_public_ip              = try(var.service.assign_public_ip, false)
  security_group_ids            = try(var.service.security_group_ids, [])
  subnet_ids                    = try(var.service.subnet_ids, var.service_subnets)
  ordered_placement_strategy    = try(var.service.ordered_placement_strategy, {})
  placement_constraints         = try(var.service.placement_constraints, {})
  platform_version              = try(var.service.platform_version, null)
  propagate_tags                = try(var.service.propagate_tags, null)
  scheduling_strategy           = try(var.service.scheduling_strategy, null)
  service_connect_configuration = lookup(var.service, "service_connect_configuration", {})
  service_registries            = lookup(var.service, "service_registries", {})
  timeouts                      = try(var.service.timeouts, {})
  triggers                      = try(var.service.triggers, {})
  wait_for_steady_state         = try(var.service.wait_for_steady_state, null)

  # Service IAM role
  create_iam_role               = try(var.service.create_iam_role, true)
  iam_role_arn                  = try(var.service.iam_role_arn, null)
  iam_role_name                 = try(var.service.iam_role_name, null)
  iam_role_use_name_prefix      = try(var.service.iam_role_use_name_prefix, true)
  iam_role_path                 = try(var.service.iam_role_path, null)
  iam_role_description          = try(var.service.iam_role_description, null)
  iam_role_permissions_boundary = try(var.service.iam_role_permissions_boundary, null)
  iam_role_tags                 = try(var.service.iam_role_tags, {})
  iam_role_statements           = lookup(var.service, "iam_role_statements", {})

  # Task definition
  create_task_definition = try(var.service.create_task_definition, true)
  task_definition_arn    = try(var.service.task_definition_arn, null)
  container_definitions = merge(
    {
      healthchecks = {
        command                 = try(var.healthchecks.command, [])
        cpu                     = try(var.healthchecks.cpu, 1024)
        dependencies            = try(var.healthchecks.dependencies, []) # depends_on is a reserved word
        disable_networking      = try(var.healthchecks.disable_networking, null)
        dns_search_domains      = try(var.healthchecks.dns_search_domains, [])
        dns_servers             = try(var.healthchecks.dns_servers, [])
        docker_labels           = try(var.healthchecks.docker_labels, {})
        docker_security_options = try(var.healthchecks.docker_security_options, [])
        enable_execute_command  = try(var.healthchecks.enable_execute_command, try(var.service.enable_execute_command, false))
        entrypoint              = try(var.healthchecks.entrypoint, [])
        environment = concat(
          [
            {
              name  = "SITE_ROOT"
              value = local.healthchecks_url
            },
            {
              name  = "ALLOWED_HOSTS"
              value = "${local.healthchecks_url},localhost,*"
            },
          ],
          lookup(var.healthchecks, "environment", [])
        )
        environment_files      = try(var.healthchecks.environment_files, [])
        essential              = try(var.healthchecks.essential, true)
        extra_hosts            = try(var.healthchecks.extra_hosts, [])
        firelens_configuration = try(var.healthchecks.firelens_configuration, {})
        health_check           = try(var.healthchecks.health_check, {})
        hostname               = try(var.healthchecks.hostname, null)
        image                  = try(var.healthchecks.image, "healthchecks/healthchecks:latest")
        interactive            = try(var.healthchecks.interactive, false)
        links                  = try(var.healthchecks.links, [])
        linux_parameters       = try(var.healthchecks.linux_parameters, {})
        log_configuration      = lookup(var.healthchecks, "log_configuration", {})
        memory                 = try(var.healthchecks.memory, 2048)
        memory_reservation     = try(var.healthchecks.memory_reservation, null)
        name                   = "healthchecks"
        port_mappings = [{
          name          = "healthchecks"
          containerPort = local.healthchecks_port
          hostPort      = local.healthchecks_port
          protocol      = "tcp"
        }]
        privileged               = try(var.healthchecks.privileged, false)
        pseudo_terminal          = try(var.healthchecks.pseudo_terminal, false)
        readonly_root_filesystem = try(var.healthchecks.readonly_root_filesystem, false)
        repository_credentials   = try(var.healthchecks.repository_credentials, {})
        resource_requirements    = try(var.healthchecks.resource_requirements, [])
        secrets                  = try(var.healthchecks.secrets, [])
        start_timeout            = try(var.healthchecks.start_timeout, 30)
        stop_timeout             = try(var.healthchecks.stop_timeout, 120)
        system_controls          = try(var.healthchecks.system_controls, [])
        ulimits                  = try(var.healthchecks.ulimits, [])
        user                     = try(var.healthchecks.user, "${var.healthchecks_uid}:${var.healthchecks_gid}")
        volumes_from             = try(var.healthchecks.volumes_from, [])
        working_directory        = try(var.healthchecks.working_directory, null)

        # CloudWatch Log Group
        service                                = var.name
        enable_cloudwatch_logging              = try(var.healthchecks.enable_cloudwatch_logging, true)
        create_cloudwatch_log_group            = try(var.healthchecks.create_cloudwatch_log_group, true)
        cloudwatch_log_group_use_name_prefix   = try(var.healthchecks.cloudwatch_log_group_use_name_prefix, true)
        cloudwatch_log_group_retention_in_days = try(var.healthchecks.cloudwatch_log_group_retention_in_days, 14)
        cloudwatch_log_group_kms_key_id        = try(var.healthchecks.cloudwatch_log_group_kms_key_id, null)
      },
    },
    lookup(var.service, "container_definitions", {})
  )
  container_definition_defaults         = lookup(var.service, "container_definition_defaults", {})
  cpu                                   = try(var.service.cpu, 1024)
  ephemeral_storage                     = try(var.service.ephemeral_storage, {})
  family                                = try(var.service.family, null)
  inference_accelerator                 = try(var.service.inference_accelerator, {})
  ipc_mode                              = try(var.service.ipc_mode, null)
  memory                                = try(var.service.memory, 2048)
  network_mode                          = try(var.service.network_mode, "awsvpc")
  pid_mode                              = try(var.service.pid_mode, null)
  task_definition_placement_constraints = try(var.service.task_definition_placement_constraints, {})
  proxy_configuration                   = try(var.service.proxy_configuration, {})
  requires_compatibilities              = try(var.service.requires_compatibilities, ["FARGATE"])
  runtime_platform = try(var.service.runtime_platform, {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  })
  skip_destroy = try(var.service.skip_destroy, null)
  task_tags    = try(var.service.task_tags, {})

  # Task execution IAM role
  create_task_exec_iam_role               = try(var.service.create_task_exec_iam_role, true)
  task_exec_iam_role_arn                  = try(var.service.task_exec_iam_role_arn, null)
  task_exec_iam_role_name                 = try(var.service.task_exec_iam_role_name, null)
  task_exec_iam_role_use_name_prefix      = try(var.service.task_exec_iam_role_use_name_prefix, true)
  task_exec_iam_role_path                 = try(var.service.task_exec_iam_role_path, null)
  task_exec_iam_role_description          = try(var.service.task_exec_iam_role_description, null)
  task_exec_iam_role_permissions_boundary = try(var.service.task_exec_iam_role_permissions_boundary, null)
  task_exec_iam_role_tags                 = try(var.service.task_exec_iam_role_tags, {})
  task_exec_iam_role_policies             = lookup(var.service, "task_exec_iam_role_policies", {})

  # Task execution IAM role policy
  create_task_exec_policy  = try(var.service.create_task_exec_policy, true)
  task_exec_ssm_param_arns = try(var.service.task_exec_ssm_param_arns, ["arn:aws:ssm:*:*:parameter/*"])
  task_exec_secret_arns    = try(var.service.task_exec_secret_arns, ["arn:aws:secretsmanager:*:*:secret:*"])
  task_exec_iam_statements = lookup(var.service, "task_exec_iam_statements", {})

  # Tasks - IAM role
  create_tasks_iam_role               = try(var.service.create_tasks_iam_role, true)
  tasks_iam_role_arn                  = try(var.service.tasks_iam_role_arn, null)
  tasks_iam_role_name                 = try(var.service.tasks_iam_role_name, null)
  tasks_iam_role_use_name_prefix      = try(var.service.tasks_iam_role_use_name_prefix, true)
  tasks_iam_role_path                 = try(var.service.tasks_iam_role_path, null)
  tasks_iam_role_description          = try(var.service.tasks_iam_role_description, null)
  tasks_iam_role_permissions_boundary = try(var.service.tasks_iam_role_permissions_boundary, null)
  tasks_iam_role_tags                 = try(var.service.tasks_iam_role_tags, {})
  tasks_iam_role_policies             = lookup(var.service, "tasks_iam_role_policies", {})
  tasks_iam_role_statements           = lookup(var.service, "tasks_iam_role_statements", {})

  # Task set
  external_id               = try(var.service.external_id, null)
  scale                     = try(var.service.scale, {})
  force_delete              = try(var.service.force_delete, null)
  wait_until_stable         = try(var.service.wait_until_stable, null)
  wait_until_stable_timeout = try(var.service.wait_until_stable_timeout, null)

  # Autoscaling
  enable_autoscaling            = try(var.service.enable_autoscaling, false)
  autoscaling_min_capacity      = try(var.service.autoscaling_min_capacity, 1)
  autoscaling_max_capacity      = try(var.service.autoscaling_max_capacity, 10)
  autoscaling_policies          = try(var.service.autoscaling_policies, {})
  autoscaling_scheduled_actions = try(var.service.autoscaling_scheduled_actions, {})

  # Security Group
  create_security_group          = try(var.service.create_security_group, true)
  security_group_name            = try(var.service.security_group_name, null)
  security_group_use_name_prefix = try(var.service.security_group_use_name_prefix, true)
  security_group_description     = try(var.service.security_group_description, null)
  security_group_rules = merge(
    {
      healthchecks = {
        type                     = "ingress"
        from_port                = local.healthchecks_port
        to_port                  = local.healthchecks_port
        protocol                 = "tcp"
        source_security_group_id = var.create_alb ? module.alb.security_group_id : var.alb_security_group_id
      }
    },
    lookup(var.service, "security_group_rules", {
      egress = {
        type        = "egress"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
    })
  )
  security_group_tags = try(var.service.security_group_tags, {})

  tags = var.tags
}
