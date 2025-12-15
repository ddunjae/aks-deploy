// Action Group Module
// Defines notification targets for Azure Monitor alerts

@description('Name of the Action Group')
param actionGroupName string

@description('Short name for the Action Group (max 12 characters)')
@maxLength(12)
param shortName string

@description('Azure region for deployment (global for action groups)')
param location string = 'global'

@description('Enable the Action Group')
param enabled bool = true

@description('Email receivers configuration')
param emailReceivers array = []
// Example: [{ name: 'Admin', emailAddress: 'admin@example.com', useCommonAlertSchema: true }]

@description('SMS receivers configuration')
param smsReceivers array = []
// Example: [{ name: 'Admin', countryCode: '82', phoneNumber: '01012345678' }]

@description('Webhook receivers configuration')
param webhookReceivers array = []
// Example: [{ name: 'Webhook', serviceUri: 'https://example.com/webhook', useCommonAlertSchema: true }]

@description('Azure App Push receivers configuration')
param azureAppPushReceivers array = []

@description('Tags for the resource')
param tags object = {}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-09-01-preview' = {
  name: actionGroupName
  location: location
  tags: tags
  properties: {
    groupShortName: shortName
    enabled: enabled
    emailReceivers: emailReceivers
    smsReceivers: smsReceivers
    webhookReceivers: webhookReceivers
    azureAppPushReceivers: azureAppPushReceivers
    automationRunbookReceivers: []
    voiceReceivers: []
    logicAppReceivers: []
    azureFunctionReceivers: []
    armRoleReceivers: []
    eventHubReceivers: []
    itsmReceivers: []
  }
}

@description('Resource ID of the Action Group')
output actionGroupId string = actionGroup.id

@description('Name of the Action Group')
output actionGroupName string = actionGroup.name
