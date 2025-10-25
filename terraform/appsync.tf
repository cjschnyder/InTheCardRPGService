resource "aws_appsync_graphql_api" "in_the_cards_api" {
  name                = "InTheCardsGraphQLAPI"
  authentication_type = "AMAZON_COGNITO_USER_POOLS"

  user_pool_config {
    user_pool_id   = aws_cognito_user_pool.in_the_cards_user_pool.id
    default_action = "ALLOW"
  }

  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ERROR"
    exclude_verbose_content  = false
  }

  schema = file("${path.module}/resources/schema.graphql")

  tags = {
    Name      = "InTheCards GraphQL API"
    Project   = "InTheCardsRPG"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role" "appsync_dynamodb" {
  name = "InTheCardsAppSyncDynamoDBRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "appsync.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name      = "InTheCards AppSync DynamoDB Role"
    Project   = "InTheCardsRPG"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy" "appsync_dynamodb_policy" {
  name = "InTheCardsAppSyncDynamoDBPolicy"
  role = aws_iam_role.appsync_dynamodb.id

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
      }
    ]
  })
}

resource "aws_iam_role" "appsync_logs" {
  name = "InTheCardsAppSyncLogsRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "appsync.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name      = "InTheCards AppSync Logs Role"
    Project   = "InTheCardsRPG"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy" "appsync_logs_policy" {
  name = "InTheCardsAppSyncLogsPolicy"
  role = aws_iam_role.appsync_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_appsync_datasource" "characters_table" {
  api_id           = aws_appsync_graphql_api.in_the_cards_api.id
  name             = "CharactersTable"
  service_role_arn = aws_iam_role.appsync_dynamodb.arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = aws_dynamodb_table.characters.name
  }
}

resource "aws_appsync_datasource" "users_table" {
  api_id           = aws_appsync_graphql_api.in_the_cards_api.id
  name             = "UsersTable"
  service_role_arn = aws_iam_role.appsync_dynamodb.arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = aws_dynamodb_table.users.name
  }
}

resource "aws_appsync_resolver" "get_character" {
  api_id      = aws_appsync_graphql_api.in_the_cards_api.id
  type        = "Query"
  field       = "getCharacter"
  data_source = aws_appsync_datasource.characters_table.name

  code = file("${path.module}/resources/getCharacter.js")

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
}

# Resolver - listCharacters
resource "aws_appsync_resolver" "list_characters" {
  api_id      = aws_appsync_graphql_api.in_the_cards_api.id
  type        = "Query"
  field       = "listCharacters"
  data_source = aws_appsync_datasource.characters_table.name

  code = file("${path.module}/resources/listCharacters.js")

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
}

# Resolver - createCharacter
resource "aws_appsync_resolver" "create_character" {
  api_id      = aws_appsync_graphql_api.in_the_cards_api.id
  type        = "Mutation"
  field       = "createCharacter"
  data_source = aws_appsync_datasource.characters_table.name

  code = file("${path.module}/resources/createCharacter.js")

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
}

# Resolver - updateCharacter
resource "aws_appsync_resolver" "update_character" {
  api_id      = aws_appsync_graphql_api.in_the_cards_api.id
  type        = "Mutation"
  field       = "updateCharacter"
  data_source = aws_appsync_datasource.characters_table.name

  code = file("${path.module}/resources/updateCharacter.js")

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
}

# Resolver - deleteCharacter
resource "aws_appsync_resolver" "delete_character" {
  api_id      = aws_appsync_graphql_api.in_the_cards_api.id
  type        = "Mutation"
  field       = "deleteCharacter"
  data_source = aws_appsync_datasource.characters_table.name

  code = file("${path.module}/resources/deleteCharacter.js")

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
}

resource "aws_appsync_resolver" "create_user" {
  api_id      = aws_appsync_graphql_api.in_the_cards_api.id
  type        = "Mutation"
  field       = "createUser"
  data_source = aws_appsync_datasource.users_table.name

  code = file("${path.module}/resources/createUser.js")

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
}

resource "aws_appsync_resolver" "get_user" {
  api_id      = aws_appsync_graphql_api.in_the_cards_api.id
  type        = "Query"
  field       = "getUser"
  data_source = aws_appsync_datasource.users_table.name

  code = file("${path.module}/resources/getUser.js")

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
}