terraform {
  required_version = ">= 1.7" # removed block

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.71.0"
    }
    buildkit = {
      source  = "cruxstack/buildkit"
      version = ">= 0.0.2"
    }

    # transitional: only for `removed` block of pre-buildkit artifact modules
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.8.1"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.9.0, < 4.6.1"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.3.2"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.9.1"
    }
  }
}
