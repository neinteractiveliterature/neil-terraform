
resource "aws_iam_role" "lambda_edge_role" {
  assume_role_policy    = jsonencode(
    {
      Statement = [
        {
          Action    = "sts:AssumeRole"
          Effect    = "Allow"
          Principal = {
            Service = [
              "lambda.amazonaws.com",
              "edgelambda.amazonaws.com",
            ]
          }
        },
      ]
      Version   = "2012-10-17"
    }
  )
  path = "/service-role/"
}

resource "aws_lambda_function" "addSecurityHeaders" {
  description   = "Blueprint for modifying CloudFront response header implemented in NodeJS."
  filename      = "lambda/addSecurityHeaders.zip"
  source_code_hash = filebase64sha256("lambda/addSecurityHeaders.zip")
  function_name = "arn:aws:lambda:us-east-1:689053117832:function:addSecurityHeaders"
  handler       = "index.handler"
  role          = aws_iam_role.lambda_edge_role.arn
  runtime       = "nodejs10.x"
  timeout       = 1

  tags = {
    "lambda-console:blueprint" = "cloudfront-modify-response-header"
  }
}
