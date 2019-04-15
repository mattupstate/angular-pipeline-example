variable "target_version" {
  type = "string"
}

provider "aws" {}
provider "dnsimple" {}
provider "fastly" {}

terraform {
  backend "s3" {
    region = "us-east-2"
    bucket = "tfstate.mattupstate.com"
    key    = "angular-pipeline-example.mattupstate.com/resources.tfstate"
  }
}

data "fastly_ip_ranges" "fastly" {}

resource "aws_s3_bucket" "website" {
  bucket = "angular-pipeline-example.mattupstate.com"
  acl    = "private"
  region = "us-east-2"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

resource "aws_s3_bucket_policy" "fastly_access" {
  bucket = "${aws_s3_bucket.website.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "${aws_s3_bucket.website.arn}/*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": ${jsonencode(data.fastly_ip_ranges.fastly.cidr_blocks)}
        }
      }
    }
  ]
}
POLICY
}

resource "aws_s3_bucket_object" "error_page" {
  bucket  = "angular-pipeline-example.mattupstate.com"
  key     = "error.html"
  content = "${file("${path.module}/error.html")}"
  acl     = "public-read"
}

resource "dnsimple_record" "website" {
  name   = "angular-pipeline-example"
  domain = "mattupstate.com"
  type   = "CNAME"
  value  = "nonssl.global.fastly.net"
  ttl    = 3600
}

resource "dnsimple_record" "versioned_website" {
  name   = "*.angular-pipeline-example"
  domain = "mattupstate.com"
  type   = "CNAME"
  value  = "nonssl.global.fastly.net"
  ttl    = 3600
}

data "template_file" "fastly_vcl" {
  template = "${file("${path.module}/fastly.vcl.tpl")}"
  vars = {
    target_version = "${var.target_version}"
  }
}

resource "fastly_service_v1" "website" {
  name          = "angular-pipeline-example.mattupstate.com"
  default_host  = "${aws_s3_bucket.website.website_endpoint}"
  force_destroy = true

  domain {
    name    = "angular-pipeline-example.mattupstate.com"
    comment = "Default site"
  }

  domain {
    name    = "*.angular-pipeline-example.mattupstate.com"
    comment = "Versioned site"
  }

  backend {
    address = "${aws_s3_bucket.website.website_endpoint}"
    name    = "AWS S3"
    port    = 80
  }

  vcl {
    name    = "my_custom_main_vcl"
    content = "${data.template_file.fastly_vcl.rendered}"
    main    = true
  }
}

output "s3_bucket_website_endpoint" {
  value = "${aws_s3_bucket.website.website_endpoint}"
}

output "fastly_service_id" {
  value = "${fastly_service_v1.website.id}"
}

output "fastly_service_active_version" {
  value = "${fastly_service_v1.website.active_version}"
}
