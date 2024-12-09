terraform {
  backend "s3" {
    bucket = "s3-lab-tfp-398cb344b0e94ae5a2605d6bc3382c41"
    key    = "tfpro.tfstate"
    region = "us-east-1"
  }
}
