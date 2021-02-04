# output bucket name so deflow can add it to the state
output "dest" {
  value = [ aws_s3_bucket.source-bucket.arn, aws_s3_bucket.destination-bucket.arn ]
}