// Metric Alerts Module
// Defines metric-based alerts for AKS monitoring

@description('Name prefix for alerts')
param alertNamePrefix string

@description('Resource ID of the AKS cluster to monitor')
param aksClusterId string

@description('Resource IDs of Action Groups to notify')
param actionGroupIds array

@description('Enable the alerts')
param enabled bool = true

@description('Tags for the resource')
param tags object = {}

// High CPU Alert
resource highCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${alertNamePrefix}-high-cpu'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when AKS node CPU usage exceeds 80%'
    severity: 2  // Warning
    enabled: enabled
    scopes: [
      aksClusterId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCPU'
          metricName: 'node_cpu_usage_percentage'
          metricNamespace: 'Insights.Container/nodes'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [for actionGroupId in actionGroupIds: {
      actionGroupId: actionGroupId
      webHookProperties: {}
    }]
    autoMitigate: true
    targetResourceType: 'Microsoft.ContainerService/managedClusters'
    targetResourceRegion: 'koreacentral'
  }
}

// High Memory Alert
resource highMemoryAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${alertNamePrefix}-high-memory'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when AKS node memory usage exceeds 80%'
    severity: 2  // Warning
    enabled: enabled
    scopes: [
      aksClusterId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighMemory'
          metricName: 'node_memory_working_set_percentage'
          metricNamespace: 'Insights.Container/nodes'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [for actionGroupId in actionGroupIds: {
      actionGroupId: actionGroupId
      webHookProperties: {}
    }]
    autoMitigate: true
    targetResourceType: 'Microsoft.ContainerService/managedClusters'
    targetResourceRegion: 'koreacentral'
  }
}

// Node Not Ready Alert
resource nodeNotReadyAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${alertNamePrefix}-node-not-ready'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when AKS nodes are not in ready state'
    severity: 1  // Error
    enabled: enabled
    scopes: [
      aksClusterId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'NodeNotReady'
          metricName: 'kube_node_status_condition'
          metricNamespace: 'Insights.Container/nodes'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'status2'
              operator: 'Include'
              values: [
                'NotReady'
              ]
            }
          ]
        }
      ]
    }
    actions: [for actionGroupId in actionGroupIds: {
      actionGroupId: actionGroupId
      webHookProperties: {}
    }]
    autoMitigate: true
    targetResourceType: 'Microsoft.ContainerService/managedClusters'
    targetResourceRegion: 'koreacentral'
  }
}

// Pod Failed Alert
resource podFailedAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${alertNamePrefix}-pod-failed'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when pods are in failed state'
    severity: 2  // Warning
    enabled: enabled
    scopes: [
      aksClusterId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'PodFailed'
          metricName: 'kube_pod_status_phase'
          metricNamespace: 'Insights.Container/pods'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'phase'
              operator: 'Include'
              values: [
                'Failed'
              ]
            }
          ]
        }
      ]
    }
    actions: [for actionGroupId in actionGroupIds: {
      actionGroupId: actionGroupId
      webHookProperties: {}
    }]
    autoMitigate: true
    targetResourceType: 'Microsoft.ContainerService/managedClusters'
    targetResourceRegion: 'koreacentral'
  }
}

@description('Resource ID of the High CPU Alert')
output highCpuAlertId string = highCpuAlert.id

@description('Resource ID of the High Memory Alert')
output highMemoryAlertId string = highMemoryAlert.id

@description('Resource ID of the Node Not Ready Alert')
output nodeNotReadyAlertId string = nodeNotReadyAlert.id

@description('Resource ID of the Pod Failed Alert')
output podFailedAlertId string = podFailedAlert.id
