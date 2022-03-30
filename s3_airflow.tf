resource "aws_s3_bucket" "airflow" {
  bucket = "inv-mm-sandbox-airflow"
}

resource "aws_iam_policy" "airflow_log_policy" {
  name = "airflow_log_policy" 
  policy = data.aws_iam_policy_document.airflow_log_permissions.json
}

data "aws_iam_policy_document" "airflow_log_permissions" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectAcl",
      "s3:PutObject",
      "s3:GetObjectAcl",
      "s3:DeleteObject",
      "s3:RestoreObject",
      "s3:ReplicateObject",
    ]

    resources = [
      aws_s3_bucket.airflow.arn,
      "${aws_s3_bucket.airflow.arn}/*",
    ]

  }
}

resource "aws_iam_role_policy_attachment" "airflow_log_role_policy" {
  policy_arn = aws_iam_policy.airflow_log_policy.arn
  role       = aws_iam_role.airflow_log_role.name
}
