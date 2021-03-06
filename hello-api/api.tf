module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "poc-function"
  description   = "POC lambda hello world"
  handler       = "app.lambdaHandler"
  runtime       = "nodejs14.x"

  source_path = [
    {
      path = "${path.module}/POCFunction"
      commands = ["npm install --only prod --no-bin-links --no-fund", ":zip"]
    }
  ]
}

data "template_file" "poc-hello-definition" {
  template = file("${path.module}/api_gateway_definition.json")

  vars = {
    lambda_invocation_arn = module.lambda_function.lambda_function_invoke_arn
  }
}

resource "aws_api_gateway_rest_api" "poc-hello-rest-api" {
  body = data.template_file.poc-hello-definition.rendered

  name = "poc-hello-rest-api"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "poc-hello-gateway-deployment" {
  rest_api_id = aws_api_gateway_rest_api.poc-hello-rest-api.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.poc-hello-rest-api.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "poc-hello-gateway-stage" {
  deployment_id = aws_api_gateway_deployment.poc-hello-gateway-deployment.id
  rest_api_id   = aws_api_gateway_rest_api.poc-hello-rest-api.id
  stage_name    = "dev"
}

resource "aws_ssm_parameter" "poc-hello-gateway-endpoint" {
  name    = "/poc-hello-gateway/endpoint"
  value   = aws_api_gateway_stage.poc-hello-gateway-stage.invoke_url
  type    = "String"
}

output "endpoint" {
  value = aws_api_gateway_stage.poc-hello-gateway-stage.invoke_url
}
