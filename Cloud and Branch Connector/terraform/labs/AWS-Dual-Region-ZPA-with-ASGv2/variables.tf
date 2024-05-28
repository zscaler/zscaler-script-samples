variable "cloudname" {
  description = "Zscaler Cloud Name"
  default = "zscalertwo.net"
}
# AWS variables
variable "aws_region1" {
  description = "Region1 Preference"
  default = "us-west-2"
}

variable "aws_region2" {
  description = "Region2 Preference"
  default = "us-east-2"
}

variable "name_prefix" {
  description = "The prefix for all resources"
  default     = "zscc"
  type        = string
}

variable "name_suffix" {
  description = "The suffix for all your resources"
  type        = string
}

variable "vpc_cidr" {
  description = "The prefix for VPCs"
  default     = "10.1.0.0/16"
}

variable "cc_count" {
  description = "Number of Cloud Connector appliances to create"
  default     = 2
}

variable "az_count" {
  description = "Number of subnets to create based on availability zone"
  type = number
  default     = 2
  validation {
          condition     = (
          (var.az_count >= 1 && var.az_count <= 3)
        )
          error_message = "Input az_count must be set to a single value between 1 and 3. Note* some regions have greater than 3 AZs. Please modify az_count validation in variables.tf if you are utilizing more than 3 AZs in a region that supports it. https://aws.amazon.com/about-aws/global-infrastructure/regions_az/."
      }
}

variable "http_probe_port" {
  description = "The port Cloud Connector will listen on for Load Balancer Healthchecks"
  default = 10000
  validation {
          condition     = (
            var.http_probe_port == 0 ||
            var.http_probe_port == 80 ||
          ( var.http_probe_port >= 1024 && var.http_probe_port <= 65535 )
        )
          error_message = "Input http_probe_port must be set to a single value of 80 or any number between 1024-65535."
      }
}

variable "cc_vm_prov_url" {
  description = "Zscaler Cloud Connector Provisioning URL"
  type        = string
}

variable "secret_username" {
  description = "AWS Secrets Manager Username for Cloud Connector provisioning"
  type        = string
}
variable "secret_password" {
  description = "AWS Secrets Manager Password for Cloud Connector provisioning"
  type        = string
}
variable "secret_apikey" {
  description = "AWS Secrets Manager API Key for Cloud Connector provisioning"
  type        = string
}

variable "ccvm_instance_type" {
  description = "Cloud Connector Instance Type (M5.large is recommended)"
  default     = "c5a.large"
  validation {
          condition     = ( 
            var.ccvm_instance_type == "t3.medium"  ||
            var.ccvm_instance_type == "m5.large"   ||
            var.ccvm_instance_type == "c5.large"   ||
            var.ccvm_instance_type == "c5a.large"  ||
            var.ccvm_instance_type == "m5.2xlarge" ||
            var.ccvm_instance_type == "c5.2xlarge" ||
            var.ccvm_instance_type == "m5.4xlarge" ||
            var.ccvm_instance_type == "c5.4xlarge"
          )
          error_message = "Input ccvm_instance_type must be set to an approved vm instance type."
      }
}

variable "owner_tag" {
  description = "Custom owner tag attributes"
  type = string
  default = "EaaS"
}

variable "tls_key_algorithm" {
  default   = "RSA"
  type      = string
}

variable "cc_instance_size" {
  description = "Zscaler Cloud Connector instance size (Small is recommended)"
  default = "small"
   validation {
          condition     = ( 
            var.cc_instance_size == "small"  ||
            var.cc_instance_size == "medium" ||
            var.cc_instance_size == "large"
          )
          error_message = "Input cc_instance_size must be set to an approved cc instance type."
      }
}

locals {
  small_cc_instance  = ["t3.medium","m5.large","c5.large","c5a.large","m5.2xlarge","c5.2xlarge","m5.4xlarge","c5.4xlarge"]
  medium_cc_instance = ["m5.2xlarge","c5.2xlarge","m5.4xlarge","c5.4xlarge"]
  large_cc_instance  = ["m5.4xlarge","c5.4xlarge"]
  
  valid_cc_create = (
contains(local.small_cc_instance, var.ccvm_instance_type) && var.cc_instance_size == "small"   ||
contains(local.medium_cc_instance, var.ccvm_instance_type) && var.cc_instance_size == "medium" ||
contains(local.large_cc_instance, var.ccvm_instance_type) && var.cc_instance_size == "large"
 )
}

variable "aws_access_key" {
  description = "AWS Access Key"
  type = string
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type = string
}
variable "ac_count" {
  description = "Default number of App Connector appliances to create"
  default     = 1
}

variable "cross_zone_lb_enabled" {
  default = true
  type = bool
  description = "Toggle cross-zone loadbalancing of GWLB on/off"
}

variable "acvm_instance_type" {
  description = "App Connector Instance Type"
  default     = "m5a.xlarge"
  validation {
          condition     = ( 
            var.acvm_instance_type == "t3.xlarge"  ||
            var.acvm_instance_type == "m5a.xlarge" 
          )
          error_message = "Input acvm_instance_type must be set to an approved vm instance type."
      }
}

variable "zpa_client_id" {
  description = "ZPA Client ID"
  type = string
}

variable "zpa_client_secret" {
  description = "ZPA Client Secret"
  type = string
}

variable "zpa_customer_id" {
  description = "ZPA Customer ID"
  type = string
}

variable "gwlb_enabled" {
  type        = bool
  default     = true
  description = "Default is true. Workload/Route 53 subnet Route Tables will point to network_interface_id via var.cc_service_enis. If true, Route Tables will point to vpc_endpoint_id via var.gwlb_endpoint_ids input."
}

variable "mgmt_ssh_enabled" {
  type        = bool
  description = "Default is true which creates an ingress rule permitting SSH traffic from the local VPC to the CC management interface. If false, the rule is not created. Value ignored if not creating a security group"
  default     = true
}

variable "all_ports_egress_enabled" {
  type        = bool
  default     = true
  description = "Default is true which creates an egress rule permitting the CC service interface to forward direct traffic on all ports and protocols. If false, the rule is not created. Value ignored if not creating a security group"
}

## GWLB specific variables
variable "health_check_interval" {
  type        = number
  description = "Interval for GWLB target group health check probing, in seconds, of Cloud Connector targets. Minimum 5 and maximum 300 seconds"
  default     = 10
}

variable "healthy_threshold" {
  type        = number
  description = "The number of successful health checks required before an unhealthy target becomes healthy. Minimum 2 and maximum 10"
  default     = 2
}

variable "unhealthy_threshold" {
  type        = number
  description = "The number of unsuccessful health checks required before an healthy target becomes unhealthy. Minimum 2 and maximum 10"
  default     = 3
}

variable "acceptance_required" {
  type        = bool
  description = "Whether to require manual acceptance of any VPC Endpoint registration attempts to the Endpoint Service or not. Default is false"
  default     = false
}

variable "allowed_principals" {
  type        = list(string)
  description = "List of AWS Principal ARNs who are allowed access to the GWLB Endpoint Service. E.g. [\"arn:aws:iam::1234567890:root\"]`. See https://docs.aws.amazon.com/vpc/latest/privatelink/configure-endpoint-service.html#accept-reject-connection-requests"
  default     = []
}

variable "flow_stickiness" {
  type        = string
  description = "Options are (Default) 5-tuple (src ip/src port/dest ip/dest port/protocol), 3-tuple (src ip/dest ip/protocol), or 2-tuple (src ip/dest ip)"
  default     = "5-tuple"

  validation {
    condition = (
      var.flow_stickiness == "2-tuple" ||
      var.flow_stickiness == "3-tuple" ||
      var.flow_stickiness == "5-tuple"
    )
    error_message = "Input flow_stickiness must be set to an approved value of either 5-tuple, 3-tuple, or 2-tuple."
  }
}

variable "deregistration_delay" {
  type        = number
  description = "Amount time for Elastic Load Balancing to wait before changing the state of a deregistering target from draining to unused. The range is 0-3600 seconds."
  default     = 0
}

variable "rebalance_enabled" {
  type        = bool
  description = "Indicates how the GWLB handles existing flows when a target is deregistered or marked unhealthy. true means rebalance. false means no_rebalance. Default: true"
  default     = true
}

variable "ami_id" {
  type        = list(string)
  description = "AMI ID(s) to be used for deploying Cloud Connector appliances. Ideally all VMs should be on the same AMI ID as templates always pull the latest from AWS Marketplace. This variable is provided if a customer desires to override/retain an old ami for existing deployments rather than upgrading and forcing a launch template change."
  default     = [""]
}

variable "ebs_volume_type" {
  type        = string
  description = "(Optional) Type of volume. Valid values include standard, gp2, gp3, io1, io2, sc1, or st1. Defaults to gp3"
  default     = "gp3"
}

variable "ebs_encryption_enabled" {
  type        = bool
  description = "true/false whether to enable EBS encryption on the root volume. Default is true"
  default     = true
}

variable "byo_kms_key_alias" {
  type        = string
  description = "Requires var.ebs_encryption_enabled to be true. Set to null by default which is the AWS default managed/master key. Set as 'alias/<key-alias>' to use a custom KMS key"
  default     = null
}

# ASG specific variables
variable "min_size" {
  type        = number
  description = "Mininum number of Cloud Connectors to maintain in Autoscaling group"
  default     = 1
}

variable "max_size" {
  type        = number
  description = "Maximum number of Cloud Connectors to maintain in Autoscaling group"
  default     = 2
  validation {
    condition = (
      var.max_size >= 1 && var.max_size <= 10
    )
    error_message = "Input max_size must be set to a number between 1 and 10."
  }
}

variable "health_check_grace_period" {
  type        = number
  description = "The amount of time until EC2 Auto Scaling performs the first health check on new instances after they are put into service. With lifecycle hooks it is immediate. Otheriwse Default is 15 minutes"
  default     = 900
}

variable "warm_pool_enabled" {
  type        = bool
  description = "If set to true, add a warm pool to the specified Auto Scaling group. See [warm_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#warm_pool)."
  default     = true
}

variable "warm_pool_state" {
  type        = string
  description = "Sets the instance state to transition to after the lifecycle hooks finish. Valid values are: Stopped (default) or Running. Ignored when 'warm_pool_enabled' is false"
  default     = "Stopped"
}

variable "warm_pool_min_size" {
  type        = number
  description = "Specifies the minimum number of instances to maintain in the warm pool. This helps you to ensure that there is always a certain number of warmed instances available to handle traffic spikes. Ignored when 'warm_pool_enabled' is false"
  default     = 1
}

variable "warm_pool_max_group_prepared_capacity" {
  type        = number
  description = "Specifies the total maximum number of instances that are allowed to be in the warm pool or in any state except Terminated for the Auto Scaling group. Ignored when 'warm_pool_enabled' is false"
  default     = null
}

variable "reuse_on_scale_in" {
  type        = bool
  description = "Specifies whether instances in the Auto Scaling group can be returned to the warm pool on scale in. Default recommendation is true"
  default     = true
}

variable "launch_template_version" {
  type        = string
  description = "Launch template version. Can be version number, `$Latest` or `$Default`"
  default     = "$Latest"
}

variable "target_cpu_util_value" {
  type        = number
  description = "Target value number for autoscaling policy CPU utilization target tracking. ie: trigger a scale in/out to keep average CPU Utliization percentage across all instances at/under this number"
  default     = 20
}

variable "lifecyclehook_instance_launch_wait_time" {
  type        = number
  description = "The maximum amount of time to wait in pending:wait state on instance launch in warmpool"
  default     = 1800
}

variable "lifecyclehook_instance_terminate_wait_time" {
  type        = number
  description = "The maximum amount of time to wait in terminating:wait state on instance termination"
  default     = 900
}

variable "asg_enabled" {
  type        = bool
  description = "Determines whether or not to create the cc_autoscale_lifecycle_policy IAM Policy and attach it to the CC IAM Role"
  default     = true
}

variable "sns_enabled" {
  type        = bool
  description = "Determine whether or not to create autoscaling group notifications. Default is false. If setting this value to true, terraform will also create a new sns topic and topic subscription"
  default     = false
}

variable "sns_email_list" {
  type        = list(string)
  description = "List of email addresses to input for sns topic subscriptions for autoscaling group notifications. Required if sns_enabled variable is true and byo_sns_topic false"
  default     = [""]
}

variable "byo_sns_topic" {
  type        = bool
  description = "Determine whether or not to create an AWS SNS topic and topic subscription for email alerts. Setting this variable to true implies you should also set variable sns_enabled to true"
  default     = false
}

variable "byo_sns_topic_name" {
  type        = string
  description = "Existing SNS Topic friendly name to be used for autoscaling group notifications"
  default     = ""
}

variable "protect_from_scale_in" {
  type        = bool
  description = "Whether newly launched instances are automatically protected from termination by Amazon EC2 Auto Scaling when scaling in. For more information about preventing instances from terminating on scale in, see Using instance scale-in protection in the Amazon EC2 Auto Scaling User Guide"
  default     = false
}

variable "instance_warmup" {
  type        = number
  description = "Amount of time, in seconds, until a newly launched instance can contribute to the Amazon CloudWatch metrics. This delay lets an instance finish initializing before Amazon EC2 Auto Scaling aggregates instance metrics, resulting in more reliable usage data. Set this value equal to the amount of time that it takes for resource consumption to become stable after an instance reaches the InService state"
  default     = 0
}

variable "asg_lambda_filename" {
  type        = string
  description = "Name of the lambda zip file without suffix"
  default     = "zscaler_cc_lambda_service"
}