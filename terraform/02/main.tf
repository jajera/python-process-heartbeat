locals {
  suffix = data.terraform_remote_state.state1.outputs.suffix
}

data "aws_dynamodb_table" "example" {
  name = "python-process-heartbeat-${local.suffix}"
}

data "aws_sqs_queue" "example" {
  name = "python-process-heartbeat-${local.suffix}"
}

resource "aws_iam_role" "lambda" {
  name = "python-process-heartbeat-${local.suffix}-lambda"
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

resource "aws_iam_role_policy" "lambda" {
  name = "python-process-heartbeat-${local.suffix}-lambda"
  role = aws_iam_role.lambda.id
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
        "Action" : [
          "dynamodb:PutItem"
        ],
        "Effect" : "Allow",
        "Resource" : data.aws_dynamodb_table.example.arn
      },
      {
        "Action" : [
          "sqs:SendMessage"
        ],
        "Effect" : "Allow",
        "Resource" : data.aws_sqs_queue.example.arn
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

resource "aws_lambda_function" "send_heartbeat" {
  filename         = "${path.module}/external/send_heartbeat.zip"
  function_name    = "python-send-heartbeat-${local.suffix}"
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/external/send_heartbeat.zip")
  runtime          = "python3.12"

  environment {
    variables = {
      HEARTBEAT_QUEUE_URL = data.aws_sqs_queue.example.url
      HEARTBEAT_RUN_ONCE  = true
    }
  }
}

resource "aws_cloudwatch_event_rule" "send_heartbeat" {
  name                = "python-send-heartbeat-${local.suffix}"
  schedule_expression = "cron(* * * * ? *)"
}

resource "aws_cloudwatch_event_target" "send_heartbeat" {
  rule      = aws_cloudwatch_event_rule.send_heartbeat.name
  target_id = "lambda"
  arn       = aws_lambda_function.send_heartbeat.arn
}

resource "aws_lambda_permission" "send_heartbeat" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_heartbeat.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.send_heartbeat.arn
}
