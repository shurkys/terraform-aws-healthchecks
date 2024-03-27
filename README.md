# Healthchecks on AWS Fargate Terraform Module

[![SWUbanner](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/banner2-direct.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)

[Healthchecks.io](https://healthchecks.io) is a service for monitoring cron jobs and similar periodic processes:

Based on [terraform-aws-atlantis](https://github.com/terraform-aws-modules/terraform-aws-atlantis "terraform-aws-atlantis")

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_acm"></a> [acm](#module\_acm) | terraform-aws-modules/acm/aws | 5.0.0 |
| <a name="module_alb"></a> [alb](#module\_alb) | terraform-aws-modules/alb/aws | 9.1.0 |
| <a name="module_ecs_cluster"></a> [ecs\_cluster](#module\_ecs\_cluster) | terraform-aws-modules/ecs/aws//modules/cluster | 5.6.0 |
| <a name="module_ecs_service"></a> [ecs\_service](#module\_ecs\_service) | terraform-aws-modules/ecs/aws//modules/service | 5.6.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb"></a> [alb](#input\_alb) | Map of values passed to ALB module definition. See the [ALB module](https://github.com/terraform-aws-modules/terraform-aws-alb) for full list of arguments supported | `any` | `{}` | no |
| <a name="input_alb_https_default_action"></a> [alb\_https\_default\_action](#input\_alb\_https\_default\_action) | Default action for the ALB https listener | `any` | <pre>{<br>  "forward": {<br>    "target_group_key": "healthchecks"<br>  }<br>}</pre> | no |
| <a name="input_alb_internal"></a> [alb\_internal](#input\_alb\_internal) | Internet-facing (false) or Internal (true). An internet-facing load balancer routes requests from clients to targets over the internet. An internal load balancer routes requests to targets using private IP addresses. | `bool` | `false` | no |
| <a name="input_alb_security_group_id"></a> [alb\_security\_group\_id](#input\_alb\_security\_group\_id) | ID of an existing security group that will be used by ALB. Required if `create_alb` is `false` | `string` | `""` | no |
| <a name="input_alb_security_group_ingress_rules"></a> [alb\_security\_group\_ingress\_rules](#input\_alb\_security\_group\_ingress\_rules) | Custom ingress rules for alb security group | <pre>map(object({<br>    from_port = number<br>    to_port   = number<br>    protocol  = string<br>    cidr_ipv4 = string<br>  }))</pre> | `null` | no |
| <a name="input_alb_subnets"></a> [alb\_subnets](#input\_alb\_subnets) | List of subnets to place ALB in. Required if `create_alb` is `true` | `list(string)` | `[]` | no |
| <a name="input_alb_target_group_arn"></a> [alb\_target\_group\_arn](#input\_alb\_target\_group\_arn) | ARN of an existing ALB target group that will be used to route traffic to the Healthchecks service. Required if `create_alb` is `false` | `string` | `""` | no |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | ARN of certificate issued by AWS ACM. If empty, a new ACM certificate will be created and validated using Route53 DNS | `string` | `""` | no |
| <a name="input_certificate_domain_name"></a> [certificate\_domain\_name](#input\_certificate\_domain\_name) | Route53 domain name to use for ACM certificate. Route53 zone for this domain should be created in advance. Specify if it is different from value in `route53_zone_name` | `string` | `""` | no |
| <a name="input_cluster"></a> [cluster](#input\_cluster) | Map of values passed to ECS cluster module definition. See the [ECS cluster module](https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/modules/cluster) for full list of arguments supported | `any` | `{}` | no |
| <a name="input_cluster_arn"></a> [cluster\_arn](#input\_cluster\_arn) | ARN of an existing ECS cluster where resources will be created. Required when `create_cluster` is `false` | `string` | `""` | no |
| <a name="input_create"></a> [create](#input\_create) | Controls if resources should be created (affects nearly all resources) | `bool` | `true` | no |
| <a name="input_create_alb"></a> [create\_alb](#input\_create\_alb) | Determines whether to create an ALB or not | `bool` | `true` | no |
| <a name="input_create_certificate"></a> [create\_certificate](#input\_create\_certificate) | Determines whether to create an ACM certificate or not. If `false`, `certificate_arn` must be provided | `bool` | `true` | no |
| <a name="input_create_cluster"></a> [create\_cluster](#input\_create\_cluster) | Whether to create an ECS cluster or not | `bool` | `true` | no |
| <a name="input_create_route53_records"></a> [create\_route53\_records](#input\_create\_route53\_records) | Determines whether to create Route53 `A` and `AAAA` records for the loadbalancer | `bool` | `true` | no |
| <a name="input_healthchecks"></a> [healthchecks](#input\_healthchecks) | Map of values passed to Healthchecks container definition. See the [ECS container definition module](https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/modules/container-definition) for full list of arguments supported | `any` | `{}` | no |
| <a name="input_healthchecks_gid"></a> [healthchecks\_gid](#input\_healthchecks\_gid) | GID of the healthchecks user | `number` | `1000` | no |
| <a name="input_healthchecks_uid"></a> [healthchecks\_uid](#input\_healthchecks\_uid) | UID of the healthchecks user | `number` | `100` | no |
| <a name="input_name"></a> [name](#input\_name) | Common name to use on all resources created unless a more specific name is provided | `string` | `"healthchecks"` | no |
| <a name="input_route53_record_name"></a> [route53\_record\_name](#input\_route53\_record\_name) | Name of Route53 record to create ACM certificate in and main A-record. If null is specified, var.name is used instead. Provide empty string to point root domain name to ALB. | `string` | `null` | no |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | Route53 zone ID to use for ACM certificate and Route53 records | `string` | `""` | no |
| <a name="input_service"></a> [service](#input\_service) | Map of values passed to ECS service module definition. See the [ECS service module](https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/modules/service) for full list of arguments supported | `any` | `{}` | no |
| <a name="input_service_subnets"></a> [service\_subnets](#input\_service\_subnets) | List of subnets to place ECS service within | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_validate_certificate"></a> [validate\_certificate](#input\_validate\_certificate) | Determines whether to validate ACM certificate using Route53 DNS. If `false`, certificate will be created but not validated | `bool` | `true` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC where the resources will be provisioned | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb"></a> [alb](#output\_alb) | ALB created and all of its associated outputs |
| <a name="output_cluster"></a> [cluster](#output\_cluster) | ECS cluster created and all of its associated outputs |
| <a name="output_service"></a> [service](#output\_service) | ECS service created and all of its associated outputs |
| <a name="output_url"></a> [url](#output\_url) | URL of Healthchecks |
<!-- END_TF_DOCS -->
