#!/usr/bin/env bash
# =============================================================================
# imports/discover.sh <dev|prod>  —  READ-ONLY facts the import blocks need.
#
# Resource Explorer gives ARNs only. Adopting into the new design needs CIDRs,
# AZs, routes, engine versions, key-pair names, etc. This prints them in a
# form you paste into terraform.auto.tfvars / imports_adopt.tf.
#
# Uses only Describe/List/Get calls. Prints no secret values.
#   AWS_PROFILE is picked from the env name (agrovesto-dev / agrovesto-prod).
# Output is also written to imports/discovery-<env>.txt (git-ignored).
# =============================================================================
set -euo pipefail

ENV="${1:?usage: discover.sh dev|prod}"
case "$ENV" in
  dev)  export AWS_PROFILE="${AWS_PROFILE:-agrovesto-dev}";  VPC=vpc-0d9b566c353787d53; ACCT=353833416626 ;;
  prod) export AWS_PROFILE="${AWS_PROFILE:-agrovesto-prod}"; VPC=vpc-0016f521bae08f4ff; ACCT=221434544570 ;;
  *) echo "env must be dev or prod" >&2; exit 2 ;;
esac
export AWS_REGION="${AWS_REGION:-eu-west-1}" AWS_PAGER=""
OUT="$(dirname "$0")/discovery-$ENV.txt"
exec > >(tee "$OUT") 2>&1

have=$(aws sts get-caller-identity --query Account --output text)
[ "$have" = "$ACCT" ] || { echo "profile $AWS_PROFILE is account $have, expected $ACCT" >&2; exit 1; }

q() { aws "$@" --output text 2>/dev/null || echo "  (not found / no access)"; }
h() { printf '\n=== %s ===\n' "$*"; }

h "VPC  (vpc_cidr = ...)"
q ec2 describe-vpcs --vpc-ids "$VPC" --query 'Vpcs[].[VpcId,CidrBlock,EnableDnsSupport,Tags[?Key==`Name`]|[0].Value]'
aws ec2 describe-vpc-attribute --vpc-id "$VPC" --attribute enableDnsHostnames --query 'EnableDnsHostnames.Value' --output text | sed 's/^/  enableDnsHostnames=/'
echo "  AZ order used by the new code (first N available):"
aws ec2 describe-availability-zones --filters Name=state,Values=available --query 'AvailabilityZones[].ZoneName' --output text | sed 's/^/  /'

h "SUBNET  id  cidr  az  public-ip-on-launch  route(0.0.0.0/0)  route-table  name"
for s in $(aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC" --query 'Subnets[].SubnetId' --output text); do
  read -r cidr az mpip name < <(aws ec2 describe-subnets --subnet-ids "$s" --query 'Subnets[0].[CidrBlock,AvailabilityZone,MapPublicIpOnLaunch,Tags[?Key==`Name`]|[0].Value]' --output text)
  rt=$(aws ec2 describe-route-tables --filters Name=association.subnet-id,Values="$s" --query 'RouteTables[0].RouteTableId' --output text)
  [ "$rt" = "None" ] && rt=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values="$VPC" Name=association.main,Values=true --query 'RouteTables[0].RouteTableId' --output text)"(main)"
  gw=$(aws ec2 describe-route-tables --route-table-ids "${rt%(main)}" --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`]|[0].[GatewayId,NatGatewayId]' --output text | tr '\t' ' ')
  kind=private; [[ "$gw" == igw-* ]] && kind=public
  echo "  $s $cidr $az $mpip $kind:$gw $rt $name"
done

h "ROUTE TABLES  id  main  associations  routes"
aws ec2 describe-route-tables --filters Name=vpc-id,Values="$VPC" \
  --query 'RouteTables[].[RouteTableId,Associations[?Main]|[0].Main,join(`,`,Associations[].SubnetId||[``]),join(`,`,Routes[].join(`>`,[DestinationCidrBlock||``,GatewayId||NatGatewayId||``]))]' --output text | sed 's/^/  /'

h "NAT GATEWAYS"
q ec2 describe-nat-gateways --filter Name=vpc-id,Values="$VPC" --query 'NatGateways[?State==`available`].[NatGatewayId,SubnetId,NatGatewayAddresses[0].AllocationId]'

h "SG  id  name  DEFAULT?  vpc  #in  #out   (default SG -> aws_default_security_group.default)"
aws ec2 describe-security-groups --query 'SecurityGroups[].[GroupId,GroupName,VpcId,length(IpPermissions),length(IpPermissionsEgress)]' --output text |
  awk '{d=($2=="default")?"DEFAULT":"-"; print "  "$1, $2, d, $3, $4, $5}'

h "NACL (default ones become aws_default_network_acl)"
q ec2 describe-network-acls --query 'NetworkAcls[].[NetworkAclId,VpcId,IsDefault,join(`,`,Associations[].SubnetId)]'

h "INSTANCES  id  state  type  ami  subnet  key  sgs  profile  name"
q ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType,ImageId,SubnetId,KeyName,join(`,`,SecurityGroups[].GroupId),IamInstanceProfile.Arn,Tags[?Key==`Name`]|[0].Value]'

h "VOLUMES  id  size  type  az  attached-to  device  ROOT?"
aws ec2 describe-volumes --query 'Volumes[].[VolumeId,Size,VolumeType,AvailabilityZone,Attachments[0].InstanceId,Attachments[0].Device]' --output text |
while read -r v sz t az i dev; do
  root=-; if [ "$i" != "None" ]; then rd=$(aws ec2 describe-instances --instance-ids "$i" --query 'Reservations[0].Instances[0].RootDeviceName' --output text); [ "$rd" = "$dev" ] && root=ROOT; fi
  echo "  $v $sz $t $az $i $dev $root"
done

h "EIP  alloc  ip  instance  assoc"
q ec2 describe-addresses --query 'Addresses[].[AllocationId,PublicIp,InstanceId,AssociationId]'

h "KEY PAIRS  key-id  NAME (import id = name)"
q ec2 describe-key-pairs --query 'KeyPairs[].[KeyPairId,KeyName]'

h "KMS  key  manager  state  aliases   (only CUSTOMER keys are importable)"
for k in $(aws kms list-keys --query 'Keys[].KeyId' --output text); do
  read -r mgr st < <(aws kms describe-key --key-id "$k" --query 'KeyMetadata.[KeyManager,KeyState]' --output text)
  al=$(aws kms list-aliases --key-id "$k" --query 'join(`,`,Aliases[].AliasName)' --output text 2>/dev/null)
  echo "  $k $mgr $st ${al:--}"
done

h "RDS  (mssql_* tfvars for adoption)"
q rds describe-db-instances --query 'DBInstances[].[DBInstanceIdentifier,Engine,EngineVersion,DBInstanceClass,AllocatedStorage,MaxAllocatedStorage,StorageType,StorageEncrypted,MultiAZ,Endpoint.Port,MasterUsername,DBSubnetGroup.DBSubnetGroupName,join(`,`,VpcSecurityGroups[].VpcSecurityGroupId),BackupRetentionPeriod,PreferredBackupWindow,PreferredMaintenanceWindow,DeletionProtection,MasterUserSecret.SecretArn!=`null`]'
q rds describe-db-subnet-groups --query 'DBSubnetGroups[].[DBSubnetGroupName,VpcId,join(`,`,Subnets[].SubnetIdentifier)]'

h "SECRETS  name  owning-service  rotation   (metadata only)"
q secretsmanager list-secrets --query 'SecretList[].[Name,OwningService,RotationEnabled]'

h "DMS ENDPOINTS  arn  IDENTIFIER (import id)"
q dms describe-endpoints --query 'Endpoints[].[EndpointArn,EndpointIdentifier,EngineName]'

h "ACM  arn  domain  SANs  status  in-use-by"
for c in $(aws acm list-certificates --query 'CertificateSummaryList[].CertificateArn' --output text); do
  aws acm describe-certificate --certificate-arn "$c" --query 'Certificate.[CertificateArn,DomainName,join(`,`,SubjectAlternativeNames),Status,length(InUseBy)]' --output text | sed 's/^/  /'
done

h "ROUTE53 hosted zones (prod design creates nomaos.com + agrovesto.com)"
q route53 list-hosted-zones --query 'HostedZones[].[Id,Name,Config.PrivateZone]'

h "AMPLIFY apps  id  name  repo  branches  domains"
for a in $(aws amplify list-apps --query 'apps[].appId' --output text); do
  n=$(aws amplify get-app --app-id "$a" --query 'app.[name,repository]' --output text | tr '\t' ' ')
  b=$(aws amplify list-branches --app-id "$a" --query 'join(`,`,branches[].branchName)' --output text)
  d=$(aws amplify list-domain-associations --app-id "$a" --query 'join(`,`,domainAssociations[].domainName)' --output text)
  echo "  $a $n branches=$b domains=${d:--}"
done

h "CLOUDFORMATION stacks  name  status  (decouple/own - RUNBOOK §0)"
q cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE UPDATE_ROLLBACK_COMPLETE IMPORT_COMPLETE --query 'StackSummaries[].[StackName,StackStatus]'

h "BOOTSTRAP  state bucket / deploy role"
B="nomaos-tfstate-$ACCT-$AWS_REGION"
aws s3api get-bucket-lifecycle-configuration --bucket "$B" >/dev/null 2>&1 && echo "  STATE lifecycle: yes" || echo "  STATE lifecycle: no"
aws s3api get-bucket-policy --bucket "$B" >/dev/null 2>&1 && echo "  STATE policy: yes" || echo "  STATE policy: no"
q iam list-roles --query 'Roles[?contains(RoleName,`deploy`)||contains(RoleName,`github`)].[RoleName,Arn]'
q iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[].Arn'

h "RESOURCES NOT IN THE INVENTORY (Resource Explorer does not index them; the new code manages them)"
q iam list-roles --query 'Roles[?!starts_with(Path,`/aws-service-role/`)].RoleName'
q route53 list-hosted-zones --query 'HostedZones[].Name'
q elbv2 describe-load-balancers --query 'LoadBalancers[].[LoadBalancerName,VpcId]'
q efs describe-file-systems --query 'FileSystems[].[FileSystemId,Name]'
q sns list-subscriptions --query 'Subscriptions[].[TopicArn,Protocol]'

echo; echo "saved to $OUT"
