resource "aws_route53_record" "tfer--Z04841994LNF5EA00ZEG__ad031d7975f933304c898b093cf97a13-002E-dev-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "_ad031d7975f933304c898b093cf97a13.dev.nomaos.com"
  records                          = ["_1218583aaea73987e16b14ae1b308e2c.jkddzztszm.acm-validations.aws."]
  ttl                              = "500"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z04841994LNF5EA00ZEG_dev-002E-nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z04841994LNF5EA00ZEG_dev-002E-nomaos-002E-com-002E-_A_" {
  alias {
    evaluate_target_health = "false"
    name                   = "d2xu37rmuxqerk.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
  }

  multivalue_answer_routing_policy = "false"
  name                             = "dev.nomaos.com"
  type                             = "A"
  zone_id                          = "${aws_route53_zone.tfer--Z04841994LNF5EA00ZEG_dev-002E-nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z04841994LNF5EA00ZEG_dev-002E-nomaos-002E-com-002E-_NS_" {
  multivalue_answer_routing_policy = "false"
  name                             = "dev.nomaos.com"
  records                          = ["ns-1081.awsdns-07.org.", "ns-1751.awsdns-26.co.uk.", "ns-188.awsdns-23.com.", "ns-529.awsdns-02.net."]
  ttl                              = "172800"
  type                             = "NS"
  zone_id                          = "${aws_route53_zone.tfer--Z04841994LNF5EA00ZEG_dev-002E-nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z04841994LNF5EA00ZEG_dev-002E-nomaos-002E-com-002E-_SOA_" {
  multivalue_answer_routing_policy = "false"
  name                             = "dev.nomaos.com"
  records                          = ["ns-529.awsdns-02.net. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400"]
  ttl                              = "900"
  type                             = "SOA"
  zone_id                          = "${aws_route53_zone.tfer--Z04841994LNF5EA00ZEG_dev-002E-nomaos-002E-com.zone_id}"
}

resource "aws_route53_record" "tfer--Z04841994LNF5EA00ZEG_www-002E-dev-002E-nomaos-002E-com-002E-_CNAME_" {
  multivalue_answer_routing_policy = "false"
  name                             = "www.dev.nomaos.com"
  records                          = ["d2xu37rmuxqerk.cloudfront.net"]
  ttl                              = "500"
  type                             = "CNAME"
  zone_id                          = "${aws_route53_zone.tfer--Z04841994LNF5EA00ZEG_dev-002E-nomaos-002E-com.zone_id}"
}
