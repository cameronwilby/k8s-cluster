set -ex

# fill in your own values for these
export BUCKET_NAME=
export GITLAB_CI_TOKEN=
export KOPS_CLUSTER_NAME=
export BASTION_EC2=t2.micro
export MASTER_EC2=m3.medium
export NODE_EC2=m3.medium
export MASTER_SPOT="0.0067"
export NODE_SPOT="0.0067"
export NODE_MAX=1

# init
aws s3api delete-bucket --bucket $BUCKET_NAME --region us-east-1 || echo "couldn't delete bucket"
kops delete cluster --name $KOPS_CLUSTER_NAME --yes || echo 'skip deleting cluster';
aws ec2 cancel-spot-instance-requests \
  --spot-instance-request-ids="$(aws ec2 describe-spot-instance-requests | jq [.SpotInstanceRequests[].SpotInstanceRequestId])" \
  || echo "no need to cancel spot instances"
aws s3api create-bucket --bucket $BUCKET_NAME --region us-east-1 || echo "couldn't create bucket"
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled

# compile
for filename in ./config/*.yaml; do
  cp -R ${filename} ${filename}.tmp
  sed -i.bak "s/__MASTER_EC2__/$MASTER_EC2/" ${filename}.tmp
  sed -i.bak "s/__MASTER_SPOT__/$MASTER_SPOT/" ${filename}.tmp
  sed -i.bak "s/__NODE_EC2__/$NODE_EC2/" ${filename}.tmp
  sed -i.bak "s/__NODE_SPOT__/$NODE_SPOT/" ${filename}.tmp
  sed -i.bak "s/__NODE_MAX__/$NODE_MAX/" ${filename}.tmp
  sed -i.bak "s/__BASTION_EC2__/$BASTION_EC2/" ${filename}.tmp
  sed -i.bak "s/__KOPS_CLUSTER_NAME__/$KOPS_CLUSTER_NAME/" ${filename}.tmp
  sed -i.bak "s/__BUCKET_NAME__/$BUCKET_NAME/" ${filename}.tmp
  sed -i.bak "s/__GITLAB_CI_TOKEN__/$(echo $GITLAB_CI_TOKEN | base64)/" ${filename}.tmp
done

# link
kops create -f ./config/cluster.yaml.tmp
kops create -f ./config/master-us-east-1a.yaml.tmp
kops create -f ./config/master-us-east-1b.yaml.tmp
kops create -f ./config/master-us-east-1d.yaml.tmp
kops create -f ./config/bastion.yaml.tmp
kops create -f ./config/nodes.yaml.tmp

# deploy cluster
kops create secret --name $KOPS_CLUSTER_NAME sshpublickey admin -i ~/.ssh/id_rsa.pub
kops update cluster --yes

watch -n1 kubectl get nodes