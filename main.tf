
# Create a VPC
resource "aws_vpc" "example" {
  cidr_block = "10.244.0.0/16"
  
  # Enable VPC flow logs
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "test-vpc-diogo"
  }
}

# Add VPC flow logs
resource "aws_flow_log" "example" {
  iam_role_arn    = aws_iam_role.vpc_flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.example.id
}

# CloudWatch log group for VPC flow logs
resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  name = "/aws/vpc/flow-log-${aws_vpc.example.id}"
}

# IAM role for VPC flow logs
resource "aws_iam_role" "vpc_flow_log_role" {
  name = "vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for VPC flow logs
resource "aws_iam_role_policy" "vpc_flow_log_policy" {
  name = "vpc-flow-log-policy"
  role = aws_iam_role.vpc_flow_log_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Default security group that restricts all traffic
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.example.id

  # No ingress or egress rules means all traffic is denied
}

output "vpc_id" {
  value = aws_vpc.example.id
}

resource "local_file" "vpc_id" {
  content = aws_vpc.example.id
  filename = "vpc_id.txt"
}
