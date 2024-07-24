resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_iam_user" "example" {
  name = "py-user-${random_string.suffix.result}"
}

resource "aws_iam_access_key" "example" {
  user = aws_iam_user.example.name
}

resource "aws_dynamodb_table" "example" {
  name         = "python-process-heartbeat-${random_string.suffix.result}"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "source"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  hash_key  = "source"
  range_key = "timestamp"

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_sqs_queue" "example" {
  name                      = "python-process-heartbeat-${random_string.suffix.result}"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 0
}

resource "aws_iam_policy" "dynamodb_table" {
  name = "python-process-heartbeat-${random_string.suffix.result}-dynamodb-table"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = [
          aws_dynamodb_table.example.arn
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "sqs" {
  name = "python-process-heartbeat-${random_string.suffix.result}-sqs"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:ReceiveMessage",
          "sqs:SendMessage"
        ]
        Resource = [
          "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_sqs_queue.example.name}"
        ]
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "dynamodb_table" {
  user       = aws_iam_user.example.name
  policy_arn = aws_iam_policy.dynamodb_table.arn
}

resource "aws_iam_user_policy_attachment" "sqs" {
  user       = aws_iam_user.example.name
  policy_arn = aws_iam_policy.sqs.arn
}

resource "null_resource" "example" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "#!/bin/bash" > terraform.tmp
      echo "export AWS_ACCESS_KEY_ID=${aws_iam_access_key.example.id}" >> terraform.tmp
      echo "export AWS_SECRET_ACCESS_KEY=${aws_iam_access_key.example.secret}" >> terraform.tmp
      echo "export AWS_REGION=${data.aws_region.current.name}" >> terraform.tmp
      chmod +x terraform.tmp
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      rm -f terraform.tmp
    EOT
  }
}

output "aws_sqs_queue_url" {
  value = aws_sqs_queue.example.url
}

output "aws_dynamodb_table_name" {
  value = aws_dynamodb_table.example.name
}

output "suffix" {
  value = random_string.suffix.result
}
