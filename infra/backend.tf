terraform {
  backend "gcs" {
    bucket = "shiori-polyforms-tfstate"
    prefix = "shiori"
  }
}
