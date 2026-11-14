# Messaging backbone of the Phase 4 saga.
#
# Billing, Inventory and Execution answer the OS service through one SNS topic,
# and the OS reads the answers from its own queue, which is subscribed to it:
#
#   billing / inventory / execution --publish--> saga-events --raw--> os-saga-events --> OS
#
# The command queues (billing-commands, inventory-commands, execution-commands)
# belong to the *-infrastructure repository of the service that reads each one.
#
# The names are fixed and carry no project prefix on purpose: the services
# default to them (os-saga-events, saga-events) and build the topic ARN from
# account, region and this name. Local runs use the same names
# (os-service/e2e/localstack-init/01-saga-topology.sh).

resource "aws_sns_topic" "saga_events" {
  name = "saga-events"

  tags = {
    Name = "saga-events"
  }
}

# Messages the OS could not handle after `saga_max_receive_count` attempts land
# here instead of being retried for ever. Kept for the longest period SQS
# allows (14 days) so there is time to look at them.
resource "aws_sqs_queue" "os_saga_events_dlq" {
  name                      = "os-saga-events-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true

  tags = {
    Name = "os-saga-events-dlq"
  }
}

resource "aws_sqs_queue" "os_saga_events" {
  name = "os-saga-events"
  # Longer than the slowest handling of one answer, so a message being worked on
  # is not delivered a second time. Handlers are idempotent anyway.
  visibility_timeout_seconds = var.queue_visibility_timeout_seconds
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.os_saga_events_dlq.arn
    maxReceiveCount     = var.saga_max_receive_count
  })

  tags = {
    Name = "os-saga-events"
  }
}

# SNS needs permission to write into the queue, and only from this topic.
# Identity-based permissions of the pods' IAM role are unaffected: inside one
# account either kind of policy is enough.
data "aws_iam_policy_document" "os_saga_events_from_topic" {
  statement {
    sid       = "AllowSagaEventsTopicToSend"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.os_saga_events.arn]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.saga_events.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "os_saga_events" {
  queue_url = aws_sqs_queue.os_saga_events.id
  policy    = data.aws_iam_policy_document.os_saga_events_from_topic.json
}

# Raw delivery: the queue body is the message envelope itself, not the SNS
# wrapper around it, which is what the OS service's listener parses.
resource "aws_sns_topic_subscription" "os_saga_events" {
  topic_arn            = aws_sns_topic.saga_events.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.os_saga_events.arn
  raw_message_delivery = true

  depends_on = [aws_sqs_queue_policy.os_saga_events]
}
