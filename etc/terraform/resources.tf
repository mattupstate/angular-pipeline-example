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

resource "aws_s3_bucket" "website" {
  bucket = "angular-pipeline-example.mattupstate.com"
  acl    = "public-read"
  region = "us-east-2"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
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
    content = "${file("${path.module}/fastly.vcl")}"
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
