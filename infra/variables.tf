variable "workload" {
  type    = string
  default = "datamountain"
}

variable "location" {
  type    = string
  default = "eastus2"
}

variable "synapse_password" {
  type      = string
  default   = "P4ssw0rd#123"
  sensitive = true
}
