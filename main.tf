provider "aws" {
    region = "us-east-1"
    profile = "evan-personal"
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

resource "aws_s3_bucket" "sheltie_image_comparison_bucket" {
    bucket = "sheltie-image-comparison-bucket"
}

resource "aws_s3_bucket_policy" "sheltie_image_bucket_policy" {
  bucket = aws_s3_bucket.sheltie_image_comparison_bucket.id
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Principal = {
          AWS = aws_iam_role.sheltie_image_role.arn
        },
        Action   = "s3:GetObject",
        Resource = "${aws_s3_bucket.sheltie_image_comparison_bucket.arn}/*"
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
          "${aws_s3_bucket.sheltie_image_comparison_bucket.arn}",
          "${aws_s3_bucket.sheltie_image_comparison_bucket.arn}/*"
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
    filename      = "./lambda/sheltie_determinator_function.zip"
    function_name = "sheltie_determination_function"
    role          = aws_iam_role.sheltie_image_role.arn
    handler       = "lambda_function.lambda_handler"
    runtime       = "python3.9"
    timeout       = 10 
    memory_size   = 256  
}

resource "aws_api_gateway_api_key" "sheltie_api_key" {
  name = "SheltieAPIKey"
  description = "API key for Sheltie Image Recognition"
  enabled = true
}


resource "aws_api_gateway_rest_api" "sheltie_api" {
  name        = "IsItASheltieAPI"
  description = "API for Sheltie Image Recognition"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_lambda_permission" "sheltie_api_lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sheltie_image_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.sheltie_api.execution_arn}/*/*"
}

resource "aws_api_gateway_resource" "sheltie_resource" {
  rest_api_id = aws_api_gateway_rest_api.sheltie_api.id
  parent_id   = aws_api_gateway_rest_api.sheltie_api.root_resource_id
  path_part   = "image"
}

resource "aws_api_gateway_method" "sheltie_post_method" {
  rest_api_id   = aws_api_gateway_rest_api.sheltie_api.id
  resource_id   = aws_api_gateway_resource.sheltie_resource.id
  http_method   = "POST"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "sheltie_lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.sheltie_api.id
  resource_id = aws_api_gateway_method.sheltie_post_method.resource_id
  http_method = aws_api_gateway_method.sheltie_post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.sheltie_image_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "sheltie_api_deployment" {
  depends_on  = [aws_api_gateway_integration.sheltie_lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.sheltie_api.id
  stage_name  = "stage"
  description = "Deploying the API for Sheltie Recognition"
  stage_description = "Stage"
}

resource "aws_api_gateway_usage_plan" "sheltie_usage_plan" {
  name        = "SheltieUsagePlan"
  description = "Usage plan for Sheltie API"

  api_stages {
    api_id = aws_api_gateway_rest_api.sheltie_api.id
    stage  = aws_api_gateway_deployment.sheltie_api_deployment.stage_name
  }
}

resource "aws_api_gateway_usage_plan_key" "sheltie_usage_plan_key" {
  key_id        = aws_api_gateway_api_key.sheltie_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.sheltie_usage_plan.id
}

output "api_endpoint" {
  value = "${aws_api_gateway_deployment.sheltie_api_deployment.invoke_url}/image"
}






