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
  mfa_configuration = "OFF"
  
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
  user_pool_id = aws_cognito_user_pool.in_the_cards_user_pool.id
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

resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.in_the_cards_user_pool.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    authorize_scopes = "email profile openid"
    client_id        = local.google_oauth_credentials.client_id
    client_secret    = local.google_oauth_credentials.client_secret
  }

  attribute_mapping = {
    email    = "email"
    name     = "name"
    username = "sub"
  }
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "inthecards-rpg"
  user_pool_id = aws_cognito_user_pool.in_the_cards_user_pool.id
}

resource "aws_cognito_identity_pool" "in_the_cards_identity_pool" {
  identity_pool_name               = "InTheCardsIdentityPool"
  allow_unauthenticated_identities = false
  allow_classic_flow               = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.in_the_cards_web_client.id
    provider_name           = aws_cognito_user_pool.in_the_cards_user_pool.endpoint
    server_side_token_check = false
  }

  supported_login_providers = {
    "accounts.google.com" = local.google_oauth_credentials.client_id
  }

  tags = {
    Name      = "InTheCards Identity Pool"
    Project   = "InTheCardsRPG"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role" "authenticated_role" {
  name = "InTheCardsCognitoAuthenticatedRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.in_the_cards_identity_pool.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "InTheCards Authenticated Role"
    Project   = "InTheCardsRPG"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy" "authenticated_dyanmodb_policy" {
  name = "InTheCardsAuthenticatedPolicy"
  role = aws_iam_role.authenticated_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.users.arn,
          "${aws_dynamodb_table.users.arn}/index/*",
          aws_dynamodb_table.characters.arn,
          "${aws_dynamodb_table.characters.arn}/index/*"
        ]
        Condition = {
          "ForAllValues:StringEquals" = {
            "dynamodb:LeadingKeys" = ["$${cognito-identity.amazonaws.com:sub}"]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "unauthenticated_role" {
  name = "InTheCards_Cognito_Unauthenticated_Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.in_the_cards_identity_pool.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "unauthenticated"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "InTheCards Unauthenticated Role"
    Project   = "InTheCardsRPG"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy" "unauthenticated_policy" {
  name = "InTheCards_Unauthenticated_Policy"
  role = aws_iam_role.unauthenticated_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "mobileanalytics:PutEvents",
          "cognito-sync:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cognito_identity_pool_roles_attachment" "attach_roles" {
  identity_pool_id = aws_cognito_identity_pool.in_the_cards_identity_pool.id

  roles = {
    authenticated   = aws_iam_role.authenticated_role.arn
    unauthenticated = aws_iam_role.unauthenticated_role.arn
  }
}