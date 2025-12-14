// Role Assignment Module
@description('Principal ID to assign the role to')
param principalId string

@description('Principal type')
@allowed(['Device', 'ForeignGroup', 'Group', 'ServicePrincipal', 'User'])
param principalType string = 'ServicePrincipal'

@description('Role definition ID')
param roleDefinitionId string

@description('Scope for the role assignment')
param scope string = resourceGroup().id

var roleAssignmentName = guid(scope, principalId, roleDefinitionId)

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentName
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: roleDefinitionId
  }
}

output roleAssignmentId string = roleAssignment.id
