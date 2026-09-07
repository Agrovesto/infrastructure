output "security_group_id" {
  value = aws_security_group.this.id
}
output "https_listener_arn" {
  value = aws_lb_listener.https.arn
}
output "dns_name" {
  value = aws_lb.this.dns_name
}
output "zone_id" {
  value = aws_lb.this.zone_id
}
output "arn_suffix" {
  value = aws_lb.this.arn_suffix
}
output "security" {
  value = {
    waf_count          = length(aws_wafv2_web_acl.this)
    waf_associations   = length(aws_wafv2_web_acl_association.this)
    waf_log_configs    = length(aws_wafv2_web_acl_logging_configuration.this)
    tls_policy         = aws_lb_listener.https.ssl_policy
    redirect_protocol  = aws_lb_listener.http.default_action[0].redirect[0].protocol
    deletion_protected = aws_lb.this.enable_deletion_protection
  }
}
