provider "aws" {
    region = "us-east-1"
    profile = "default"
}


resource "aws_iam_role" "sheltie_image_role" {
  name = "sheltie-image-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })
}

resource "aws_s3_bucket" "sheltie_image_bucket" {
    bucket = "sheltie-images"
}

resource "aws_s3_bucket_policy" "sheltie_image_bucket_policy" {
 bucket = aws_s3_bucket.sheltie_image_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Principal = aws_iam_role.sheltie_image_role.arn,
        Action   = "s3:GetObject",
        Resource = aws_s3_bucket.sheltie_image_bucket.arn
      }
    ]
  })
  
}

resource "aws_iam_policy" "sheltie_image_read_policy" {
  name        = "sheltie-image-read-policy"
  description = "Policy that allows Lambda to read from a sheltie S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          "${aws_s3_bucket.sheltie_image_bucket.arn}",
          "${aws_s3_bucket.sheltie_image_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sheltie_image_read_policy_attachment" {
  policy_arn = aws_iam_policy.sheltie_image_read_policy.arn
  role       = aws_iam_role.sheltie_image_role.name
}

resource "aws_lambda_function" "sheltie_image_lambda" {
    filename      = "lambda_function_payload.zip"
    function_name = "sheltie_determination_function"
    role          = aws_iam_role.sheltie_image_role.arn
    handler       = "lambda_function.lambda_handler"
    runtime       = "python3.9"
    timeout       = 10 
    memory_size   = 256  
}


