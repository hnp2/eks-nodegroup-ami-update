resource "aws_iam_role" "main" {
  name_prefix          = format("%v-", var.name)
  path                 = var.iam_path
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  permissions_boundary = ""
  description          = "The Role used by AWS Lambda to track and replace AMI for Node Groups to latest one"
  tags                 = var.tags
}

resource "aws_iam_role_policy" "main" {
  name    = "permissions"
  role    = aws_iam_role.main.id
  policy  = data.aws_iam_policy_document.main.json
}

resource "aws_cloudwatch_log_group" "main" {
  name              = format("/aws/lambda/%v", aws_lambda_function.main.function_name)
  retention_in_days = var.lambda_logs_retention_in_days
  tags              = var.tags
}

resource "aws_lambda_function" "main" {
  function_name = var.name
  role          = aws_iam_role.main.arn
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size
  runtime       = "python3.9"
  handler       = "main.lambda_handler"
  filename      = data.archive_file.main.output_path
  source_code_hash = data.archive_file.main.output_base64sha256

  environment {
    variables = merge(
      var.eks_cluster_name != null ? { EKS_CLUSTER_NAME = var.eks_cluster_name } : {} ,
      var.eks_cluster_node_groups != null ? { EKS_CLUSTER_NODE_GROUPS = join(",",var. eks_cluster_node_groups) } : {}
    )
  }

  tags          = var.tags
}

resource "aws_lambda_permission" "allow_cloudwatch_schedule" {
  count         = var.lambda_schedule_enabled ? 1 : 0
  function_name = aws_lambda_function.main.function_name
  statement_id  = "CloudWatchCronInvoke"
  action        = "lambda:InvokeFunction"

  source_arn = aws_cloudwatch_event_rule.schedule[count.index].arn
  principal = "events.amazonaws.com"
}

resource "aws_cloudwatch_event_rule" "schedule" {
  count = var.lambda_schedule_enabled ? 1 : 0
  name  = format("%v-schedule", var.name)
  schedule_expression = var.lambda_schedule
}

resource "aws_cloudwatch_event_target" "schedule" {
  count = var.lambda_schedule_enabled ? 1 : 0
  rule  = aws_cloudwatch_event_rule.schedule[count.index].name
  arn   = aws_lambda_function.main.arn
}

resource "aws_cloudwatch_metric_alarm" "main" {
  count             = var.lambda_alarm_enabled ? 1 : 0
  alarm_name        = format("%v-errors", var.name)
  alarm_description = format("Errors during '%v' lambda execution.", var.name)

  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 0
  period              = 60
  unit                = "Count"
  treat_missing_data  = "notBreaching"

  namespace   = "AWS/Lambda"
  metric_name = "Errors"
  statistic   = "Maximum"

  alarm_actions = var.lambda_alarm_actions
  ok_actions    = var.lambda_alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }
}