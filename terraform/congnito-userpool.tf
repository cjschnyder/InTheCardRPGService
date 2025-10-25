resource "aws_cognito_user_pool" "in_the_cards_user_pool" {
  name = "InTheCardsUserPool"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 7
  }

  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    
    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }
  schema {
    name                     = "name"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    
    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Your In The Cards RPG verification code"
    email_message        = "Your verification code for In The Cards RPG is {####}"
  }
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }
  mfa_configuration = "OPTIONAL"
  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  tags = {
    Name        = "InTheCards User Pool"
    Project     = "InTheCardsRPG"
    ManagedBy   = "Terraform"
  }
}

resource "aws_cognito_user_pool_client" "in_the_cards_web_client" {
  name         = "InTheCardsWebClient"
  user_pool_id = aws_cognito_user_pool.main.id
  generate_secret = false

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  callback_urls = [
    "http://localhost:5173/auth/callback",     
    "https://handlemydeck.com/auth/callback"
  ]

  logout_urls = [
    "http://localhost:5173",
    "https://handlemydeck.com"                   
  ]

  supported_identity_providers = ["COGNITO", "Google"]

  refresh_token_validity = 30
  access_token_validity  = 60
  id_token_validity      = 60
  token_validity_units {
    refresh_token = "days"
    access_token  = "minutes"
    id_token      = "minutes"
  }


  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]
  prevent_user_existence_errors = "ENABLED"
  read_attributes = [
    "email",
    "email_verified",
    "name"
  ]
  write_attributes = [
    "email",
    "name"
  ]
}

data "aws_secretsmanager_secret" "google_oauth" {
  name = "in-the-cards/google-creds"
}

data "aws_secretsmanager_secret_version" "google_oauth" {
  secret_id = data.aws_secretsmanager_secret.google_oauth.id
}

locals {
  google_oauth_credentials = jsondecode(data.aws_secretsmanager_secret_version.google_oauth.secret_string)
}

# Google Identity Provider
resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"

  # Credentials pulled from AWS Secrets Manager
  provider_details = {
    authorize_scopes = "email profile openid"
    client_id        = local.google_oauth_credentials.client_id
    client_secret    = local.google_oauth_credentials.client_secret
  }

  # Map Google attributes to Cognito attributes
  attribute_mapping = {
    email    = "email"
    name     = "name"
    username = "sub"
  }
}

# User Pool Domain (required for Google OAuth)
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "itc-rpg-${var.environment}-${random_string.domain_suffix.result}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# Random string for unique domain name
resource "random_string" "domain_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Outputs
output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.in_the_cards_user_pool.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.in_the_cards_user_pool.arn
}

output "user_pool_endpoint" {
  description = "Endpoint of the Cognito User Pool"
  value       = aws_cognito_user_pool.in_the_cards_user_pool.endpoint
}

output "user_pool_client_id" {
  description = "ID of the User Pool Client"
  value       = aws_cognito_user_pool_client.web_client.id
}

output "cognito_domain" {
  description = "Cognito domain for OAuth flows"
  value       = aws_cognito_user_pool_domain.in_the_cards_user_pool.domain
}

output "cognito_oauth_url" {
  description = "Base URL for Cognito OAuth endpoints"
  value       = "https://${aws_cognito_user_pool_domain.in_the_cards_user_pool.domain}.auth.${var.aws_region}.amazoncognito.com"
}