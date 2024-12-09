terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.80.0"
    }
    github = {
      source = "integrations/github"
      version = "6.4.0"
    }
  }
}
# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

provider "github" {
  # Configuration options
    
}



resource "github_repository" "example" {
  name        = "test-vpc-diogo-tf"
  description = "My awesome codebase"

  visibility = "public"

#   template {
#     owner                = "github"
#     repository           = "terraform-template-module"
#     include_all_branches = true
#   }
}