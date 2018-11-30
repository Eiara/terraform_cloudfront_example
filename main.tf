locals {
  log_bucket = "my-logging-bucket-name"
  secondary_bucket = "secondary-cloudfront-serve-bucket"
  tertiary_bucket = "tertiary-cloudfront-serve-bucket"
}

data "aws_caller_identity" "primary" {
  provider = "aws.primary"
}

data "aws_caller_identity" "secondary" {
  provider = "aws.secondary"
}

data "aws_caller_identity" "tertiary" {
  provider = "aws.tertiary"
}

provider "aws" {
  region = "ap-southeast-2"
}

provider "aws" {
  alias   = "primary"
  profile = "primary"
  region = "ap-southeast-2"
}

provider "aws" {
  alias   = "secondary"
  profile = "secondary"
  region = "ap-southeast-2"
}

provider "aws" {
  alias   = "tertiary"
  profile = "tertiary"
  region = "ap-southeast-2"
}

resource "aws_s3_bucket" "server_secondary" {
  provider = "aws.secondary"
  bucket   = "${local.secondary_bucket}"

  website {
    index_document = "index.html"
  }
  policy = "${data.aws_iam_policy_document.bucket_policy_read_secondary.json}"
}

resource "aws_s3_bucket" "server_tertiary" {
  provider = "aws.tertiary"
  bucket   = "${local.tertiary_bucket}"

  website {
    index_document = "index.html"
  }
  policy = "${data.aws_iam_policy_document.bucket_policy_read_tertiary.json}"
}

resource "aws_s3_bucket" "logs" {
  provider = "aws.primary"
  bucket   = "${local.log_bucket}"
  acl      = "private"
  policy   = "${data.aws_iam_policy_document.bucket_policy.json}"
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    actions = [
      "s3:GetBucketACL",
      "s3:PutBucketACL",
    ]

    resources = [
      "arn:aws:s3:::${local.log_bucket}",
    ]

    principals {
      type = "AWS"

      identifiers = [
        "${data.aws_caller_identity.secondary.account_id}",
        "${data.aws_caller_identity.tertiary.account_id}",
      ]
    }
  }
}


data "aws_iam_policy_document" "bucket_policy_read_secondary" {
  # Cloudfront can read anything
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${local.secondary_bucket}/*"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.s3_access_secondary.iam_arn}"]
    }
  }
  
  # Cloudfront can list the bucket
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.secondary_bucket}"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.s3_access_secondary.iam_arn}"]
    }
  }
}

data "aws_iam_policy_document" "bucket_policy_read_tertiary" {
  # Cloudfront can read anything
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${local.tertiary_bucket}/*"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.s3_access_tertiary.iam_arn}", "*"]
    }
  }
  
  # Cloudfront can list the bucket
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.tertiary_bucket}"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.s3_access_tertiary.iam_arn}"]
    }
  }
}

resource "aws_cloudfront_origin_access_identity" "s3_access_secondary" {
  provider = "aws.secondary"
  comment = "secondary identity"
}

resource "aws_cloudfront_origin_access_identity" "s3_access_tertiary" {
  provider = "aws.tertiary"
  comment = "tertiary identity"
}

resource "aws_cloudfront_distribution" "s3_distribution_secondary" {
  
  provider = "aws.secondary"
  
  origin {
    domain_name = "${aws_s3_bucket.server_secondary.bucket_domain_name}"
    origin_id   = "secondary_origin"
    s3_origin_config {
      origin_access_identity = "${aws_cloudfront_origin_access_identity.s3_access_secondary.cloudfront_access_identity_path}"
    }
  }

  enabled         = true
  
  logging_config {
    include_cookies = false
    bucket          = "${aws_s3_bucket.logs.bucket_domain_name}"
    prefix          = "secondary-cloudfront-logs"
  }
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "secondary_origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress = true
  }
  price_class = "PriceClass_All"
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_distribution" "s3_distribution_tertiary" {
  
  provider = "aws.tertiary"
  
  origin {
    domain_name = "${aws_s3_bucket.server_tertiary.bucket_domain_name}"
    origin_id   = "tertiary_origin"
    s3_origin_config {
      origin_access_identity = "${aws_cloudfront_origin_access_identity.s3_access_tertiary.cloudfront_access_identity_path}"
    }
  }

  enabled         = true

  logging_config {
    include_cookies = false
    bucket          = "${aws_s3_bucket.logs.bucket_domain_name}"
    prefix          = "logs-tertiary"
  }
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "tertiary_origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress = true
  }
  price_class = "PriceClass_All"
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
