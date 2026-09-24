resource "aws_iam_role_policy_attachment" "tfer--AWSCodePipelineServiceRole-eu-west-1-argovesto-api-v8_AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = "AWSCodePipelineServiceRole-eu-west-1-argovesto-api-v8"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSCodePipelineServiceRole-eu-west-1-argovesto-api-v8_AWSCodePipelineServiceRole-eu-west-1-argovesto-api-v8" {
  policy_arn = "arn:aws:iam::221434544570:policy/service-role/AWSCodePipelineServiceRole-eu-west-1-argovesto-api-v8"
  role       = "AWSCodePipelineServiceRole-eu-west-1-argovesto-api-v8"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSCodePipelineServiceRole-eu-west-1-argovesto-api-v8_AmazonSSMFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
  role       = "AWSCodePipelineServiceRole-eu-west-1-argovesto-api-v8"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSCodePipelineServiceRole-eu-west-1-argovesto-api-v8_CloudWatchLogsFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  role       = "AWSCodePipelineServiceRole-eu-west-1-argovesto-api-v8"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSCodePipelineServiceRole-eu-west-1-argovesto-api-v8_CodePipeline-CodeConnections-eu-west-1-argovesto-api-v8" {
  policy_arn = "arn:aws:iam::221434544570:policy/service-role/CodePipeline-CodeConnections-eu-west-1-argovesto-api-v8"
  role       = "AWSCodePipelineServiceRole-eu-west-1-argovesto-api-v8"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSReservedSSO_AdministratorAccess_bf9552b39d2cb66a_AdministratorAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = "AWSReservedSSO_AdministratorAccess_bf9552b39d2cb66a"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForAmazonSSM_AmazonSSMServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AmazonSSMServiceRolePolicy"
  role       = "AWSServiceRoleForAmazonSSM"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForAutoScaling_AutoScalingServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AutoScalingServiceRolePolicy"
  role       = "AWSServiceRoleForAutoScaling"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForCostOptimizationHub_CostOptimizationHubServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/CostOptimizationHubServiceRolePolicy"
  role       = "AWSServiceRoleForCostOptimizationHub"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForDMSServerless_AWSDMSServerlessServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AWSDMSServerlessServiceRolePolicy"
  role       = "AWSServiceRoleForDMSServerless"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForElasticLoadBalancing_AWSElasticLoadBalancingServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AWSElasticLoadBalancingServiceRolePolicy"
  role       = "AWSServiceRoleForElasticLoadBalancing"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForGlobalAccelerator_AWSGlobalAcceleratorSLRPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AWSGlobalAcceleratorSLRPolicy"
  role       = "AWSServiceRoleForGlobalAccelerator"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForOrganizations_AWSOrganizationsServiceTrustPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AWSOrganizationsServiceTrustPolicy"
  role       = "AWSServiceRoleForOrganizations"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForRDS_AmazonRDSServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AmazonRDSServiceRolePolicy"
  role       = "AWSServiceRoleForRDS"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForResourceExplorer_AWSResourceExplorerServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AWSResourceExplorerServiceRolePolicy"
  role       = "AWSServiceRoleForResourceExplorer"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForSMSVoice_SMSVoiceServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/SMSVoiceServiceRolePolicy"
  role       = "AWSServiceRoleForSMSVoice"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForSSO_AWSSSOServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AWSSSOServiceRolePolicy"
  role       = "AWSServiceRoleForSSO"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForSupport_AWSSupportServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AWSSupportServiceRolePolicy"
  role       = "AWSServiceRoleForSupport"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForTrustedAdvisor_AWSTrustedAdvisorServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AWSTrustedAdvisorServiceRolePolicy"
  role       = "AWSServiceRoleForTrustedAdvisor"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSSystemsManagerDefaultEC2InstanceManagementRole_AmazonSSMManagedEC2InstanceDefaultPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"
  role       = "AWSSystemsManagerDefaultEC2InstanceManagementRole"
}

resource "aws_iam_role_policy_attachment" "tfer--AmplifySSRLoggingRole-227acf59-5d64-413b-b600-1a52d75bec84_AdministratorAccess-Amplify" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-Amplify"
  role       = "AmplifySSRLoggingRole-227acf59-5d64-413b-b600-1a52d75bec84"
}

resource "aws_iam_role_policy_attachment" "tfer--AmplifySSRLoggingRole-227acf59-5d64-413b-b600-1a52d75bec84_AmplifyBackendDeployFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmplifyBackendDeployFullAccess"
  role       = "AmplifySSRLoggingRole-227acf59-5d64-413b-b600-1a52d75bec84"
}

resource "aws_iam_role_policy_attachment" "tfer--AmplifySSRLoggingRole-227acf59-5d64-413b-b600-1a52d75bec84_AmplifySSRLoggingPolicy-227acf59-5d64-413b-b600-1a52d75bec84" {
  policy_arn = "arn:aws:iam::221434544570:policy/service-role/AmplifySSRLoggingPolicy-227acf59-5d64-413b-b600-1a52d75bec84"
  role       = "AmplifySSRLoggingRole-227acf59-5d64-413b-b600-1a52d75bec84"
}

resource "aws_iam_role_policy_attachment" "tfer--CloudWatchAgentServerPolicy_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = "CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "tfer--CloudWatchAgentServerPolicy_CloudWatchAgentAdminPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentAdminPolicy"
  role       = "CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "tfer--CloudWatchAgentServerPolicy_CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = "CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "tfer--CodeBuildDeploymentRole_AdministratorAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = "CodeBuildDeploymentRole"
}

resource "aws_iam_role_policy_attachment" "tfer--DMSSecretManagerAccessRole-agxdb2DBcredentials_DMSSecretManagerPolicy-DMSSecretManagerAccessRole-agxdb2DBcredentials" {
  policy_arn = "arn:aws:iam::221434544570:policy/service-role/DMSSecretManagerPolicy-DMSSecretManagerAccessRole-agxdb2DBcredentials"
  role       = "DMSSecretManagerAccessRole-agxdb2DBcredentials"
}

resource "aws_iam_role_policy_attachment" "tfer--DMSSecretManagerAccessRole-nomaosDBcredentials_DMSSecretManagerPolicy-DMSSecretManagerAccessRole-nomaosDBcredentials" {
  policy_arn = "arn:aws:iam::221434544570:policy/service-role/DMSSecretManagerPolicy-DMSSecretManagerAccessRole-nomaosDBcredentials"
  role       = "DMSSecretManagerAccessRole-nomaosDBcredentials"
}

resource "aws_iam_role_policy_attachment" "tfer--GitHubActionsCDKDeploy_AWSCloudFormationFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess"
  role       = "GitHubActionsCDKDeploy"
}

resource "aws_iam_role_policy_attachment" "tfer--GitHubActionsCDKDeploy_AmazonEC2FullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  role       = "GitHubActionsCDKDeploy"
}

resource "aws_iam_role_policy_attachment" "tfer--GitHubActionsCDKDeploy_AmazonRDSFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
  role       = "GitHubActionsCDKDeploy"
}

resource "aws_iam_role_policy_attachment" "tfer--GitHubActionsCDKDeploy_AmazonS3FullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = "GitHubActionsCDKDeploy"
}

resource "aws_iam_role_policy_attachment" "tfer--GitHubActionsCDKDeploy_AmazonSSMFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
  role       = "GitHubActionsCDKDeploy"
}

resource "aws_iam_role_policy_attachment" "tfer--GitHubActionsCDKDeploy_IAMFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
  role       = "GitHubActionsCDKDeploy"
}

resource "aws_iam_role_policy_attachment" "tfer--GitHubActionsCDKDeploy_SecretsManagerReadWrite" {
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
  role       = "GitHubActionsCDKDeploy"
}

resource "aws_iam_role_policy_attachment" "tfer--agrovesto-infra-deploymen-CustomVpcRestrictDefaultS-Hzq7oZBnIJrR_AWSLambdaBasicExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "agrovesto-infra-deploymen-CustomVpcRestrictDefaultS-Hzq7oZBnIJrR"
}

resource "aws_iam_role_policy_attachment" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-UepjS11Nv8aU_AWSLambdaBasicExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-UepjS11Nv8aU"
}

resource "aws_iam_role_policy_attachment" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-UepjS11Nv8aU_AWSLambdaVPCAccessExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-UepjS11Nv8aU"
}

resource "aws_iam_role_policy_attachment" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-yDIdim0P5oKG_AWSLambdaBasicExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-yDIdim0P5oKG"
}

resource "aws_iam_role_policy_attachment" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-yDIdim0P5oKG_AWSLambdaVPCAccessExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-yDIdim0P5oKG"
}

resource "aws_iam_role_policy_attachment" "tfer--agrovesto-infra-pipeline-CodePipelineRole-OF4B386rGJe4_PowerUserAccess" {
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
  role       = "agrovesto-infra-pipeline-CodePipelineRole-OF4B386rGJe4"
}

resource "aws_iam_role_policy_attachment" "tfer--agrovesto-prod-github-deploy_agrovesto-prod-github-deploy-policy" {
  policy_arn = "arn:aws:iam::221434544570:policy/agrovesto-prod-github-deploy-policy"
  role       = "agrovesto-prod-github-deploy"
}

resource "aws_iam_role_policy_attachment" "tfer--cdk-hnb659fds-cfn-exec-role-221434544570-eu-west-1_AdministratorAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = "cdk-hnb659fds-cfn-exec-role-221434544570-eu-west-1"
}

resource "aws_iam_role_policy_attachment" "tfer--cdk-hnb659fds-lookup-role-221434544570-eu-west-1_ReadOnlyAccess" {
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  role       = "cdk-hnb659fds-lookup-role-221434544570-eu-west-1"
}

resource "aws_iam_role_policy_attachment" "tfer--dms-cloudwatch-logs-role_AmazonDMSCloudWatchLogsRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
  role       = "dms-cloudwatch-logs-role"
}

resource "aws_iam_role_policy_attachment" "tfer--dms-vpc-role_AmazonDMSVPCManagementRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
  role       = "dms-vpc-role"
}

resource "aws_iam_role_policy_attachment" "tfer--ec2_role-d0f2b8_AmazonEC2RoleforAWSCodeDeploy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
  role       = "ec2_role-d0f2b8"
}

resource "aws_iam_role_policy_attachment" "tfer--ec2_role-d0f2b8_AmazonS3FullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = "ec2_role-d0f2b8"
}

resource "aws_iam_role_policy_attachment" "tfer--ec2_role-d0f2b8_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = "ec2_role-d0f2b8"
}

resource "aws_iam_role_policy_attachment" "tfer--instanceRole_AmazonEC2RoleforSSM" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  role       = "instanceRole"
}

resource "aws_iam_role_policy_attachment" "tfer--instanceRole_AmazonSSMAutomationApproverAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMAutomationApproverAccess"
  role       = "instanceRole"
}

resource "aws_iam_role_policy_attachment" "tfer--instanceRole_AmazonSSMAutomationRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole"
  role       = "instanceRole"
}

resource "aws_iam_role_policy_attachment" "tfer--instanceRole_AmazonSSMDirectoryServiceAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
  role       = "instanceRole"
}

resource "aws_iam_role_policy_attachment" "tfer--instanceRole_AmazonSSMFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
  role       = "instanceRole"
}

resource "aws_iam_role_policy_attachment" "tfer--instanceRole_AmazonSSMMaintenanceWindowRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMMaintenanceWindowRole"
  role       = "instanceRole"
}

resource "aws_iam_role_policy_attachment" "tfer--instanceRole_AmazonSSMManagedEC2InstanceDefaultPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"
  role       = "instanceRole"
}

resource "aws_iam_role_policy_attachment" "tfer--instanceRole_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = "instanceRole"
}

resource "aws_iam_role_policy_attachment" "tfer--instanceRole_AmazonSageMakerCanvasSMDataScienceAssistantAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerCanvasSMDataScienceAssistantAccess"
  role       = "instanceRole"
}

resource "aws_iam_role_policy_attachment" "tfer--instanceRole_CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = "instanceRole"
}

resource "aws_iam_role_policy_attachment" "tfer--nomaos-prod-github-terraform_AdministratorAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = "nomaos-prod-github-terraform"
}

resource "aws_iam_role_policy_attachment" "tfer--rds-monitoring-role_AmazonRDSEnhancedMonitoringRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  role       = "rds-monitoring-role"
}
