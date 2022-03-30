module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "17.24.0"
  cluster_name    = local.cluster_name
  cluster_version = "1.21"
  subnets         = module.vpc.private_subnets

  vpc_id = module.vpc.vpc_id

  workers_group_defaults = {
    root_volume_type = "gp2"
  }

  worker_groups = [
    {
      name                          = "worker-group-1"
      instance_type                 = "t2.small"
      additional_userdata           = "airflow-small"
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
      asg_desired_capacity          = 1
    },
    {
      name                          = "worker-group-2"
      instance_type                 = "t2.medium"
      additional_userdata           = "airflow-medium"
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_two.id]
      asg_desired_capacity          = 1
    },
  ]

  node_groups = {
    airflow_cpu = {
      desired_capacity = 0
      max_capacity     = 10
      min_capacity     = 0

      instance_type = "m5.large"
    }
    airflow_gpu = {
      desired_capacity = 0
      max_capacity     = 10
      min_capacity     = 0

      instance_type = "p3.2xlarge"
    }
  }

  #workers_additional_policies = [aws_iam_policy.worker_policy.arn]
}

#resource "aws_iam_policy" "worker_policy" {
#  name        = "worker-policy"
#  description = "Worker policy for the ALB Ingress"
#
#  policy = file("iam_policy.json")
#}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

data "tls_certificate" "eks_certificate" {
  url = module.eks.cluster_oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "eks_oidcp" {
  url = module.eks.cluster_oidc_issuer_url

  client_id_list = [
    "sts.amazonaws.com"
  ]
  # use different thumbprint for different region
  # https://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/id_roles_providers_create_oidc_verify-thumbprint.html
  thumbprint_list = [data.tls_certificate.eks_certificate.certificates.0.sha1_fingerprint]
}

resource "aws_iam_role" "airflow_log_role" {
  name = "airflow_eks_log_role"

  assume_role_policy = <<EOS
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
          "Federated": "${aws_iam_openid_connect_provider.eks_oidcp.arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${aws_iam_openid_connect_provider.eks_oidcp.url}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOS
}


resource "kubernetes_service_account" "airflow" {
  metadata {
    name      = "airflow-sa"
    namespace = "airflow"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.airflow_log_role.arn
    }
  }

  automount_service_account_token = true
}
