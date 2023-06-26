variable "name" {
  type = string
  default     = "eks-cluster-ami-rotation"
  description = "The name that will be used for AWS resources"
  nullable    = false
}

variable "iam_path" {
  type = string
  default     = "/"
  description = "The path for IAM role"
  nullable    = false
}

variable "lambda_timeout" {
  type        = number
  default     = 60
  description = "Amount of time your Lambda Function has to run in seconds."
}

variable "lambda_memory_size" {
  type        = number
  default     = 128
  description = "Amount of memory in MB your Lambda Function can use at runtime"
}

variable "lambda_logs_retention_in_days" {
  type = number
  default = 365
  description = "Specifies the number of days you want to retain log events in the specified log group."
}

variable "eks_cluster_name" {
  type        = string
  default     = null
  description = "EKS Cluster name to use. If not specified all cluster will be taken into processing"
}

variable "eks_cluster_node_groups" {
  type        = list(string)
  default     = null
  description = "List of EKS Cluster Node Groups. If not specified all node groups for cluster will be considered."
}

variable "lambda_schedule_enabled" {
  type        = bool
  default     = true
  description = "Enable lambda to run on schedule."
}

variable "lambda_schedule" {
  type        = string
  default     = "cron(30 9 ? * 6 *)"
  description = "Cron or rate schedule expression for lambda. Default to cron(30 9 ? * 6 *)"
}

variable "lambda_alarm_enabled" {
  type        = bool
  default     = true
  description = "Lambda error execution notifications"
}

variable "lambda_alarm_actions" {
  type        = list(string)
  default     = []
  description = "The list of actions to execute when this alarm transitions into an `ALARM`/`OK` state from any other state"
}

variable "tags" {
  type    = map(string)
  default = {}
  description = "The map of tags to attach to created resources"
}
