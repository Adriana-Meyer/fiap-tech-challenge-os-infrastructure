output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "saga_events_topic_arn" {
  description = "Topic the services publish their answers to. The services build this ARN themselves (account, region and the fixed name saga-events); this output is for checking they agree."
  value       = aws_sns_topic.saga_events.arn
}

output "os_saga_events_queue_url" {
  description = "Queue the OS service reads the answers from."
  value       = aws_sqs_queue.os_saga_events.url
}

output "os_saga_events_dlq_url" {
  description = "Where answers the OS could not handle end up after saga_max_receive_count attempts."
  value       = aws_sqs_queue.os_saga_events_dlq.url
}

output "cluster_security_group_id" {
  description = "os-database-infrastructure (RDS) allows MySQL ingress from this security group instead of a broader CIDR."
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}
