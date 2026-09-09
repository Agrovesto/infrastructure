output "start_schedule_arn" {
  value = aws_scheduler_schedule.start.arn
}

output "stop_schedule_arn" {
  value = aws_scheduler_schedule.stop.arn
}
