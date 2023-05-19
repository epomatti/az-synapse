variable "workload" {
  type    = string
  default = "datamountain"
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "synapse_password" {
  type      = string
  default   = "P4ssw0rd#"
  sensitive = true
}
