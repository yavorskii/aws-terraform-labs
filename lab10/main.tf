provider "aws" {
  region = "eu-north-1"
}

provider "aws" {
  alias  = "backup_region"
  region = "eu-central-1"
}

data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

resource "aws_instance" "app_vm" {
  ami           = data.aws_ami.latest_amazon_linux.id
  instance_type = "t3.micro"

  tags = {
    Name       = "az104-10-vm0"
    BackupPlan = "Gold"
  }
}

resource "aws_backup_vault" "primary_vault" {
  name = "az104-rsv-region1"
}

resource "aws_backup_vault" "secondary_vault" {
  provider = aws.backup_region
  name     = "az104-rsv-region2"
}

resource "aws_backup_plan" "main_plan" {
  name = "az104-backup-plan"

  rule {
    rule_name         = "DailyBackupAndDR"
    target_vault_name = aws_backup_vault.primary_vault.name
    schedule          = "cron(0 0 * * ? *)"

    lifecycle {
      delete_after = 14
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.secondary_vault.arn
      
      lifecycle {
        delete_after = 14
      }
    }
  }
}

resource "aws_backup_selection" "tagged_selection" {
  name         = "tagged-resources-selection"
  iam_role_arn = "arn:aws:iam::947993334988:role/service-role/AWSBackupDefaultServiceRole"
  plan_id      = aws_backup_plan.main_plan.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "BackupPlan"
    value = "Gold"
  }
}

resource "aws_s3_bucket" "monitoring_logs" {
  bucket = "vladyslav-backup-monitoring-logs"
}

resource "aws_backup_report_plan" "daily_report" {
  name        = "backup_diagnostic_report"
  description = "Logs and Metrics to storage"

  report_delivery_channel {
    s3_bucket_name = aws_s3_bucket.monitoring_logs.id
    s3_key_prefix  = "reports"
  }

  report_setting {
    report_template = "BACKUP_JOB_REPORT"
  }
}