resource "aws_dynamodb_table" "users" {
  name           = "InTheCardsUsers"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name            = "EmailIndex"
    hash_key        = "email"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = false 
  }

  tags = {
    Name        = "In The Cards Users Table"
    ManagedBy   = "Terraform"
  }
}

resource "aws_dynamodb_table" "characters" {
  name           = "InTheCardsCharacters"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "characterId"
  range_key       = "userId"

  attribute {
    name = "characterId"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  global_secondary_index {
    name            = "UserCharactersIndex"
    hash_key        = "userId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "In The Cards Characters Table"
    ManagedBy   = "Terraform"
  }
}