resource "aws_iam_role_policy_attachment" "tfer--AWSCodePipelineServiceRole-eu-west-1-nomaos_AWSCodeDeployFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployFullAccess"
  role       = "AWSCodePipelineServiceRole-eu-west-1-nomaos"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSCodePipelineServiceRole-eu-west-1-nomaos_AWSCodePipelineServiceRole-eu-west-1-nomaos" {
  policy_arn = "arn:aws:iam::353833416626:policy/service-role/AWSCodePipelineServiceRole-eu-west-1-nomaos"
  role       = "AWSCodePipelineServiceRole-eu-west-1-nomaos"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSCodePipelineServiceRole-eu-west-1-nomaos_AWSCodePipeline_FullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess"
  role       = "AWSCodePipelineServiceRole-eu-west-1-nomaos"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSCodePipelineServiceRole-eu-west-1-nomaos_AmazonSSMFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
  role       = "AWSCodePipelineServiceRole-eu-west-1-nomaos"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSCodePipelineServiceRole-eu-west-1-nomaos_CloudWatchLogsFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  role       = "AWSCodePipelineServiceRole-eu-west-1-nomaos"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSCodePipelineServiceRole-eu-west-1-nomaos_CodePipeline-CodeConnections-eu-west-1-nomaos" {
  policy_arn = "arn:aws:iam::353833416626:policy/service-role/CodePipeline-CodeConnections-eu-west-1-nomaos"
  role       = "AWSCodePipelineServiceRole-eu-west-1-nomaos"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSReservedSSO_AdministratorAccess_0b70d56e4b20d17b_AdministratorAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = "AWSReservedSSO_AdministratorAccess_0b70d56e4b20d17b"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForAmazonSSM_AmazonSSMServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AmazonSSMServiceRolePolicy"
  role       = "AWSServiceRoleForAmazonSSM"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForAppRunner_AppRunnerServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AppRunnerServiceRolePolicy"
  role       = "AWSServiceRoleForAppRunner"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForAutoScaling_AutoScalingServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AutoScalingServiceRolePolicy"
  role       = "AWSServiceRoleForAutoScaling"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForAwsUserNotifications_AWSUserNotificationsServiceLinkedRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AWSUserNotificationsServiceLinkedRolePolicy"
  role       = "AWSServiceRoleForAwsUserNotifications"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForCostOptimizationHub_CostOptimizationHubServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/CostOptimizationHubServiceRolePolicy"
  role       = "AWSServiceRoleForCostOptimizationHub"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForECS_AmazonECSServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AmazonECSServiceRolePolicy"
  role       = "AWSServiceRoleForECS"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForElasticLoadBalancing_AWSElasticLoadBalancingServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AWSElasticLoadBalancingServiceRolePolicy"
  role       = "AWSServiceRoleForElasticLoadBalancing"
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

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForSSO_AWSSSOServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AWSSSOServiceRolePolicy"
  role       = "AWSServiceRoleForSSO"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForServiceQuotas_ServiceQuotasServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/ServiceQuotasServiceRolePolicy"
  role       = "AWSServiceRoleForServiceQuotas"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForSupport_AWSSupportServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AWSSupportServiceRolePolicy"
  role       = "AWSServiceRoleForSupport"
}

resource "aws_iam_role_policy_attachment" "tfer--AWSServiceRoleForTrustedAdvisor_AWSTrustedAdvisorServiceRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AWSTrustedAdvisorServiceRolePolicy"
  role       = "AWSServiceRoleForTrustedAdvisor"
}

resource "aws_iam_role_policy_attachment" "tfer--AmplifySSRLoggingRole-4fb94426-a00e-4cd2-9ea2-2d0bd82fd3e1_AmplifySSRLoggingPolicy-4fb94426-a00e-4cd2-9ea2-2d0bd82fd3e1" {
  policy_arn = "arn:aws:iam::353833416626:policy/service-role/AmplifySSRLoggingPolicy-4fb94426-a00e-4cd2-9ea2-2d0bd82fd3e1"
  role       = "AmplifySSRLoggingRole-4fb94426-a00e-4cd2-9ea2-2d0bd82fd3e1"
}

resource "aws_iam_role_policy_attachment" "tfer--AmplifySSRLoggingRole-640973d5-6399-421a-ac2a-ba65df815c56_AmplifySSRLoggingPolicy-640973d5-6399-421a-ac2a-ba65df815c56" {
  policy_arn = "arn:aws:iam::353833416626:policy/service-role/AmplifySSRLoggingPolicy-640973d5-6399-421a-ac2a-ba65df815c56"
  role       = "AmplifySSRLoggingRole-640973d5-6399-421a-ac2a-ba65df815c56"
}

resource "aws_iam_role_policy_attachment" "tfer--AmplifySSRLoggingRole-702a70a4-375c-468f-97d4-4641dd448284_AmplifySSRLoggingPolicy-702a70a4-375c-468f-97d4-4641dd448284" {
  policy_arn = "arn:aws:iam::353833416626:policy/service-role/AmplifySSRLoggingPolicy-702a70a4-375c-468f-97d4-4641dd448284"
  role       = "AmplifySSRLoggingRole-702a70a4-375c-468f-97d4-4641dd448284"
}

resource "aws_iam_role_policy_attachment" "tfer--AmplifySSRLoggingRole-739d4bc2-0a8d-4a1b-9796-ea41cf9cfc87_AmplifySSRLoggingPolicy-739d4bc2-0a8d-4a1b-9796-ea41cf9cfc87" {
  policy_arn = "arn:aws:iam::353833416626:policy/service-role/AmplifySSRLoggingPolicy-739d4bc2-0a8d-4a1b-9796-ea41cf9cfc87"
  role       = "AmplifySSRLoggingRole-739d4bc2-0a8d-4a1b-9796-ea41cf9cfc87"
}

resource "aws_iam_role_policy_attachment" "tfer--AmplifySSRLoggingRole-77230cc0-0b08-4dc4-be4b-98f0a92c9b9b_AmplifySSRLoggingPolicy-77230cc0-0b08-4dc4-be4b-98f0a92c9b9b" {
  policy_arn = "arn:aws:iam::353833416626:policy/service-role/AmplifySSRLoggingPolicy-77230cc0-0b08-4dc4-be4b-98f0a92c9b9b"
  role       = "AmplifySSRLoggingRole-77230cc0-0b08-4dc4-be4b-98f0a92c9b9b"
}

resource "aws_iam_role_policy_attachment" "tfer--AmplifySSRLoggingRole-9ceec546-7451-41f6-8409-410781242368_AmplifySSRLoggingPolicy-9ceec546-7451-41f6-8409-410781242368" {
  policy_arn = "arn:aws:iam::353833416626:policy/service-role/AmplifySSRLoggingPolicy-9ceec546-7451-41f6-8409-410781242368"
  role       = "AmplifySSRLoggingRole-9ceec546-7451-41f6-8409-410781242368"
}

resource "aws_iam_role_policy_attachment" "tfer--AmplifySSRLoggingRole-c0c3ebab-fdb6-4ed4-a8fb-2ce7dd34f371_AmplifySSRLoggingPolicy-c0c3ebab-fdb6-4ed4-a8fb-2ce7dd34f371" {
  policy_arn = "arn:aws:iam::353833416626:policy/service-role/AmplifySSRLoggingPolicy-c0c3ebab-fdb6-4ed4-a8fb-2ce7dd34f371"
  role       = "AmplifySSRLoggingRole-c0c3ebab-fdb6-4ed4-a8fb-2ce7dd34f371"
}

resource "aws_iam_role_policy_attachment" "tfer--GitHubActionsCDKDeploy_AWSCloudFormationFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess"
  role       = "GitHubActionsCDKDeploy"
}

resource "aws_iam_role_policy_attachment" "tfer--GitHubActionsCDKDeploy_AmazonEC2ContainerRegistryPowerUser" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  role       = "GitHubActionsCDKDeploy"
}

resource "aws_iam_role_policy_attachment" "tfer--GitHubActionsCDKDeploy_AmazonEC2FullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  role       = "GitHubActionsCDKDeploy"
}

resource "aws_iam_role_policy_attachment" "tfer--GitHubActionsCDKDeploy_AmazonECS_FullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
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

resource "aws_iam_role_policy_attachment" "tfer--GitHubActionsCDKDeploy_EC2InstanceProfileForImageBuilderECRContainerBuilds" {
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
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

resource "aws_iam_role_policy_attachment" "tfer--OrganizationAccountAccessRole_AdministratorAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = "OrganizationAccountAccessRole"
}

resource "aws_iam_role_policy_attachment" "tfer--agrovesto-infra-deploymen-CustomVpcRestrictDefaultS-wHppFzTSRAd1_AWSLambdaBasicExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "agrovesto-infra-deploymen-CustomVpcRestrictDefaultS-wHppFzTSRAd1"
}

resource "aws_iam_role_policy_attachment" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-DTg5g94z5aY6_AWSLambdaBasicExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-DTg5g94z5aY6"
}

resource "aws_iam_role_policy_attachment" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-DTg5g94z5aY6_AWSLambdaVPCAccessExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-DTg5g94z5aY6"
}

resource "aws_iam_role_policy_attachment" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-EXyHA0Ipenan_AWSLambdaBasicExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-EXyHA0Ipenan"
}

resource "aws_iam_role_policy_attachment" "tfer--agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-EXyHA0Ipenan_AWSLambdaVPCAccessExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = "agrovesto-infra-deploymen-SecretsManagerRDSSQLServe-EXyHA0Ipenan"
}

resource "aws_iam_role_policy_attachment" "tfer--amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCustom-ejNMfppltfPg_AWSLambdaBasicExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCustom-ejNMfppltfPg"
}

resource "aws_iam_role_policy_attachment" "tfer--amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCustom-fzp661Q35Odb_AWSLambdaBasicExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "amplify-d3setdk1gwy695-ma-AmplifyBranchLinkerCustom-fzp661Q35Odb"
}

resource "aws_iam_role_policy_attachment" "tfer--amplify-d3setdk1gwy695-ma-AmplifyManagedTableIsComp-rcS8Djx2OFrP_AWSLambdaBasicExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "amplify-d3setdk1gwy695-ma-AmplifyManagedTableIsComp-rcS8Djx2OFrP"
}

resource "aws_iam_role_policy_attachment" "tfer--amplify-d3setdk1gwy695-ma-AmplifyManagedTableOnEven-SnL0p2y5qusS_AWSLambdaBasicExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "amplify-d3setdk1gwy695-ma-AmplifyManagedTableOnEven-SnL0p2y5qusS"
}

resource "aws_iam_role_policy_attachment" "tfer--amplify-d3setdk1gwy695-ma-CustomCDKBucketDeployment-pZMgmQWVhiQn_AWSLambdaBasicExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "amplify-d3setdk1gwy695-ma-CustomCDKBucketDeployment-pZMgmQWVhiQn"
}

resource "aws_iam_role_policy_attachment" "tfer--amplify-d3setdk1gwy695-ma-CustomS3AutoDeleteObjects-BK3zRlUFMp70_AWSLambdaBasicExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "amplify-d3setdk1gwy695-ma-CustomS3AutoDeleteObjects-BK3zRlUFMp70"
}

resource "aws_iam_role_policy_attachment" "tfer--amplify-d3setdk1gwy695-ma-CustomS3AutoDeleteObjects-izjLHpD4ISHR_AWSLambdaBasicExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "amplify-d3setdk1gwy695-ma-CustomS3AutoDeleteObjects-izjLHpD4ISHR"
}

resource "aws_iam_role_policy_attachment" "tfer--amplify-d3setdk1gwy695-ma-amplifyAuthauthenticatedU-9bTF5ojNgNm7_amplify-d3setdk1gwy695-main-branch-467367b8b9-data7552DF31-13E3RJPY8AFZP-amplifyDataAuthRolePolicy01567A5654-kJ3IQgNtXlXZ" {
  policy_arn = "arn:aws:iam::353833416626:policy/amplify-d3setdk1gwy695-main-branch-467367b8b9-data7552DF31-13E3RJPY8AFZP-amplifyDataAuthRolePolicy01567A5654-kJ3IQgNtXlXZ"
  role       = "amplify-d3setdk1gwy695-ma-amplifyAuthauthenticatedU-9bTF5ojNgNm7"
}

resource "aws_iam_role_policy_attachment" "tfer--amplify-d3setdk1gwy695-ma-amplifyAuthunauthenticate-PeKmwwLSiQEo_amplify-d3setdk1gwy695-main-branch-467367b8b9-data7552DF31-13E3RJPY8AFZP-amplifyDataUnauthRolePolicy01355B9DCF-HIvjT1HkH1Fp" {
  policy_arn = "arn:aws:iam::353833416626:policy/amplify-d3setdk1gwy695-main-branch-467367b8b9-data7552DF31-13E3RJPY8AFZP-amplifyDataUnauthRolePolicy01355B9DCF-HIvjT1HkH1Fp"
  role       = "amplify-d3setdk1gwy695-ma-amplifyAuthunauthenticate-PeKmwwLSiQEo"
}

resource "aws_iam_role_policy_attachment" "tfer--amplify-d3setdk1gwy695-ma-presignuplambdaServiceRol-3sfnt65dFkcU_AWSLambdaBasicExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "amplify-d3setdk1gwy695-ma-presignuplambdaServiceRol-3sfnt65dFkcU"
}

resource "aws_iam_role_policy_attachment" "tfer--cdk-hnb659fds-cfn-exec-role-353833416626-eu-central-1_AdministratorAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = "cdk-hnb659fds-cfn-exec-role-353833416626-eu-central-1"
}

resource "aws_iam_role_policy_attachment" "tfer--cdk-hnb659fds-cfn-exec-role-353833416626-eu-west-1_AdministratorAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = "cdk-hnb659fds-cfn-exec-role-353833416626-eu-west-1"
}

resource "aws_iam_role_policy_attachment" "tfer--cdk-hnb659fds-deploy-role-353833416626-eu-central-1_AWSCloudFormationReadOnlyAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCloudFormationReadOnlyAccess"
  role       = "cdk-hnb659fds-deploy-role-353833416626-eu-central-1"
}

resource "aws_iam_role_policy_attachment" "tfer--cdk-hnb659fds-lookup-role-353833416626-eu-central-1_ReadOnlyAccess" {
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  role       = "cdk-hnb659fds-lookup-role-353833416626-eu-central-1"
}

resource "aws_iam_role_policy_attachment" "tfer--cdk-hnb659fds-lookup-role-353833416626-eu-west-1_ReadOnlyAccess" {
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  role       = "cdk-hnb659fds-lookup-role-353833416626-eu-west-1"
}

resource "aws_iam_role_policy_attachment" "tfer--ec2_role-12c63a_AmazonEC2RoleforAWSCodeDeploy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
  role       = "ec2_role-12c63a"
}

resource "aws_iam_role_policy_attachment" "tfer--ec2_role-12c63a_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = "ec2_role-12c63a"
}

resource "aws_iam_role_policy_attachment" "tfer--ec2_role_AmazonEC2RoleforSSM" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  role       = "ec2_role"
}

resource "aws_iam_role_policy_attachment" "tfer--ec2_role_AmazonSSMFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
  role       = "ec2_role"
}

resource "aws_iam_role_policy_attachment" "tfer--ec2_role_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = "ec2_role"
}

resource "aws_iam_role_policy_attachment" "tfer--nomaos-amplify_AdministratorAccess-Amplify" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-Amplify"
  role       = "nomaos-amplify"
}

resource "aws_iam_role_policy_attachment" "tfer--nomaos-dev-github-terraform_AdministratorAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = "nomaos-dev-github-terraform"
}

resource "aws_iam_role_policy_attachment" "tfer--rds-monitoring-role_AmazonRDSEnhancedMonitoringRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  role       = "rds-monitoring-role"
}

resource "aws_iam_role_policy_attachment" "tfer--ssmrole_AmazonEC2ContainerRegistryFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  role       = "ssmrole"
}

resource "aws_iam_role_policy_attachment" "tfer--ssmrole_AmazonEC2RoleforSSM" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  role       = "ssmrole"
}

resource "aws_iam_role_policy_attachment" "tfer--ssmrole_AmazonEventBridgeSchedulerFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEventBridgeSchedulerFullAccess"
  role       = "ssmrole"
}

resource "aws_iam_role_policy_attachment" "tfer--ssmrole_AmazonS3FullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = "ssmrole"
}

resource "aws_iam_role_policy_attachment" "tfer--ssmrole_AmazonSSMFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
  role       = "ssmrole"
}

resource "aws_iam_role_policy_attachment" "tfer--ssmrole_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = "ssmrole"
}

resource "aws_iam_role_policy_attachment" "tfer--ssmrole_CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = "ssmrole"
}

resource "aws_iam_role_policy_attachment" "tfer--test-role-dfn63jmf_AWSLambdaBasicExecutionRole-11c81ffa-eaed-45b5-b356-bf24894d1193" {
  policy_arn = "arn:aws:iam::353833416626:policy/service-role/AWSLambdaBasicExecutionRole-11c81ffa-eaed-45b5-b356-bf24894d1193"
  role       = "test-role-dfn63jmf"
}

resource "aws_iam_role_policy_attachment" "tfer--test-role-dfn63jmf_AWSLambdaVPCAccessExecutionRole-6aa51a87-0e83-4869-be44-e074cad3bc76" {
  policy_arn = "arn:aws:iam::353833416626:policy/service-role/AWSLambdaVPCAccessExecutionRole-6aa51a87-0e83-4869-be44-e074cad3bc76"
  role       = "test-role-dfn63jmf"
}
