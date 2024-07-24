locals {
  suffix = data.terraform_remote_state.state1.outputs.suffix
}

resource "aws_iam_role" "process_heartbeat" {
  name = "python-process-heartbeat-${local.suffix}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

data "aws_dynamodb_table" "example" {
  name = "python-process-heartbeat-${local.suffix}"
}

data "aws_sqs_queue" "example" {
  name = "python-process-heartbeat-${local.suffix}"
}

resource "aws_iam_role_policy" "process_heartbeat" {
  name = "python-process-heartbeat-${local.suffix}"
  role = aws_iam_role.process_heartbeat.id
  policy = jsonencode({
    "Statement" : [
      {
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:ReceiveMessage"
        ]
        Resource = [
          "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${data.aws_sqs_queue.example.name}"
        ]
      },
      {
        "Action" : [
          "dynamodb:PutItem"
        ],
        "Effect" : "Allow",
        "Resource" : data.aws_dynamodb_table.example.arn
      }
    ]
  })
}

resource "null_resource" "example" {
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      rm -rf ./external
    EOT
  }
}

resource "aws_lambda_function" "process_heartbeat" {
  filename         = "${path.module}/external/process_heartbeat.zip"
  function_name    = "python-process-heartbeat-${local.suffix}"
  role             = aws_iam_role.process_heartbeat.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/external/process_heartbeat.zip")
  runtime          = "python3.12"

  environment {
    variables = {
      HEARTBEAT_QUEUE_URL = data.aws_sqs_queue.example.url
      TABLE_NAME          = data.aws_dynamodb_table.example.name
    }
  }
}

resource "aws_cloudwatch_event_rule" "process_heartbeat" {
  name                = "python-process-heartbeat-${local.suffix}"
  schedule_expression = "cron(* * * * ? *)"
}

resource "aws_cloudwatch_event_target" "process_heartbeat" {
  rule      = aws_cloudwatch_event_rule.process_heartbeat.name
  target_id = "lambda"
  arn       = aws_lambda_function.process_heartbeat.arn
}

resource "aws_lambda_permission" "process_heartbeat" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_heartbeat.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.process_heartbeat.arn
}