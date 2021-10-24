resource "azurerm_policy_definition" "encrypt_storage_cmk" {
  name                  = "encrypt_storage_cmk"
  policy_type           = "Custom"
  mode                  = "Indexed"
  display_name          = "Encrypt Storage Accounts with CMK"
  management_group_name = "main"
  description           = "Encrypt Storage Accounts with CMK"

  metadata = <<METADATA
    {
    "category": "Encryption"
    }
  METADATA

  parameters = <<PARAMETERS
    ${file(
  "${path.module}/encrypt_storage_cmk.params.json",
)}
  PARAMETERS

policy_rule = <<POLICY_RULE
    ${file(
"${path.module}/encrypt_storage_cmk.json",
)}
  POLICY_RULE
}
