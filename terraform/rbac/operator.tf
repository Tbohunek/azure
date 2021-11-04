resource "azurerm_role_definition" "operator" {
  role_definition_id = # generated uuid
  name               = "Operator"
  scope              = /providers/Microsoft.Management/managementGroups/main"
  description        = "Custom role for Operator - read + start/stop operations"

  permissions {
    actions = [
      "*/read",
      # In fase of issues with new role, consider commented actions first. Comments to be removed by 2022Q2
      "Microsoft.Automation/automationAccounts/listKeys/action", #	Reads the Keys for the automation account
      "Microsoft.Automation/automationAccounts/*/getCount/action", #	Reads the count of objects
      "Microsoft.Automation/automationAccounts/jobs/runbookContent/action", #	Gets the content of the Azure Automation runbook at the time of the job execution
      "Microsoft.Automation/automationAccounts/*/start/action", #	Starts an Azure Automation job
      "Microsoft.Automation/automationAccounts/*/stop/action", #	Stops an Azure Automation job
      "Microsoft.Automation/automationAccounts/*/suspend/action", #	Suspends an Azure Automation job
      "Microsoft.Automation/automationAccounts/*/resume/action", #	Resumes an Azure Automation job
      "Microsoft.Automation/automationAccounts/nodeConfigurations/rawContent/action", #	Reads an Azure Automation DSC's node configuration content
      #"Microsoft.Automation/automationAccounts/webhooks/action	Generates a URI for an Azure Automation webhook
      #"Microsoft.Automation/automationAccounts/runbooks/publish/action", #	Publishes an Azure Automation runbook draft
      "Microsoft.Automation/automationAccounts/runbooks/draft/*/action", #
      "Microsoft.Batch/batchAccounts/*/action",
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/powerOff/action",
      "Microsoft.Compute/virtualMachines/deallocate/action",
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachineScaleSets/start/action",
      "Microsoft.Compute/virtualMachineScaleSets/powerOff/action",
      "Microsoft.Compute/virtualMachineScaleSets/restart/action",
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/powerOff/action",
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/restart/action",
      "Microsoft.DevTestLab/labs/users/serviceFabrics/Start/action",
      "Microsoft.DevTestLab/labs/users/serviceFabrics/Stop/action",
      "Microsoft.Insights/AutoscaleSettings/*/Action",
      "Microsoft.Insights/ListMigrationDate/Action",
      #Microsoft.Insights/Metrics/Action	Metric Action
      #Microsoft.Insights/ActivityLogAlerts/Activated/Action	Activity Log Alert activated
      #Microsoft.Insights/AlertRules/Activated/Action	Classic metric alert activated
      #Microsoft.Insights/AlertRules/Resolved/Action	Classic metric alert resolved
      #Microsoft.Insights/AlertRules/Throttled/Action	Classic metric alert rule throttled
      #Microsoft.Insights/Components/AnalyticsTables/Action	Application Insights analytics table action
      #Microsoft.Insights/Components/DailyCapReached/Action	Reached the daily cap for Application Insights component
      #Microsoft.Insights/Components/DailyCapWarningThresholdReached/Action	Reached the daily cap warning threshold for Application Insights component
      #Microsoft.Insights/Components/ExportConfiguration/Action
      "Microsoft.Network/applicationGateways/backendhealth/action",
      "Microsoft.Network/applicationGateways/getBackendHealthOnDemand/action",
      "Microsoft.Network/networkInterfaces/effectiveRouteTable/action",
      "Microsoft.Network/networkInterfaces/effectiveNetworkSecurityGroups/action",
      "Microsoft.Scheduler/*/run/action",
      "Microsoft.Support/*",
      "microsoft.web/sites/functions/*/action",
      "microsoft.web/sites/config/list/action",
    ]

    not_actions = []
  }
}
