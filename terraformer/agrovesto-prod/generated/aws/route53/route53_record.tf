resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84__13be8f42d395b0475111265493d93055-002E-agrovesto-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_13be8f42d395b0475111265493d93055.agrovesto.com"
  records                          = ["_9e386e28dc6c5739d7130fe45b2a4fc7.xlfgrmvvlj.acm-validations.aws."]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84__13be8f42d395b0475111265493d93055-002E-agrovesto-002E-com-002E-agrovesto-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_13be8f42d395b0475111265493d93055.agrovesto.com.agrovesto.com"
  records                          = ["_9e386e28dc6c5739d7130fe45b2a4fc7.xlfgrmvvlj.acm-validations.aws."]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84__2f526d39a8e34b3f80f3f001047fbf55-002E-trade-002E-agrovesto-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_2f526d39a8e34b3f80f3f001047fbf55.trade.agrovesto.com"
  records                          = ["_97ac539bb1f4bebbf7ded7c88d54a2a5.xlfgrmvvlj.acm-validations.aws."]
  ttl                              = "500"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84__7456609fffef838351fd7929d02ba17c-002E-dev-trade-002E-agrovesto-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_7456609fffef838351fd7929d02ba17c.dev-trade.agrovesto.com"
  records                          = ["_4099a5bfddeca241683b7e241e42da23.jkddzztszm.acm-validations.aws."]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84__9981d5f1f74b2a91fe3fe1c65fd0f468-002E-agrovesto-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_9981d5f1f74b2a91fe3fe1c65fd0f468.agrovesto.com"
  records                          = ["_bb7879eeef530f02cf922c3420f3af51.xlfgrmvvlj.acm-validations.aws."]
  ttl                              = "500"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84__dmarc-002E-agrovesto-002E-com-002E-_TXT_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_dmarc.agrovesto.com"
  records                          = ["v=DMARC1; p=none; rua=mailto:info@agrovesto.com; ruf=mailto:info@agrovesto.com; sp=none; adkim=r; aspf=r"]
  ttl                              = "300"
  type                             = "TXT"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84__gh-agrovesto-o-002E-agrovesto-002E-com-002E-_TXT_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_gh-agrovesto-o.agrovesto.com"
  records                          = ["cc92c7c1a6"]
  ttl                              = "300"
  type                             = "TXT"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com-002E-_A_" {
  alias {
    evaluate_target_health = "false"
    name                   = "d3b7e9oz814lns.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
  }

  multivalue_answer_routing_policy = "false"
  name                             = "agrovesto.com"
  type                             = "A"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com-002E-_MX_" {
  multivalue_answer_routing_policy = "false"
  name                             = "agrovesto.com"
  records                          = ["10 mx.zoho.com", "20 mx2.zoho.com", "50 mx3.zoho.com"]
  ttl                              = "300"
  type                             = "MX"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com-002E-_NS_" {
  multivalue_answer_routing_policy = "false"
  name                             = "agrovesto.com"
  records                          = ["ns-1516.awsdns-61.org.", "ns-1831.awsdns-36.co.uk.", "ns-783.awsdns-33.net.", "ns-85.awsdns-10.com."]
  ttl                              = "172800"
  type                             = "NS"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com-002E-_SOA_" {
  multivalue_answer_routing_policy = "false"
  name                             = "agrovesto.com"
  records                          = ["ns-85.awsdns-10.com. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400"]
  ttl                              = "900"
  type                             = "SOA"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com-002E-_TXT_" {
  multivalue_answer_routing_policy = "false"
  name                             = "agrovesto.com"
  records                          = ["v=spf1 include:zohomail.com ~all"]
  ttl                              = "300"
  type                             = "TXT"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_agx-api-002E-agrovesto-002E-com-002E-_A_" {
  multivalue_answer_routing_policy = "false"
  name                             = "agx-api.agrovesto.com"
  records                          = ["34.254.5.223"]
  ttl                              = "300"
  type                             = "A"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_dev-agx-api-002E-agrovesto-002E-com-002E-_A_" {
  multivalue_answer_routing_policy = "false"
  name                             = "dev-agx-api.agrovesto.com"
  records                          = ["18.202.191.229"]
  ttl                              = "300"
  type                             = "A"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_dev-trade-002E-agrovesto-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "dev-trade.agrovesto.com"
  records                          = ["d1os5kbpqnqnxl.cloudfront.net"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_dev-vault-002E-agrovesto-002E-com-002E-_A_" {
  multivalue_answer_routing_policy = "false"
  name                             = "dev-vault.agrovesto.com"
  records                          = ["18.202.191.229"]
  ttl                              = "300"
  type                             = "A"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_h3vzvooabxmlfbcjdcwgce5as2df2gu4-002E-_domainkey-002E-agrovesto-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "h3vzvooabxmlfbcjdcwgce5as2df2gu4._domainkey.agrovesto.com"
  records                          = ["h3vzvooabxmlfbcjdcwgce5as2df2gu4.dkim.amazonses.com"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_nomaos-002E-agrovesto-002E-com-002E-_MX_" {
  multivalue_answer_routing_policy = "false"
  name                             = "nomaos.agrovesto.com"
  records                          = ["10 feedback-smtp.eu-west-1.amazonses.com"]
  ttl                              = "300"
  type                             = "MX"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_nomaos-002E-agrovesto-002E-com-002E-_TXT_" {
  multivalue_answer_routing_policy = "false"
  name                             = "nomaos.agrovesto.com"
  records                          = ["v=spf1 include:amazonses.com ~all"]
  ttl                              = "300"
  type                             = "TXT"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_shaaqbpf2v5gkwcb5t5msczm4gmcqibz-002E-_domainkey-002E-agrovesto-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "shaaqbpf2v5gkwcb5t5msczm4gmcqibz._domainkey.agrovesto.com"
  records                          = ["shaaqbpf2v5gkwcb5t5msczm4gmcqibz.dkim.amazonses.com"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_sonar-002E-agrovesto-002E-com-002E-_A_" {
  multivalue_answer_routing_policy = "false"
  name                             = "sonar.agrovesto.com"
  records                          = ["18.202.191.229"]
  ttl                              = "300"
  type                             = "A"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_trade-002E-agrovesto-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "trade.agrovesto.com"
  records                          = ["dvj1y21m1k5qo.cloudfront.net."]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_vault-002E-agrovesto-002E-com-002E-_A_" {
  multivalue_answer_routing_policy = "false"
  name                             = "vault.agrovesto.com"
  records                          = ["34.254.5.223"]
  ttl                              = "300"
  type                             = "A"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_www-002E-agrovesto-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "www.agrovesto.com"
  records                          = ["d3b7e9oz814lns.cloudfront.net"]
  ttl                              = "500"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_www-002E-agx-api-002E-agrovesto-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "www.agx-api.agrovesto.com"
  records                          = ["agx-api.agrovesto.com"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_www-002E-dev-agx-api-002E-agrovesto-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "www.dev-agx-api.agrovesto.com"
  records                          = ["dev-agx-api.agrovesto.com"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_www-002E-dev-trade-002E-agrovesto-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "www.dev-trade.agrovesto.com"
  records                          = ["d1os5kbpqnqnxl.cloudfront.net"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_www-002E-sonar-002E-agrovesto-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "www.sonar.agrovesto.com"
  records                          = ["sonar.agrovesto.com"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_www-002E-trade-002E-agrovesto-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "www.trade.agrovesto.com"
  records                          = ["dvj1y21m1k5qo.cloudfront.net"]
  ttl                              = "500"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z00055662LTUSSMS5ZA84_wybbx4m27i66wkku2wfdtpz3s6x7c4lu-002E-_domainkey-002E-agrovesto-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "wybbx4m27i66wkku2wfdtpz3s6x7c4lu._domainkey.agrovesto.com"
  records                          = ["wybbx4m27i66wkku2wfdtpz3s6x7c4lu.dkim.amazonses.com"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z00055662LTUSSMS5ZA84_agrovesto-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F__003994dac3d9b5b5aec2180e8831ef16-002E-onboarding-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_003994dac3d9b5b5aec2180e8831ef16.onboarding.nomaos.com"
  records                          = ["_bb3f0aeab5b27c7a6f3ede8c587d6def.jkddzztszm.acm-validations.aws."]
  ttl                              = "500"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F__21c604054a7b42a2d1869527fda5264b-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_21c604054a7b42a2d1869527fda5264b.nomaos.com"
  records                          = ["_34643daca7c2c355690767241796f33d.xlfgrmvvlj.acm-validations.aws."]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F__8040315a68aea0952c20b22f523efd2d-002E-www-dev-noma-api-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_8040315a68aea0952c20b22f523efd2d.www-dev-noma-api.nomaos.com"
  records                          = ["_a0fc05bd3983b918f4781076bc949e3d.jkddzztszm.acm-validations.aws."]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F__91fc180fda9b17e5ac01054a5ac1b09e-002E-www-002E-dev-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_91fc180fda9b17e5ac01054a5ac1b09e.www.dev.nomaos.com"
  records                          = ["_59ab9c2eb8d334ad1f89edf0bc73d2bd.jkddzztszm.acm-validations.aws."]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F__9432a8bd2967acc353043ba99c1cf51f-002E-dev-insight-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_9432a8bd2967acc353043ba99c1cf51f.dev-insight.nomaos.com"
  records                          = ["_41c75ed414157d9a121fb6e46b40f3d0.jkddzztszm.acm-validations.aws."]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F__9c359aa511561dfe22359dae04e56bb8-002E-dev-onboarding-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_9c359aa511561dfe22359dae04e56bb8.dev-onboarding.nomaos.com"
  records                          = ["_a0c3ea62e2d1ed61c77d690c64a2143d.jkddzztszm.acm-validations.aws."]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F__ad031d7975f933304c898b093cf97a13-002E-dev-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_ad031d7975f933304c898b093cf97a13.dev.nomaos.com"
  records                          = ["_1218583aaea73987e16b14ae1b308e2c.jkddzztszm.acm-validations.aws."]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F__b86aa32860f202c7a419287fee43c891-002E-dev-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_b86aa32860f202c7a419287fee43c891.dev.nomaos.com"
  records                          = ["_5c672f7508f2c5c1772c53cce93f27a9.jkddzztszm.acm-validations.aws."]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F__be1ccaf597b95d30f8b2a4a5ddd5ad21-002E-insight-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_be1ccaf597b95d30f8b2a4a5ddd5ad21.insight.nomaos.com"
  records                          = ["_15bb0d6b5e745542a6d691b185ba5034.jkddzztszm.acm-validations.aws."]
  ttl                              = "500"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F__d02911d2d0d21a1c67455d6b7c6750fd-002E-preview-onboarding-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_d02911d2d0d21a1c67455d6b7c6750fd.preview-onboarding.nomaos.com"
  records                          = ["_5d2f027a13c99697ebe043ae7da16b2c.jkddzztszm.acm-validations.aws."]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F__e2b97be0df5e67759503308bd6488206-002E-www-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_e2b97be0df5e67759503308bd6488206.www.nomaos.com"
  records                          = ["_f6b86906651ae2bcac06f579553ebdfe.jkddzztszm.acm-validations.aws."]
  ttl                              = "500"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F__eea287f925f941d979d9d8708d84c416-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_eea287f925f941d979d9d8708d84c416.nomaos.com"
  records                          = ["_8753804db3b3678216900ad038ca8ca0.xlfgrmvvlj.acm-validations.aws."]
  ttl                              = "500"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F__f0cabfaa8df2cfb883e868beb61de1f9-002E-dev-noma-api-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_f0cabfaa8df2cfb883e868beb61de1f9.dev-noma-api.nomaos.com"
  records                          = ["_f4a6834692d913a280fe699e913e0bf1.jkddzztszm.acm-validations.aws."]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_dev-insight-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "dev-insight.nomaos.com"
  records                          = ["dryvsr8uwghc7.cloudfront.net"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_dev-noma-api-002E-nomaos-002E-com-002E-_A_" {
  multivalue_answer_routing_policy = "false"
  name                             = "dev-noma-api.nomaos.com"
  records                          = ["18.202.191.229"]
  ttl                              = "300"
  type                             = "A"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_dev-onboarding-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "dev-onboarding.nomaos.com"
  records                          = ["d2j1qezyk8m4xp.cloudfront.net"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_google-site-verification-002E-nomaos-002E-com-002E-_TXT_" {
  multivalue_answer_routing_policy = "false"
  name                             = "google-site-verification.nomaos.com"
  records                          = ["=oMp8cg0oByFPRYGxoQi9Qgen8P2zfKkukOMePXY5sL8"]
  ttl                              = "300"
  type                             = "TXT"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_insight-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "insight.nomaos.com"
  records                          = ["d263y9ncwxp8uu.cloudfront.net"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_monitoring-002E-nomaos-002E-com-002E-_A_" {
  multivalue_answer_routing_policy = "false"
  name                             = "monitoring.nomaos.com"
  records                          = ["18.202.191.229"]
  ttl                              = "300"
  type                             = "A"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_noma-api-002E-nomaos-002E-com-002E-_A_" {
  multivalue_answer_routing_policy = "false"
  name                             = "noma-api.nomaos.com"
  records                          = ["34.254.5.223"]
  ttl                              = "300"
  type                             = "A"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com-002E-_A_" {
  alias {
    evaluate_target_health = "false"
    name                   = "d1ibp586fw2be5.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
  }

  multivalue_answer_routing_policy = "false"
  name                             = "nomaos.com"
  type                             = "A"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com-002E-_NS_" {
  multivalue_answer_routing_policy = "false"
  name                             = "nomaos.com"
  records                          = ["ns-1145.awsdns-15.org.", "ns-152.awsdns-19.com.", "ns-1959.awsdns-52.co.uk.", "ns-707.awsdns-24.net."]
  ttl                              = "172800"
  type                             = "NS"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com-002E-_SOA_" {
  multivalue_answer_routing_policy = "false"
  name                             = "nomaos.com"
  records                          = ["ns-707.awsdns-24.net. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400"]
  ttl                              = "900"
  type                             = "SOA"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_onboarding-002E-nomaos-002E-com-002E-_A_" {
  alias {
    evaluate_target_health = "false"
    name                   = "d2naoyi3nerpqw.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
  }

  multivalue_answer_routing_policy = "false"
  name                             = "onboarding.nomaos.com"
  type                             = "A"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_preview-onboarding-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "preview-onboarding.nomaos.com"
  records                          = ["d1y5a32bfenu2k.cloudfront.net"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_release-noma-api-002E-nomaos-002E-com-002E-_A_" {
  multivalue_answer_routing_policy = "false"
  name                             = "release-noma-api.nomaos.com"
  records                          = ["108.130.232.124"]
  ttl                              = "300"
  type                             = "A"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_www-002E-dev-insight-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "www.dev-insight.nomaos.com"
  records                          = ["dryvsr8uwghc7.cloudfront.net"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_www-002E-dev-noma-api-002E-nomaos-002E-com-002E-_A_" {
  multivalue_answer_routing_policy = "false"
  name                             = "www.dev-noma-api.nomaos.com"
  records                          = ["18.202.191.229"]
  ttl                              = "300"
  type                             = "A"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_www-002E-dev-onboarding-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "www.dev-onboarding.nomaos.com"
  records                          = ["d2j1qezyk8m4xp.cloudfront.net"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_www-002E-insight-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "www.insight.nomaos.com"
  records                          = ["d263y9ncwxp8uu.cloudfront.net"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_www-002E-monitoring-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "www.monitoring.nomaos.com"
  records                          = ["monitoring.nomaos.com"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_www-002E-noma-api-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "www.noma-api.nomaos.com"
  records                          = ["noma-api.nomaos.com"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_www-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "www.nomaos.com"
  records                          = ["d1ibp586fw2be5.cloudfront.net"]
  ttl                              = "500"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_www-002E-onboarding-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "www.onboarding.nomaos.com"
  records                          = ["d2naoyi3nerpqw.cloudfront.net"]
  ttl                              = "500"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_www-002E-preview-onboarding-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "www.preview-onboarding.nomaos.com"
  records                          = ["d1y5a32bfenu2k.cloudfront.net"]
  ttl                              = "300"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z0208643NZ0W8WF5RQ9F_www-002E-release-noma-api-002E-nomaos-002E-com-002E-_A_" {
  multivalue_answer_routing_policy = "false"
  name                             = "www.release-noma-api.nomaos.com"
  records                          = ["108.130.232.124"]
  ttl                              = "300"
  type                             = "A"
  zone_id                          = "${aws_route53_zone.tfer--Z0208643NZ0W8WF5RQ9F_nomaos-002E-com.zone_id}"
}
