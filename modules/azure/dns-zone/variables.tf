variable "zone_name" {
  type        = string
  description = "The domain name of the DNS zone (e.g. \"example.com\")."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group the zone is created in."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the zone."
  default     = {}
}

variable "records" {
  description = <<-EOT
    DNS records to create in this zone. One entry per record set (Azure DNS
    allows only one record set per name/type combination — e.g. all TXT
    values at "@" must be a single entry, not one per value).

    Fields used depend on `type`:
      - CNAME: `value`      (the target hostname)
      - A:     `values`     (list of IP addresses)
      - TXT:   `values`     (list of strings, one per TXT value)
      - MX:    `mx_records` (list of { preference, exchange })
  EOT
  type = list(object({
    type   = string # "A" | "CNAME" | "MX" | "TXT"
    name   = string # "@" for the zone apex
    ttl    = number
    value  = optional(string)
    values = optional(list(string))
    mx_records = optional(list(object({
      preference = number
      exchange   = string
    })))
  }))
  default = []
}
