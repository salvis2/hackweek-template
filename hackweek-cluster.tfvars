# Put your cluster where your data is
region = "us-west-2"

profile = "terraform-bot"

# See https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html for
# more information
map_users = [{
    userarn  = "arn:aws:iam::783380859522:user/salvis"
    username = "salvis"
    groups   = ["system:masters"]
  },
  {
    userarn  = "arn:aws:iam::783380859522:user/terraform-bot"
    username = "terraform-bot"
    groups   = ["system:masters"]
  }
]

# Name of your cluster
cluster_name = "hackweek-cluster"

# Name of your VPC
vpc_name     = "hackweek-vpc"