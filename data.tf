data "aws_region" "main" {}
data "aws_caller_identity" "main" {}

data "archive_file" "main" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  source_dir  = "${path.module}/lambda"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "main" {
  policy_id = "terraform-managed-policy"

  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      format("%v:*", aws_cloudwatch_log_group.main.arn)
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeImages",
      # Required by AWS in order to use a new launch template https://docs.aws.amazon.com/autoscaling/ec2/userguide/ts-as-launch-template.html
      "ec2:CreateTags",
      "ec2:RunInstances"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ssm:GetParameter",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:ModifyLaunchTemplate",
      "CreateLaunchTemplateVersion"
    ]

    resources = [
      format("arn:aws:ec2:%v:%v:launch-template/*",
        data.aws_region.main.name,
        data.aws_caller_identity.main.account_id
      )
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeLaunchTemplateVersions",
    ]

    resources = [
      "*"
    ]

  }

  statement {
    effect = "Allow"

    actions = [
      "eks:ListClusters",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "eks:DescribeCluster",
      "eks:ListNodegroups",
    ]

    resources = [
      format("arn:aws:eks:%v:%v:cluster/*",
        data.aws_region.main.name,
        data.aws_caller_identity.main.account_id
      )
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "eks:DescribeNodegroup",
      "eks:UpdateNodegroupVersion"
    ]

    resources = [
      format("arn:aws:eks:%v:%v:nodegroup/*/*/*",
        data.aws_region.main.name,
        data.aws_caller_identity.main.account_id
      )
    ]
  }
}


