provider "aws" {
  version = "~> 1.41"
}

provider "null" {
  version = "~> 1.0"
}

provider "aws" {
  alias  = "east1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "west2"
  region = "us-west-2"
}
