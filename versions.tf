terraform {
  required_version = ">= 1.7" # removed block

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.37.0"
    }
    buildkit = {
      source  = "cruxstack/buildkit"
      version = ">= 0.0.1"
    }

    # transitional: only for `removed` block of pre-buildkit artifact modules
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.0.0, < 4.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.1"
    }
  }
}
