# data "aws_s3_bucket" "bucket_aws_east" {
#   depends_on = ["aws_s3_bucket.source-bucket"]
#   bucket = "khymera-source-s3-bucket-to-test-crr"
# }

# data "aws_s3_bucket" "bucket_aws_west" {
#   depends_on = ["aws_s3_bucket.destination-bucket"]
#   bucket = "khymera-destination-s3-bucket-to-test-crr"
# }

data "external" "bucket_aws_east" {
  program = ["/bin/bash", "-c", "aws s3api list-buckets --query 'Buckets[?contains(Name, `khymera-source-s3-bucket-to-test-crr`)] | [0]' "]
}

data "external" "bucket_aws_west" {
  program = ["/bin/bash", "-c", "aws s3api list-buckets --query 'Buckets[?contains(Name, `khymera-destination-s3-bucket-to-test-crr`)] | [0]' "]
}


locals{
  # does_source_bucket_exist = [false]
  # does_destination_bucket_exist = [false]
  # does_source_bucket_exist = [data.aws_s3_bucket.bucket_aws_east ? true : false]
  # does_destination_bucket_exist = [data.aws_s3_bucket.bucket_aws_west ? true : false]
  # does_source_bucket_exist = [data.external.bucket_aws_east ? true : false]
  # does_destination_bucket_exist = [data.external.bucket_aws_west ? true : false]
  does_source_bucket_exist = length(keys(data.external.bucket_aws_east.result)) > 0 ? [1] : []
  does_destination_bucket_exist = length(keys(data.external.bucket_aws_west.result)) > 0 ? [1] : []
}

provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias = "west"
  region = "us-west-2"
}

resource "aws_iam_policy_attachment" "replication" {
  name       = "khymera-tf-iam-role-attachment-replication-12345"
  roles      = [aws_iam_role.replication-role.name]
  policy_arn = aws_iam_policy.replication-policy.arn
}

resource "aws_iam_role" "replication-role" {
  name = "khymera-replication-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "replication-policy" {
  name = "khymera-replication-policy"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetReplicationConfiguration",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.source-bucket.arn}"
      ]
    },
    {
      "Action": [
        "s3:GetObjectVersion",
        "s3:GetObjectVersionAcl"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.source-bucket.arn}/*"
      ]
    },
    {
      "Action": [
        "s3:ReplicateObject",
        "s3:ReplicateDelete"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.destination-bucket.arn}/*"
    }
  ]
}
POLICY
}

resource "aws_s3_bucket" "source-bucket" {
  provider = aws
  bucket   = "khymera-source-s3-bucket-to-test-crr"
  acl      = "private"

  versioning {
    enabled = true
  }

  dynamic "replication_configuration" {
    for_each = local.does_destination_bucket_exist
    content{
      role = aws_iam_role.replication-role.arn
      rules {
          prefix = ""
          status = "Enabled"
        destination {
          # this line has to be changed -- AWS partinion would be different for china
              bucket        = "arn:aws:s3:::${data.external.bucket_aws_west.result.Name}"
              storage_class = "STANDARD"
            }
          }
        }
    }
}

resource "aws_s3_bucket" "destination-bucket" {
  provider = aws.west
  bucket = "khymera-destination-s3-bucket-to-test-crr"

  versioning {
    enabled = true
  }

  dynamic "replication_configuration" {
    for_each = local.does_source_bucket_exist
    content{
      role = aws_iam_role.replication-role.arn

          rules {
            prefix = ""
            status = "Enabled"

            destination {
              # this line has to be changed -- AWS partinion would be different for china
              bucket        = "arn:aws:s3:::${data.external.bucket_aws_east.result.Name}"
              storage_class = "STANDARD"
            }
          }
        }
    }
}
