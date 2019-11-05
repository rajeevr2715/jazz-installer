#
# Cognito resources
#
resource "aws_cognito_user_pool" "pool"{
  name = "${var.envPrefix}"
  username_attributes = ["email"]
  schema = [
    {
      name = "email"
      attribute_data_type = "String"
      required = true
    },
    {
      name = "reg-code"
      attribute_data_type = "String"
      string_attribute_constraints = {
        min_length = 1
      },
    }
  ]
  tags = {
    Application = "Jazz"
    JazzInstance = "${var.envPrefix}"
  }
  auto_verified_attributes = ["email"]
  verification_message_template = {
    email_subject_by_link = "Jazz Notification - Account Verification"
    email_message_by_link = "Hello,\n<br><br>\nThanks for signing up!\n<br><br>\nPlease click the link to verify your email address: {##VERIFY EMAIL##}\n<br><br>\nTo know more about Jazz, please refer to link https://github.com/tmobile/jazz/wiki\n<br><br>\nBest,<br>\nJazz Team"
    default_email_option = "CONFIRM_WITH_LINK"
  }
  password_policy = {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = false
    require_symbols   = false
    require_uppercase = false
  }
}

resource "aws_cognito_user_pool_client" "client" {
  name = "${var.envPrefix}-api-onboarding"
  generate_secret = false
  user_pool_id = "${aws_cognito_user_pool.pool.id}"

}

resource "aws_cognito_user_pool_domain" "domain" {
  domain = "${var.envPrefix}"
  user_pool_id = "${aws_cognito_user_pool.pool.id}"
}
